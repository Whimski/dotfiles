#include "CalendarController.h"

#include <algorithm>

CalendarController::CalendarController(QObject *parent)
    : QObject(parent)
    , m_anchor(QDate::currentDate())
{
    setMockData();
}

void CalendarController::setViewMode(const QString &v)
{
    if (m_view == v) return;
    m_view = v;
    emit viewModeChanged();
}

QString CalendarController::monthLabel() const
{
    if (m_view == "day")
        return m_anchor.toString("dddd, d MMMM yyyy");
    return m_anchor.toString("MMMM yyyy");
}

void CalendarController::today()
{
    m_anchor = QDate::currentDate();
    emit anchorChanged();
}

void CalendarController::prev()
{
    if (m_view == "week")      m_anchor = m_anchor.addDays(-7);
    else if (m_view == "day")  m_anchor = m_anchor.addDays(-1);
    else                       m_anchor = m_anchor.addMonths(-1);
    emit anchorChanged();
}

void CalendarController::next()
{
    if (m_view == "week")      m_anchor = m_anchor.addDays(7);
    else if (m_view == "day")  m_anchor = m_anchor.addDays(1);
    else                       m_anchor = m_anchor.addMonths(1);
    emit anchorChanged();
}

void CalendarController::setAnchorIso(const QString &iso)
{
    QDate d = QDate::fromString(iso, Qt::ISODate);
    if (!d.isValid() || d == m_anchor) return;
    m_anchor = d;
    emit anchorChanged();
}

QVariantList CalendarController::calendars() const
{
    QVariantList out;
    for (const CalInfo &c : m_calendars) {
        QVariantMap m;
        m["id"] = c.id;
        m["summary"] = c.summary;
        m["color"] = c.color.name();
        m["visible"] = !m_hidden.contains(c.id);
        m["writable"] = c.writable;
        out.append(m);
    }
    return out;
}

QVariantList CalendarController::monthCells() const
{
    QVariantList out;
    const QDate today = QDate::currentDate();
    QDate first(m_anchor.year(), m_anchor.month(), 1);
    const int dow = first.dayOfWeek();          // Mon=1 .. Sun=7
    QDate start = first.addDays(-(dow - 1));     // back to the Monday of the first row
    for (int i = 0; i < 42; ++i) {
        const QDate d = start.addDays(i);
        QVariantMap m;
        m["iso"] = d.toString(Qt::ISODate);
        m["day"] = d.day();
        m["inMonth"] = (d.month() == m_anchor.month() && d.year() == m_anchor.year());
        m["isToday"] = (d == today);
        m["weekend"] = (d.dayOfWeek() >= 6);
        out.append(m);
    }
    return out;
}

QVariantMap CalendarController::eventMap(const Event &e) const
{
    QVariantMap m;
    m["id"] = e.id;
    m["title"] = e.title;
    m["color"] = e.color.name();
    m["allDay"] = e.allDay;
    m["calendarId"] = e.calendarId;
    m["start"] = e.start;
    m["end"] = e.end;
    m["timeLabel"] = e.allDay ? QStringLiteral("All day")
                              : e.start.toString("h:mm ap");
    // Recurrence info for the editor: `recurring` true if part of a series;
    // `recurringEventId` is the master to target when editing/deleting all.
    m["recurring"] = !e.recurringEventId.isEmpty() || !e.recurrence.isEmpty();
    m["recurringEventId"] = e.recurringEventId;
    return m;
}

QVariantList CalendarController::eventsOnIso(const QString &iso) const
{
    QVariantList out;
    const QDate d = QDate::fromString(iso, Qt::ISODate);
    if (!d.isValid()) return out;

    QVector<Event> day;
    for (const Event &e : m_events) {
        if (!visible(e)) continue;
        const QDate s = e.start.date();
        const QDate en = e.end.date();
        if (d >= s && d <= en)
            day.append(e);
    }
    std::sort(day.begin(), day.end(), [](const Event &a, const Event &b) {
        if (a.allDay != b.allDay) return a.allDay;   // all-day first
        return a.start < b.start;
    });
    for (const Event &e : day) out.append(eventMap(e));
    return out;
}

QVariantList CalendarController::agenda(int days) const
{
    const QDate from = QDate::currentDate();
    const QDate to = from.addDays(days);

    QVector<Event> up;
    for (const Event &e : m_events) {
        if (!visible(e)) continue;
        const QDate s = e.start.date();
        if (s >= from && s <= to) up.append(e);
    }
    std::sort(up.begin(), up.end(), [](const Event &a, const Event &b) {
        if (a.start.date() != b.start.date()) return a.start.date() < b.start.date();
        if (a.allDay != b.allDay) return a.allDay;
        return a.start < b.start;
    });

    QVariantList out;
    for (const Event &e : up) {
        QVariantMap m = eventMap(e);
        const QDate s = e.start.date();
        m["iso"] = s.toString(Qt::ISODate);
        m["dateLabel"] = s.toString("ddd d MMM");
        m["dayNum"] = s.day();
        m["weekday"] = s.toString("ddd");
        // calendar name for the row
        for (const CalInfo &c : m_calendars)
            if (c.id == e.calendarId) { m["calendar"] = c.summary; break; }
        out.append(m);
    }
    return out;
}

void CalendarController::toggleCalendar(const QString &id)
{
    const bool nowHidden = !m_hidden.contains(id);
    if (nowHidden) m_hidden.insert(id);
    else           m_hidden.remove(id);
    emit calendarToggled(id, nowHidden);
    emit dataChanged();
}

void CalendarController::setSourceData(const QString &source, const QVector<CalInfo> &cals,
                                       const QVector<Event> &events)
{
    if (cals.isEmpty() && events.isEmpty())
        m_sources.remove(source);
    else
        m_sources[source] = { cals, events };
    rebuild();
}

void CalendarController::rebuild()
{
    // "mock" is only shown when there is no real (google/ics) source.
    bool haveReal = false;
    for (auto it = m_sources.constBegin(); it != m_sources.constEnd(); ++it)
        if (it.key() != "mock" && (!it.value().cals.isEmpty() || !it.value().events.isEmpty()))
            haveReal = true;

    m_calendars.clear();
    m_events.clear();
    for (auto it = m_sources.constBegin(); it != m_sources.constEnd(); ++it) {
        if (haveReal && it.key() == "mock") continue;
        m_calendars += it.value().cals;
        m_events += it.value().events;
    }
    // Apply per-calendar colour overrides to the dot + its events.
    if (!m_colorOverrides.isEmpty()) {
        for (CalInfo &c : m_calendars)
            if (m_colorOverrides.contains(c.id)) c.color = m_colorOverrides.value(c.id);
        for (Event &e : m_events)
            if (m_colorOverrides.contains(e.calendarId)) e.color = m_colorOverrides.value(e.calendarId);
    }
    emit dataChanged();
}

void CalendarController::setCalendarColor(const QString &id, const QString &hex)
{
    const QColor c(hex);
    if (!c.isValid()) return;
    m_colorOverrides.insert(id, c);
    rebuild();
    emit calendarColorChanged(id, c.name());
}

void CalendarController::setColorOverrides(const QVariantMap &map)
{
    m_colorOverrides.clear();
    for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
        const QColor c(it.value().toString());
        if (c.isValid()) m_colorOverrides.insert(it.key(), c);
    }
    rebuild();
}

void CalendarController::setMockData()
{
    QVector<CalInfo> cals = {
        { "personal",  "Personal",  QColor("#34c3a3") },
        { "work",      "Work",      QColor("#6aa6f0") },
        { "birthdays", "Birthdays", QColor("#ef86b3") },
        { "focus",     "Focus",     QColor("#f0a35e") },
    };

    const QDate t = QDate::currentDate();
    auto at = [](const QDate &d, int h, int m) { return QDateTime(d, QTime(h, m)); };
    auto allDay = [](const QDate &d) { return QDateTime(d, QTime(0, 0)); };

    QVector<Event> events;
    int n = 0;
    auto add = [&](const QString &title, const QString &cal, const QColor &col,
                   const QDateTime &s, const QDateTime &e, bool ad = false) {
        events.append({ QString("mock-%1").arg(n++), title, cal, s, e, ad, col });
    };

    add("Morning standup",   "work",      QColor("#6aa6f0"), at(t, 9, 30),  at(t, 9, 45));
    add("Design review",     "work",      QColor("#6aa6f0"), at(t, 14, 0),  at(t, 15, 0));
    add("Gym",               "personal",  QColor("#34c3a3"), at(t, 18, 30), at(t, 19, 30));
    add("Deep work",         "focus",     QColor("#f0a35e"), at(t.addDays(1), 10, 0), at(t.addDays(1), 12, 0));
    add("Lunch w/ Sam",      "personal",  QColor("#34c3a3"), at(t.addDays(1), 12, 30), at(t.addDays(1), 13, 30));
    add("Dentist",           "personal",  QColor("#34c3a3"), at(t.addDays(2), 16, 0), at(t.addDays(2), 16, 45));
    add("Release cut",       "work",      QColor("#6aa6f0"), at(t.addDays(3), 11, 0), at(t.addDays(3), 11, 30));
    add("Mia's birthday",    "birthdays", QColor("#ef86b3"), allDay(t.addDays(3)), allDay(t.addDays(3)), true);
    add("Weekend trip",      "personal",  QColor("#34c3a3"), allDay(t.addDays(5)), allDay(t.addDays(6)), true);
    add("1:1 with manager",  "work",      QColor("#6aa6f0"), at(t.addDays(7), 15, 0), at(t.addDays(7), 15, 30));
    add("Write blog post",   "focus",     QColor("#f0a35e"), at(t.addDays(8), 9, 0), at(t.addDays(8), 11, 0));
    add("Team offsite",      "work",      QColor("#6aa6f0"), allDay(t.addDays(10)), allDay(t.addDays(10)), true);
    add("Call parents",      "personal",  QColor("#34c3a3"), at(t.addDays(-1), 19, 0), at(t.addDays(-1), 19, 30));
    add("Sprint planning",   "work",      QColor("#6aa6f0"), at(t.addDays(-2), 10, 0), at(t.addDays(-2), 11, 0));

    setSourceData("mock", cals, events);
}
