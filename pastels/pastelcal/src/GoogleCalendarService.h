#pragma once

#include <QObject>
#include <QOAuth2AuthorizationCodeFlow>
#include <QVector>
#include "CalendarController.h"

class SettingsStore;
class QNetworkAccessManager;

// Google Calendar backend: OAuth2 (loopback / "Desktop app" client) + Calendar
// API v3. On a successful sign-in it fetches the user's calendar list and their
// events for a window around the current month and feeds them into the
// CalendarController. Requires a Google OAuth client id/secret supplied via the
// GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET environment variables (or
// ~/.config/PastelCal/google_client.json). Until then the app uses mock data.
class GoogleCalendarService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool configured READ configured NOTIFY configChanged)
    Q_PROPERTY(QString clientId READ clientId NOTIFY configChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString account READ account NOTIFY authChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit GoogleCalendarService(SettingsStore *settings,
                                   CalendarController *controller,
                                   QObject *parent = nullptr);

    bool configured() const { return !m_clientId.isEmpty(); }
    QString clientId() const { return m_clientId; }
    bool authenticated() const { return m_authenticated; }
    bool busy() const { return m_busy; }
    QString account() const { return m_account; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void signIn();
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void refresh();

    // Save the OAuth client id/secret entered in the UI (or a pasted client
    // JSON in `id`), persist them, and reconfigure the flow. Empty secret keeps
    // the stored one.
    Q_INVOKABLE void setClientCredentials(const QString &id, const QString &secret);

    // Event write API (Calendar API v3). ISO strings: all-day = "yyyy-MM-dd";
    // timed = "yyyy-MM-ddTHH:mm:ss" (local). `recurrence` is an RRULE body value
    // (e.g. "FREQ=WEEKLY") or "" for a one-off. On success the calendars refetch.
    Q_INVOKABLE void createEvent(const QString &calendarId, const QString &title,
                                 const QString &startIso, const QString &endIso, bool allDay,
                                 const QString &recurrence = QString());
    // Edit a single occurrence (pass an instance id).
    Q_INVOKABLE void updateEvent(const QString &calendarId, const QString &eventId,
                                 const QString &title, const QString &startIso,
                                 const QString &endIso, bool allDay);
    // Edit the whole series (pass the recurring master id). Fetches the master to
    // preserve the series' anchor date, then applies the new title/time to all.
    Q_INVOKABLE void updateSeries(const QString &calendarId, const QString &masterId,
                                  const QString &title, const QString &startIso,
                                  const QString &endIso, bool allDay);
    // Delete an occurrence (instance id) or the whole series (master id).
    Q_INVOKABLE void deleteEvent(const QString &calendarId, const QString &eventId);

signals:
    void authChanged();
    void busyChanged();
    void lastErrorChanged();
    void configChanged();
    void writeDone();          // an event create/update/delete succeeded

private:
    void loadClientCredentials();
    void applyClientCreds();
    QJsonObject eventBody(const QString &title, const QString &startIso,
                          const QString &endIso, bool allDay) const;
    void sendWrite(const QByteArray &verb, const QUrl &url, const QJsonObject &body);
    void setBusy(bool b);
    void setError(const QString &e);
    void fetchAccount();
    void fetchCalendars();
    void fetchEventsFor(const QString &calId, const QColor &color, const QString &summary);
    void maybeCommit();

    SettingsStore *m_settings;
    CalendarController *m_controller;
    QOAuth2AuthorizationCodeFlow m_flow;
    QNetworkAccessManager *m_net = nullptr;

    QString m_clientId, m_clientSecret;
    bool m_authenticated = false;
    bool m_busy = false;
    QString m_account;
    QString m_lastError;

    // accumulation while fetching multiple calendars
    int m_pending = 0;
    QVector<CalendarController::CalInfo> m_accCals;
    QVector<CalendarController::Event> m_accEvents;
};
