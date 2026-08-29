# pastelcal

A pastel + glass **calendar** app for the desktop — a sibling of `pastelbar`
(Quickshell shell) and `pastelfm` (file manager). Qt 6 / QML, styled by the
shared **`pasteltheme`** module (same 6 palettes, light/dark/auto, glass/glow).

- **Month** and **Agenda** views over your calendars.
- **iCal / ICS feeds** — read *any* calendar by URL, no sign-in (the easy path).
- **Google Calendar** sign-in via OAuth2 (optional; for future read/write).
- Runs on **sample data** out of the box, so the UI is usable before you add
  anything.

## Build & run

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/pastelcal
```

The shared theme module lives at `~/dotfiles/pastels/pasteltheme`. If you keep it
elsewhere, point the app at the directory that *contains* it:

```sh
PASTEL_QML_IMPORT_PATH=/path/that/contains/pasteltheme ./build/pastelcal
```

Headless render check: `QT_QPA_PLATFORM=offscreen PASTELCAL_SCREENSHOT=/tmp/cal.png ./build/pastelcal`.

## Reading a calendar by URL (iCal / ICS — no sign-in)

The simplest way to see your own events. Open **Settings → Calendar feeds** and
paste a calendar's iCal URL, then **Add**.

- **Google:** Calendar settings → *Settings for my calendars* → pick a calendar →
  **Integrate calendar** → copy **“Secret address in iCal format”** (or “Public
  address” for a public calendar). `webcal://` links work too.
- **Nextcloud / Fastmail / iCloud / others:** use their published ICS/iCal link.

Feeds are read-only, fetched on launch and via the **↻** refresh button. All-day
events and simple recurring events (daily/weekly/monthly/yearly) are supported.

## Connecting Google Calendar (optional, later)

Only needed for account sign-in / future write access. Google requires **your
own** OAuth client (they don't allow shipping a shared secret for desktop apps).
One-time setup:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) → create
   (or pick) a project.
2. **APIs & Services → Library →** enable **Google Calendar API**.
3. **APIs & Services → OAuth consent screen**: choose *External*, fill the app
   name/email, add the scopes `.../auth/calendar` (read **and** write, so you can
   add/edit events) and `.../auth/userinfo.email`, and add your Google address
   under *Test users*.
4. **APIs & Services → Credentials → Create credentials → OAuth client ID**,
   application type **Desktop app**. Copy the **Client ID** and **Client secret**.
5. Give them to pastelcal in **one** of these ways:
   - Environment variables:
     ```sh
     export GOOGLE_OAUTH_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
     export GOOGLE_OAUTH_CLIENT_SECRET=xxxxxxxx
     ./build/pastelcal
     ```
   - Or drop the credentials JSON you can download from the console at
     `~/.config/PastelCal/google_client.json` (the `{ "installed": { ... } }`
     file is read as-is).
6. Launch pastelcal and click **Connect Google** (top-right). Your browser opens
   for consent; the app captures the token on a local loopback port, then loads
   your calendars and events. The refresh token is stored in
   `~/.config/PastelCal` so you stay signed in.

Nothing is committed: credentials come from env or your local config dir only.

## Architecture

- `src/CalendarController` — focused date + view, the calendar/event store, and
  the per-day / agenda query API the QML views bind to. Ships mock data via
  `setMockData()`; a backend replaces it through `setData()`.
- `src/GoogleCalendarService` — `QOAuth2AuthorizationCodeFlow` (loopback) +
  Calendar API v3; feeds the controller. Designed behind the controller's
  `setData()` seam so **CalDAV / ICS / local** backends can be added later.
- `src/SettingsStore` — QSettings (theme keys mirror pastelfm, plus the Google
  token and hidden-calendar set).
- `qml/` — `Main`, `TopBar`, `SideBar`, `MonthView`, `AgendaView`, and
  `components/{EventChip,SettingsDialog}`, all styled with `import pasteltheme`.

### Creating / editing events
Once a Google account is connected (with the read-write `.../auth/calendar`
scope), use **＋ New** in the top bar — or click an empty day / an existing
event — to add, edit or delete events. Changes are written via the Calendar API
and re-fetched. iCal (ICS) feeds are read-only.

### Roadmap
Week/Day views, richer recurrence editing, and a native CalDAV source.
