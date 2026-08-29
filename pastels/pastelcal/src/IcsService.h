#pragma once

#include <QObject>
#include <QVariantList>
#include <QColor>
#include <QVector>
#include "CalendarController.h"

class SettingsStore;
class QNetworkAccessManager;

// Read-only iCal / ICS feed source. The user pastes a calendar's public or
// "secret address in iCal format" URL (Google, Nextcloud, Fastmail, …); this
// fetches it, parses the VEVENTs (all-day + basic recurrence), and feeds the
// CalendarController under the "ics" source key. No OAuth required.
class IcsService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList feeds READ feeds NOTIFY feedsChanged)     // [{url,name,color}]
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit IcsService(SettingsStore *settings, CalendarController *controller,
                        QObject *parent = nullptr);

    QVariantList feeds() const;
    bool busy() const { return m_pending > 0; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void addFeed(const QString &url, const QString &name);
    Q_INVOKABLE void removeFeed(const QString &url);
    Q_INVOKABLE void refresh();

signals:
    void feedsChanged();
    void busyChanged();
    void lastErrorChanged();

private:
    void reload();
    void setError(const QString &e);
    void parseInto(const QString &text, const QString &calId, const QColor &color,
                   const QDate &from, const QDate &to,
                   QVector<CalendarController::Event> &out) const;
    QColor colorFor(int index) const;

    SettingsStore *m_settings;
    CalendarController *m_controller;
    QNetworkAccessManager *m_net;
    int m_pending = 0;
    QString m_lastError;
    QVector<CalendarController::CalInfo> m_accCals;
    QVector<CalendarController::Event> m_accEvents;
};
