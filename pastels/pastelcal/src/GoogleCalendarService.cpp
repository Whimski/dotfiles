#include "GoogleCalendarService.h"
#include "SettingsStore.h"

#include <QOAuthHttpServerReplyHandler>
#include <QDesktopServices>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrlQuery>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QTimeZone>
#include <QDebug>

// Build a useful message from a failed Calendar API reply. Google returns a JSON
// body ({ "error": { "code", "message", "errors":[{ "reason" }] } }) that explains
// *why* far better than Qt's generic "server replied: Forbidden" — surface it.
static QString apiError(QNetworkReply *reply)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QString msg = reply->errorString();
    const QByteArray body = reply->readAll();
    if (!body.isEmpty()) {
        const QJsonObject err = QJsonDocument::fromJson(body).object().value("error").toObject();
        const QString m = err.value("message").toString();
        const QJsonArray errs = err.value("errors").toArray();
        const QString reason = errs.isEmpty() ? QString()
                             : errs.first().toObject().value("reason").toString();
        if (!m.isEmpty())
            msg = reason.isEmpty() ? m : (m + " [" + reason + "]");
    }
    return status > 0 ? QString("HTTP %1 — %2").arg(status).arg(msg) : msg;
}

static const char *kAuthUrl  = "https://accounts.google.com/o/oauth2/auth";
static const char *kTokenUrl = "https://oauth2.googleapis.com/token";
static const char *kScope    = "https://www.googleapis.com/auth/calendar "
                               "https://www.googleapis.com/auth/userinfo.email";

GoogleCalendarService::GoogleCalendarService(SettingsStore *settings,
                                             CalendarController *controller,
                                             QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
    loadClientCredentials();

    m_flow.setAuthorizationUrl(QUrl(QString::fromUtf8(kAuthUrl)));
    m_flow.setAccessTokenUrl(QUrl(QString::fromUtf8(kTokenUrl)));
    m_flow.setScope(QString::fromUtf8(kScope));
    applyClientCreds();

    // Loopback reply handler on an OS-chosen port (Google "Desktop app" clients
    // accept any http://127.0.0.1:<port> redirect).
    auto *handler = new QOAuthHttpServerReplyHandler(0, this);
    m_flow.setReplyHandler(handler);

    // Ask Google for offline access so we receive a refresh token.
    m_flow.setModifyParametersFunction(
        [](QAbstractOAuth::Stage stage, QMultiMap<QString, QVariant> *params) {
            if (stage == QAbstractOAuth::Stage::RequestingAuthorization) {
                params->insert("access_type", "offline");
                params->insert("prompt", "consent");
            }
        });

    // Persist calendar show/hide toggles.
    connect(m_controller, &CalendarController::calendarToggled, this,
            [this](const QString &id, bool hidden) { m_settings->setCalendarHidden(id, hidden); });

    connect(&m_flow, &QOAuth2AuthorizationCodeFlow::authorizeWithBrowser,
            this, [](const QUrl &url) { QDesktopServices::openUrl(url); });

    connect(&m_flow, &QOAuth2AuthorizationCodeFlow::granted, this, [this] {
        m_authenticated = true;
        const QString rt = m_flow.refreshToken();
        if (!rt.isEmpty()) m_settings->setGoogleRefreshToken(rt);
        emit authChanged();
        fetchAccount();
        fetchCalendars();
    });

    // Resume a persisted session.
    const QString rt = m_settings->googleRefreshToken();
    if (configured() && !rt.isEmpty()) {
        m_account = m_settings->googleAccount();
        m_flow.setRefreshToken(rt);
        setBusy(true);
        m_flow.refreshAccessToken();
    }
}

void GoogleCalendarService::loadClientCredentials()
{
    // Priority: credentials entered in the UI (persisted) → environment →
    // a google_client.json in the app config dir.
    m_clientId = m_settings->googleClientId();
    m_clientSecret = m_settings->googleClientSecret();
    if (!m_clientId.isEmpty()) return;

    m_clientId = qEnvironmentVariable("GOOGLE_OAUTH_CLIENT_ID");
    m_clientSecret = qEnvironmentVariable("GOOGLE_OAUTH_CLIENT_SECRET");
    if (!m_clientId.isEmpty()) return;

    const QString path = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
                         + "/google_client.json";
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject root = QJsonDocument::fromJson(f.readAll()).object();
    QJsonObject o = root;
    if (root.contains("installed")) o = root.value("installed").toObject();
    else if (root.contains("web")) o = root.value("web").toObject();
    m_clientId = o.value("client_id").toString();
    m_clientSecret = o.value("client_secret").toString();
}

void GoogleCalendarService::applyClientCreds()
{
    m_flow.setClientIdentifier(m_clientId);
    m_flow.setClientIdentifierSharedKey(m_clientSecret);
}

void GoogleCalendarService::setClientCredentials(const QString &id, const QString &secret)
{
    QString newId = id.trimmed();
    QString newSecret = secret.trimmed();

    // Allow pasting the whole downloaded client JSON into the id field.
    if (newId.startsWith('{')) {
        const QJsonObject root = QJsonDocument::fromJson(newId.toUtf8()).object();
        QJsonObject o = root;
        if (root.contains("installed")) o = root.value("installed").toObject();
        else if (root.contains("web")) o = root.value("web").toObject();
        newId = o.value("client_id").toString();
        if (newSecret.isEmpty()) newSecret = o.value("client_secret").toString();
    }

    if (newId.isEmpty()) {
        setError("That doesn't look like a valid Client ID.");
        return;
    }
    // Keep the stored secret if the field was left blank.
    if (newSecret.isEmpty()) newSecret = m_settings->googleClientSecret();

    m_clientId = newId;
    m_clientSecret = newSecret;
    m_settings->setGoogleClientId(newId);
    m_settings->setGoogleClientSecret(newSecret);
    applyClientCreds();
    m_lastError.clear();
    emit lastErrorChanged();
    emit configChanged();
}

void GoogleCalendarService::setBusy(bool b)
{
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

void GoogleCalendarService::setError(const QString &e)
{
    qWarning().noquote() << "[pastelcal]" << e;   // also to the console for debugging
    m_lastError = e;
    emit lastErrorChanged();
    setBusy(false);
}

void GoogleCalendarService::signIn()
{
    if (!configured()) {
        setError("No Google OAuth client configured. Set GOOGLE_OAUTH_CLIENT_ID "
                 "(and secret) or ~/.config/PastelCal/google_client.json — see README.");
        return;
    }
    m_lastError.clear();
    emit lastErrorChanged();
    setBusy(true);
    m_flow.grant();
}

void GoogleCalendarService::signOut()
{
    m_settings->setGoogleRefreshToken(QString());
    m_settings->setGoogleAccount(QString());
    m_flow.setToken(QString());
    m_flow.setRefreshToken(QString());
    m_authenticated = false;
    m_account.clear();
    emit authChanged();
    m_controller->setSourceData("google", {}, {});   // drops google data; mock/ics remain
}

void GoogleCalendarService::refresh()
{
    if (m_authenticated) fetchCalendars();
    else if (configured() && !m_settings->googleRefreshToken().isEmpty())
        m_flow.refreshAccessToken();
}

void GoogleCalendarService::fetchAccount()
{
    auto *reply = m_flow.get(QUrl("https://www.googleapis.com/oauth2/v3/userinfo"));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        m_account = o.value("email").toString();
        m_settings->setGoogleAccount(m_account);
        emit authChanged();
    });
}

void GoogleCalendarService::fetchCalendars()
{
    setBusy(true);
    m_accCals.clear();
    m_accEvents.clear();

    auto *reply = m_flow.get(QUrl("https://www.googleapis.com/calendar/v3/users/me/calendarList"));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setError("Failed to load calendars: " + apiError(reply));
            return;
        }
        const QJsonArray items = QJsonDocument::fromJson(reply->readAll())
                                     .object().value("items").toArray();
        struct Pending { QString id, summary; QColor color; };
        QVector<Pending> pend;
        for (const QJsonValue &v : items) {
            const QJsonObject o = v.toObject();
            const QString id = o.value("id").toString();
            const QString summary = o.value("summaryOverride").toString(
                                        o.value("summary").toString());
            const QColor color(o.value("backgroundColor").toString("#6aa6f0"));
            const QString role = o.value("accessRole").toString();
            const bool writable = (role == "owner" || role == "writer");
            m_accCals.append({ id, summary, color, writable });
            pend.append({ id, summary, color });
        }
        // Apply persisted visibility.
        QSet<QString> hidden(m_settings->hiddenCalendars().begin(),
                             m_settings->hiddenCalendars().end());
        m_controller->setHidden(hidden);

        m_pending = pend.size();
        if (m_pending == 0) { maybeCommit(); return; }
        for (const Pending &p : pend)
            fetchEventsFor(p.id, p.color, p.summary);
    });
}

void GoogleCalendarService::fetchEventsFor(const QString &calId, const QColor &color,
                                           const QString &summary)
{
    Q_UNUSED(summary);
    const QDateTime from(QDate::currentDate().addMonths(-1).addDays(
                             1 - QDate::currentDate().addMonths(-1).day()), QTime(0, 0));
    const QDateTime to = from.addMonths(3);

    QUrl url("https://www.googleapis.com/calendar/v3/calendars/"
             + QString::fromUtf8(QUrl::toPercentEncoding(calId)) + "/events");
    QUrlQuery q;
    q.addQueryItem("timeMin", from.toUTC().toString(Qt::ISODate));
    q.addQueryItem("timeMax", to.toUTC().toString(Qt::ISODate));
    q.addQueryItem("singleEvents", "true");
    q.addQueryItem("orderBy", "startTime");
    q.addQueryItem("maxResults", "250");
    url.setQuery(q);

    auto *reply = m_flow.get(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply, calId, color] {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonArray items = QJsonDocument::fromJson(reply->readAll())
                                         .object().value("items").toArray();
            for (const QJsonValue &v : items) {
                const QJsonObject o = v.toObject();
                CalendarController::Event e;
                e.id = o.value("id").toString();
                e.title = o.value("summary").toString("(no title)");
                e.calendarId = calId;
                e.color = color;
                e.recurringEventId = o.value("recurringEventId").toString();
                const QJsonArray rr = o.value("recurrence").toArray();
                if (!rr.isEmpty()) e.recurrence = rr.first().toString();

                const QJsonObject s = o.value("start").toObject();
                const QJsonObject en = o.value("end").toObject();
                if (s.contains("date")) {          // all-day (end date is exclusive)
                    e.allDay = true;
                    const QDate sd = QDate::fromString(s.value("date").toString(), Qt::ISODate);
                    QDate ed = QDate::fromString(en.value("date").toString(), Qt::ISODate);
                    if (ed.isValid()) ed = ed.addDays(-1);
                    e.start = QDateTime(sd, QTime(0, 0));
                    e.end = QDateTime(ed.isValid() ? ed : sd, QTime(0, 0));
                } else {
                    e.start = QDateTime::fromString(s.value("dateTime").toString(), Qt::ISODate);
                    e.end = QDateTime::fromString(en.value("dateTime").toString(), Qt::ISODate);
                }
                if (e.start.isValid())
                    m_accEvents.append(e);
            }
        }
        if (--m_pending <= 0) maybeCommit();
    });
}

void GoogleCalendarService::maybeCommit()
{
    m_controller->setSourceData("google", m_accCals, m_accEvents);
    QSet<QString> hidden(m_settings->hiddenCalendars().begin(),
                         m_settings->hiddenCalendars().end());
    m_controller->setHidden(hidden);
    setBusy(false);
}

// -------------------- event write (Calendar API v3) --------------------

QJsonObject GoogleCalendarService::eventBody(const QString &title, const QString &startIso,
                                             const QString &endIso, bool allDay) const
{
    QJsonObject body, s, e;
    body["summary"] = title;
    if (allDay) {
        s["date"] = startIso;                 // yyyy-MM-dd
        e["date"] = endIso;                   // exclusive (caller passes start + 1 day)
    } else {
        const QString tz = QString::fromUtf8(QTimeZone::systemTimeZoneId());
        s["dateTime"] = startIso;  s["timeZone"] = tz;
        e["dateTime"] = endIso;    e["timeZone"] = tz;
    }
    body["start"] = s;
    body["end"] = e;
    return body;
}

void GoogleCalendarService::sendWrite(const QByteArray &verb, const QUrl &url, const QJsonObject &body)
{
    if (!m_authenticated) { setError("Connect Google to add or edit events."); return; }
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", "Bearer " + m_flow.token().toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    const QByteArray data = body.isEmpty() ? QByteArray()
                                           : QJsonDocument(body).toJson(QJsonDocument::Compact);
    setBusy(true);
    QNetworkReply *reply = (verb == "POST")   ? m_net->post(req, data)
                         : (verb == "DELETE") ? m_net->deleteResource(req)
                                              : m_net->sendCustomRequest(req, verb, data);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            setError("Save failed: " + apiError(reply));
            return;
        }
        emit writeDone();
        fetchCalendars();       // refetch so the change shows
    });
}

static QString encId(const QString &s) { return QString::fromUtf8(QUrl::toPercentEncoding(s)); }

void GoogleCalendarService::createEvent(const QString &calendarId, const QString &title,
                                        const QString &startIso, const QString &endIso, bool allDay,
                                        const QString &recurrence)
{
    const QUrl url("https://www.googleapis.com/calendar/v3/calendars/"
                   + encId(calendarId) + "/events");
    QJsonObject body = eventBody(title, startIso, endIso, allDay);
    if (!recurrence.trimmed().isEmpty())
        body["recurrence"] = QJsonArray{ "RRULE:" + recurrence.trimmed() };
    sendWrite("POST", url, body);
}

void GoogleCalendarService::updateSeries(const QString &calendarId, const QString &masterId,
                                         const QString &title, const QString &startIso,
                                         const QString &endIso, bool allDay)
{
    if (!m_authenticated) { setError("Connect Google to edit events."); return; }
    const QUrl url("https://www.googleapis.com/calendar/v3/calendars/"
                   + encId(calendarId) + "/events/" + encId(masterId));

    // Fetch the master first: editing all occurrences must keep the series' own
    // anchor date (only the title/time-of-day should change), otherwise PATCHing the
    // instance's date would reschedule the whole series. Recurrence is left intact.
    setBusy(true);
    auto *get = m_flow.get(url);
    connect(get, &QNetworkReply::finished, this, [this, get, url, title, startIso, endIso, allDay] {
        get->deleteLater();
        if (get->error() != QNetworkReply::NoError) {
            setError("Edit-all failed: " + apiError(get));
            return;
        }
        const QJsonObject master = QJsonDocument::fromJson(get->readAll()).object();
        QJsonObject body;
        body["summary"] = title;
        if (!allDay) {
            // Master's anchor date + the newly chosen time-of-day.
            const QString mStart = master.value("start").toObject().value("dateTime").toString();
            const QString anchor = mStart.left(10);               // yyyy-MM-dd
            if (anchor.length() == 10) {
                const QString tz = QString::fromUtf8(QTimeZone::systemTimeZoneId());
                QJsonObject s, e;
                s["dateTime"] = anchor + startIso.mid(10);        // + "THH:mm:ss"
                s["timeZone"] = tz;
                e["dateTime"] = anchor + endIso.mid(10);
                e["timeZone"] = tz;
                body["start"] = s;
                body["end"] = e;
            }
        }
        sendWrite("PATCH", url, body);
    });
}

void GoogleCalendarService::updateEvent(const QString &calendarId, const QString &eventId,
                                        const QString &title, const QString &startIso,
                                        const QString &endIso, bool allDay)
{
    const QUrl url("https://www.googleapis.com/calendar/v3/calendars/"
                   + encId(calendarId) + "/events/" + encId(eventId));
    sendWrite("PATCH", url, eventBody(title, startIso, endIso, allDay));
}

void GoogleCalendarService::deleteEvent(const QString &calendarId, const QString &eventId)
{
    const QUrl url("https://www.googleapis.com/calendar/v3/calendars/"
                   + encId(calendarId) + "/events/" + encId(eventId));
    sendWrite("DELETE", url, {});
}
