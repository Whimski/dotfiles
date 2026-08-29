#include "IcsService.h"
#include "SettingsStore.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QStringList>
#include <QRegularExpression>

IcsService::IcsService(SettingsStore *settings, CalendarController *controller, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
    , m_controller(controller)
    , m_net(new QNetworkAccessManager(this))
{
    if (!m_settings->icsFeeds().isEmpty())
        reload();
}

QVariantList IcsService::feeds() const { return m_settings->icsFeeds(); }

QColor IcsService::colorFor(int index) const
{
    static const char *palette[] = { "#6aa6f0", "#34c3a3", "#ef86b3", "#f0a35e", "#a98bf0", "#e0658a" };
    return QColor(palette[index % 6]);
}

void IcsService::setError(const QString &e)
{
    m_lastError = e;
    emit lastErrorChanged();
}

void IcsService::addFeed(const QString &url, const QString &name)
{
    QString u = url.trimmed();
    if (u.startsWith("webcal://", Qt::CaseInsensitive)) u = "https://" + u.mid(9);
    if (u.isEmpty() || !(u.startsWith("http://") || u.startsWith("https://"))) {
        setError("Please paste an http(s) or webcal iCal URL.");
        return;
    }
    QVariantList list = m_settings->icsFeeds();
    for (const QVariant &v : list)
        if (v.toMap().value("url").toString() == u) return;   // already added

    QVariantMap m;
    m["url"] = u;
    m["name"] = name.trimmed().isEmpty() ? QUrl(u).host() : name.trimmed();
    m["color"] = colorFor(list.size()).name();
    list.append(m);
    m_settings->setIcsFeeds(list);
    m_lastError.clear();
    emit lastErrorChanged();
    emit feedsChanged();
    reload();
}

void IcsService::removeFeed(const QString &url)
{
    QVariantList list = m_settings->icsFeeds();
    QVariantList kept;
    for (const QVariant &v : list)
        if (v.toMap().value("url").toString() != url) kept.append(v);
    m_settings->setIcsFeeds(kept);
    emit feedsChanged();
    reload();
}

void IcsService::refresh() { reload(); }

void IcsService::reload()
{
    const QVariantList feeds = m_settings->icsFeeds();
    if (feeds.isEmpty()) {
        m_controller->setSourceData("ics", {}, {});
        return;
    }

    const QDate from = QDate::currentDate().addMonths(-2);
    const QDate to = QDate::currentDate().addMonths(6);

    m_accCals.clear();
    m_accEvents.clear();
    m_pending = feeds.size();
    emit busyChanged();

    for (const QVariant &fv : feeds) {
        const QVariantMap f = fv.toMap();
        const QString url = f.value("url").toString();
        const QString name = f.value("name").toString();
        const QColor color(f.value("color", "#6aa6f0").toString());
        m_accCals.append({ url, name, color });   // id = url

        QNetworkRequest req{ QUrl(url) };
        req.setHeader(QNetworkRequest::UserAgentHeader, "pastelcal/0.1");
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
        QNetworkReply *reply = m_net->get(req);
        connect(reply, &QNetworkReply::finished, this,
                [this, reply, url, color, from, to] {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError)
                setError("Couldn't fetch " + QUrl(url).host() + ": " + reply->errorString());
            else
                parseInto(QString::fromUtf8(reply->readAll()), url, color, from, to, m_accEvents);

            if (--m_pending <= 0) {
                m_controller->setSourceData("ics", m_accCals, m_accEvents);
                QSet<QString> hidden(m_settings->hiddenCalendars().begin(),
                                     m_settings->hiddenCalendars().end());
                m_controller->setHidden(hidden);
                emit busyChanged();
            }
        });
    }
}

// -------------------- parsing --------------------

static QString unescapeText(QString s)
{
    s.replace("\\n", "\n").replace("\\N", "\n");
    s.replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\");
    return s;
}

// value like 20260827 (date) or 20260827T093000 / ...Z (datetime)
static QDateTime parseDt(const QString &value, bool &allDay)
{
    const QString v = value.trimmed();
    if (!v.contains('T')) {                         // date only → all-day
        allDay = true;
        return QDateTime(QDate::fromString(v.left(8), "yyyyMMdd"), QTime(0, 0));
    }
    allDay = false;
    const bool utc = v.endsWith('Z');
    const QString core = utc ? v.left(v.size() - 1) : v;
    QDateTime dt = QDateTime::fromString(core, "yyyyMMddTHHmmss");
    if (utc) { dt.setTimeSpec(Qt::UTC); dt = dt.toLocalTime(); }
    return dt;
}

static QList<int> parseByDay(const QString &s)     // "MO,WE,FR" → [1,3,5] (Mon=1)
{
    static const QStringList names = { "MO", "TU", "WE", "TH", "FR", "SA", "SU" };
    QList<int> out;
    for (QString tok : s.split(',', Qt::SkipEmptyParts)) {
        tok = tok.right(2);   // drop any leading ordinal like "2MO"
        const int i = names.indexOf(tok);
        if (i >= 0) out.append(i + 1);
    }
    return out;
}

void IcsService::parseInto(const QString &text, const QString &calId, const QColor &color,
                           const QDate &from, const QDate &to,
                           QVector<CalendarController::Event> &out) const
{
    // Unfold: a line beginning with space/tab continues the previous one.
    QStringList raw = text.split('\n');
    QStringList lines;
    for (QString ln : raw) {
        if (ln.endsWith('\r')) ln.chop(1);
        if (!ln.isEmpty() && (ln[0] == ' ' || ln[0] == '\t') && !lines.isEmpty())
            lines.last() += ln.mid(1);
        else
            lines.append(ln);
    }

    bool inEvent = false;
    QString summary, dtStartRaw, dtEndRaw, rrule, uid;
    bool startAllDay = false, endAllDay = false;

    auto flush = [&] {
        if (dtStartRaw.isEmpty()) return;
        const QString sv = dtStartRaw.section(':', -1);
        CalendarController::Event base;
        base.id = uid;
        base.title = unescapeText(summary.section(':', -1));
        base.calendarId = calId;
        base.color = color;
        base.start = parseDt(sv, startAllDay);
        base.allDay = startAllDay;
        if (!dtEndRaw.isEmpty()) {
            QDateTime e = parseDt(dtEndRaw.section(':', -1), endAllDay);
            if (startAllDay) e = e.addDays(-1);      // DTEND is exclusive for all-day
            base.end = e;
        } else {
            base.end = base.start;
        }
        if (!base.start.isValid()) return;

        if (rrule.isEmpty()) {
            if (base.end.date() >= from && base.start.date() <= to)
                out.append(base);
        } else {
            // ---- expand a simple RRULE within [from, to] ----
            QMap<QString, QString> r;
            for (const QString &kv : rrule.section(':', -1).split(';', Qt::SkipEmptyParts)) {
                const int eq = kv.indexOf('=');
                if (eq > 0) r.insert(kv.left(eq).toUpper(), kv.mid(eq + 1));
            }
            const QString freq = r.value("FREQ").toUpper();
            const int interval = qMax(1, r.value("INTERVAL", "1").toInt());
            const int count = r.value("COUNT", "0").toInt();
            QDate until;
            if (r.contains("UNTIL")) until = QDate::fromString(r.value("UNTIL").left(8), "yyyyMMdd");
            const QList<int> byDay = parseByDay(r.value("BYDAY"));
            const qint64 durSecs = base.allDay ? 0 : base.start.secsTo(base.end);
            const int durDays = base.allDay ? base.start.date().daysTo(base.end.date()) : 0;

            int emitted = 0, guard = 0;
            auto emitAt = [&](const QDateTime &s) {
                CalendarController::Event c = base;
                c.start = s;
                c.end = base.allDay ? QDateTime(s.date().addDays(durDays), QTime(0, 0))
                                    : s.addSecs(durSecs);
                if (s.date() >= from && s.date() <= to) out.append(c);
            };

            if (freq == "WEEKLY" && !byDay.isEmpty()) {
                QDate ws = base.start.date().addDays(-(base.start.date().dayOfWeek() - 1));
                bool done = false;
                for (; !done && ws <= to && guard < 5000; ws = ws.addDays(7 * interval)) {
                    for (int dw : byDay) {
                        const QDate d = ws.addDays(dw - 1);
                        if (d < base.start.date()) continue;
                        if ((count > 0 && emitted >= count) || (until.isValid() && d > until)) { done = true; break; }
                        if (d > to) { done = true; break; }
                        emitAt(QDateTime(d, base.start.time()));
                        ++emitted; ++guard;
                    }
                }
            } else {
                QDateTime s = base.start;
                while (guard++ < 5000) {
                    const QDate d = s.date();
                    if ((count > 0 && emitted >= count) || (until.isValid() && d > until) || d > to) break;
                    emitAt(s);
                    ++emitted;
                    if (freq == "DAILY")        s = s.addDays(interval);
                    else if (freq == "WEEKLY")  s = s.addDays(7 * interval);
                    else if (freq == "MONTHLY") s = s.addMonths(interval);
                    else if (freq == "YEARLY")  s = s.addYears(interval);
                    else break;
                }
            }
        }
    };

    for (const QString &line : lines) {
        if (line.startsWith("BEGIN:VEVENT")) {
            inEvent = true;
            summary.clear(); dtStartRaw.clear(); dtEndRaw.clear(); rrule.clear(); uid.clear();
        } else if (line.startsWith("END:VEVENT")) {
            if (inEvent) flush();
            inEvent = false;
        } else if (inEvent) {
            if (line.startsWith("SUMMARY"))       summary = line;
            else if (line.startsWith("DTSTART"))  dtStartRaw = line;
            else if (line.startsWith("DTEND"))    dtEndRaw = line;
            else if (line.startsWith("RRULE"))    rrule = line;
            else if (line.startsWith("UID"))      uid = line.section(':', -1);
        }
    }
}
