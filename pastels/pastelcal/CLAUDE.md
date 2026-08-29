# pastelcal

A **Qt 6 Quick** calendar styled by the shared `pasteltheme` module. Two data sources: **Google
Calendar** (OAuth2, read/write) and read‑only **iCal/ICS feeds**; ships with mock data so the UI
works offline. See `../CLAUDE.md` for family/theme wiring and `README.md` for account setup.

## Build & run

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/pastelcal
```

Qt modules include **`Network` + `NetworkAuth`**. QML is compiled in (URI `PastelCal`) → **rebuild
after `qml/` edits**; `../pasteltheme/` edits need no rebuild. `PASTELCAL_SCREENSHOT=/tmp/x.png` is an
offscreen render aid. Desktop entry `desktop_files/pastelcal.desktop` → `~/.local/share/applications`.

## Structure

- `src/main.cpp` — context props `Settings`, `Cal`, `Google`, `Ics`; theme import path; screenshot aid.
- `src/CalendarController` (`Cal`) — focused date + view (`month`/`agenda`), the calendar/event store,
  and query API the views bind (`monthCells`, `eventsOnIso`, `agenda`, `calendars`). **Merges named
  sources** (`mock`/`google`/`ics`) via `setSourceData()`; applies per‑calendar **colour overrides**.
- `src/GoogleCalendarService` (`Google`) — `QOAuth2AuthorizationCodeFlow` (loopback) + Calendar API v3;
  read scope + **write** (`createEvent`/`updateEvent`/`updateSeries`/`deleteEvent`). OAuth client
  id/secret come from the UI (persisted), env (`GOOGLE_OAUTH_CLIENT_ID`/`SECRET`), or
  `~/.config/PastelCal/google_client.json`. API failures surface the JSON `error.message`+`reason`
  (via `apiError()`), not just Qt's generic string, and are also logged to the console.
- **Recurrence**: `createEvent` takes an RRULE (`FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, empty = one-off) →
  `recurrence:["RRULE:…"]`. Events fetched with `singleEvents=true` are expanded instances carrying
  `recurringEventId` (the master). Editing a recurring event offers **This event** (PATCH the instance)
  vs **All events** (`updateSeries`: GET the master to keep the series' anchor date, then PATCH
  title/time to the whole series); delete-all removes the master. The Event model carries
  `recurringEventId`/`recurrence`; `eventMap` exposes `recurring` + `recurringEventId` to QML.
- `src/IcsService` (`Ics`) — fetches iCal URLs, parses `VEVENT` (all‑day + simple recurrence), feeds the
  `ics` source. Read‑only.
- `src/SettingsStore` (`Settings`) — theme keys (mirror pastelfm) + Google token/client + `icsFeeds`
  + hidden calendars + `calendarColors`.
- `qml/` — `Main`, `TopBar` (nav + view switch + New + account), `SideBar` (mini‑month + calendar list
  with colour picker + visibility), `MonthView`, `AgendaView`, `components/` (`EventChip`,
  `EventDialog` create/edit/delete, `SettingsDialog`).

## Conventions & gotchas

- **Writes are Google‑only** (its calendars carry a `writable` flag from `accessRole`); ICS is
  read‑only. `EventDialog` disables save unless a writable calendar exists.
- Google needs the user's **own** OAuth *Desktop* client with the read‑write `.../auth/calendar`
  scope; changing the scope requires re‑consent (Disconnect → Connect).
- Backends push events by ISO strings; the controller/query layer stays UI‑facing so **CalDAV** could
  be added as another source behind `setSourceData()`.
- Stale CMake cache after a move → `rm -rf build` and reconfigure.
