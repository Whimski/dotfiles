#pragma once

#include <QObject>
#include <QDate>
#include <QDateTime>
#include <QColor>
#include <QVector>
#include <QSet>
#include <QMap>
#include <QVariantList>

// Central calendar UI state: the focused date, the active view, the set of
// calendars and their events. Views bind monthLabel/viewMode and pull data via
// the invokable query methods. A backend (GoogleCalendarService) feeds real data
// through setData(); until then setMockData() provides a populated sample so the
// UI is usable offline.
class CalendarController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString viewMode READ viewMode WRITE setViewMode NOTIFY viewModeChanged)
    Q_PROPERTY(QString monthLabel READ monthLabel NOTIFY anchorChanged)
    Q_PROPERTY(QString anchorIso READ anchorIso NOTIFY anchorChanged)
    Q_PROPERTY(QString todayIso READ todayIso CONSTANT)
    Q_PROPERTY(QVariantList calendars READ calendars NOTIFY dataChanged)

public:
    struct Event {
        QString id, title, calendarId;
        QDateTime start, end;
        bool allDay = false;
        QColor color;
        // Recurrence: `recurringEventId` is the master id when this is an instance of
        // a repeating series (empty otherwise); `recurrence` is the RRULE body value
        // (only present on masters — empty on expanded instances).
        QString recurringEventId, recurrence;
    };
    struct CalInfo { QString id, summary; QColor color; bool writable = false; };

    explicit CalendarController(QObject *parent = nullptr);

    QString viewMode() const { return m_view; }
    void setViewMode(const QString &v);
    QString monthLabel() const;
    QString anchorIso() const { return m_anchor.toString(Qt::ISODate); }
    QString todayIso() const { return QDate::currentDate().toString(Qt::ISODate); }
    QVariantList calendars() const;

    // ---- navigation ----
    Q_INVOKABLE void today();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void next();
    Q_INVOKABLE void setAnchorIso(const QString &iso);

    // ---- queries for the views ----
    Q_INVOKABLE QVariantList monthCells() const;             // 42 cells (Mon-start) for the anchor month
    Q_INVOKABLE QVariantList eventsOnIso(const QString &iso) const;   // visible events on a day
    Q_INVOKABLE QVariantList agenda(int days = 45) const;    // upcoming visible events, flat + sorted

    Q_INVOKABLE void toggleCalendar(const QString &id);
    Q_INVOKABLE bool calendarVisible(const QString &id) const { return !m_hidden.contains(id); }

    // Per-calendar colour override (applies to the calendar dot + its events).
    Q_INVOKABLE void setCalendarColor(const QString &id, const QString &hex);
    void setColorOverrides(const QVariantMap &map);

    // ---- data feed (from backends) ----
    // Each backend pushes under a key ("google", "ics", "mock"); the controller
    // shows the union of the real sources, falling back to mock when none exist.
    void setSourceData(const QString &source, const QVector<CalInfo> &cals, const QVector<Event> &events);
    void setHidden(const QSet<QString> &hidden) { m_hidden = hidden; emit dataChanged(); }
    void setMockData();

signals:
    void viewModeChanged();
    void anchorChanged();
    void dataChanged();
    void calendarToggled(const QString &id, bool hidden);
    void calendarColorChanged(const QString &id, const QString &hex);

private:
    QVariantMap eventMap(const Event &e) const;
    bool visible(const Event &e) const { return !m_hidden.contains(e.calendarId); }
    void rebuild();   // recompute the combined calendars/events from m_sources

    struct SourceData { QVector<CalInfo> cals; QVector<Event> events; };

    QDate m_anchor;
    QString m_view = "month";
    QMap<QString, SourceData> m_sources;
    QMap<QString, QColor> m_colorOverrides;
    QVector<CalInfo> m_calendars;    // combined (derived from m_sources)
    QVector<Event> m_events;         // combined
    QSet<QString> m_hidden;
};
