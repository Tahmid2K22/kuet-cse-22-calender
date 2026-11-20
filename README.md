# KUET CSE 22 Calender

A focused Flutter (Material 3) app that visualises the **KUET CSE 22** academic
calendar on **Android and the web**. Every event comes from a Google Sheet
through a Google Apps Script Web App — there is no Firebase, authentication or
local database.

- Monthly calendar with swipe/arrow navigation, today highlight and date
  selection.
- Six event types with the requested colours: **Class** (light blue), **Exam**
  (yellow), **Deadline** (salmon), **Holiday** (green), **Event** (pink) and
  **Meeting** (violet).
- Dates with events get a coloured **ring around the date number**. If a date
  has several types, the ring uses the highest priority:
  **red → yellow → blue → violet → green → pink**
  (Deadline → Exam → Class → Meeting → Holiday → Event).
- Green and white theme with a deep green brand colour (`#146B45`).
- Responsive layout: on phones the selected-date details sit below the calendar;
  on screens at least 900 px wide the calendar and details sit side by side.
- Pull-to-refresh plus an app-bar refresh button, loading and error states, and
  a non-blocking notice for unreadable sheet rows.
- The web build loads the same Web App with JSONP, so it works even though
  Google Apps Script does not send CORS headers.

---

## 1. Architecture and data flow

```
Google Sheet (A:F)
        │
        │  doGet() reads all rows (row 1 = headers)
        ▼
Apps Script Web App  ──►  JSON { ok, count, events:[...] }
        │                 (or JSONP when ?callback=name is present)
        │
        ├── Android / iOS / desktop: HTTPS GET (20 s timeout)
        └── Web: <script src="...&callback=...">
        ▼
CalendarTransport (HTTP or JSONP)  ──►  raw status + body
        │
        ▼
SheetsService  ──►  validates HTTP status, JSON shape and errors
        │
        ▼
EventRepository  ──►  CalendarEvent.tryParse() per row, skips bad rows,
        │             sorts by date + time, groups by day
        ▼
CalendarScreen (loading / ready / error state, focused month, selected day)
        │
        ├──► CalendarWidget (table_calendar) — priority ring + type dots
        └──► EventList → EventCard — details for the selected date
```

### Layers

| Layer | Location | Responsibility |
|---|---|---|
| Config | `lib/config/` | Endpoint from `--dart-define`, timeout, green palette, theme, event colours |
| Models | `lib/models/` | `CalendarEvent`, `EventType` (`fromRawType` maps the sheet value and priority) |
| Services | `lib/services/` | `CalendarDataSource`, `CalendarTransport` (HTTP/JSONP), `SheetsService`, `EventRepository`, `CalendarException` |
| Utils | `lib/utils/` | Strict date parsing, time parsing/formatting, display formatters |
| Widgets | `lib/widgets/` | Calendar card, legend, event card/list, loading/error/empty views |
| Screens | `lib/screens/` | `CalendarScreen` state machine, responsive layout and user interaction |

### Project structure

```
academic_calendar/
├── android/
├── apps_script/
│   └── AcademicCalendarApi.gs     # paste into Google Apps Script
├── web/
│   ├── index.html                 # title, green theme, CSP, noindex
│   ├── flutter_bootstrap.js       # self-hosted CanvasKit config
│   ├── manifest.json              # PWA metadata
│   ├── robots.txt                 # keep the site out of search engines
│   ├── favicon.svg
│   ├── favicon.png
│   └── icons/
├── lib/
│   ├── app.dart
│   ├── main.dart
│   ├── config/
│   │   ├── app_config.dart        # app name + endpoint from --dart-define
│   │   └── app_theme.dart         # green palette + EventPalette
│   ├── models/
│   │   ├── calendar_event.dart
│   │   └── event_type.dart
│   ├── screens/
│   │   └── calendar_screen.dart
│   ├── services/
│   │   ├── calendar_data_source.dart
│   │   ├── calendar_exception.dart
│   │   ├── calendar_transport.dart
│   │   ├── calendar_transport_factory.dart  # HTTP or JSONP, per platform
│   │   ├── http_calendar_transport.dart
│   │   ├── jsonp_calendar_transport.dart
│   │   ├── event_repository.dart
│   │   └── sheets_service.dart
│   ├── utils/
│   │   └── date_time_utils.dart
│   └── widgets/
│       ├── calendar_widget.dart
│       ├── event_card.dart
│       ├── event_list.dart
│       ├── legend.dart
│       └── status_views.dart
├── sample/
│   └── academic_calendar_sample.csv
├── tool/
│   ├── deploy_web.ps1             # build + publish to gh-pages
│   └── secrets.example.json       # copy to secrets.json (git-ignored)
├── test/
│   ├── date_time_utils_test.dart
│   ├── event_repository_test.dart
│   ├── http_calendar_transport_test.dart
│   ├── sheets_service_test.dart
│   └── widget_test.dart
└── pubspec.yaml
```

### Data contract

`GET <WEB_APP_URL>` returns:

```json
{
  "ok": true,
  "count": 2,
  "skipped": 0,
  "timezone": "Asia/Dhaka",
  "generatedAt": "2026-11-19T10:00:00.000Z",
  "events": [
    {
      "date": "2026-11-20",
      "time": "10:00 AM",
      "title": "Data Structures",
      "type": "Class",
      "description": "Graph traversal",
      "location": "Room 201"
    },
    {
      "date": "2026-11-22",
      "time": "2:30 PM",
      "title": "Class Test 2",
      "type": "Exam",
      "description": "Chapters 1-4",
      "location": "Room 201"
    }
  ]
}
```

- `date` is always `YYYY-MM-DD`.
- `time` is display text (`10:00 AM`, `2:30 PM`, ranges allowed). The app parses
  the first time for sorting and keeps the original label visible.
- `type` keeps the sheet label and chooses the colour category. Unknown values
  and an empty `Type` fall back to **Deadline** (red), so they are never
  invisible.
- Rows with an unreadable date or an empty title are skipped and counted in
  `skipped`; the rest of the calendar still loads.

The same payload has two envelopes:

- `GET <WEB_APP_URL>` → plain JSON (`Content-Type: application/json`).
- `GET <WEB_APP_URL>?callback=name` → `name("...json...");`
  (`Content-Type: text/javascript`).

Native builds always use the first form. The web build uses the second
automatically. `SheetsService` receives the JSON text either way and validates
it in one place.

---

## 2. Google Sheets setup

The script contains **no spreadsheet ID**. It reads the ID from a **Script
Property** named `SPREADSHEET_ID`, so the ID never enters this repository.

1. Create a Google Spreadsheet (or open your existing one).
2. Name the first tab **Academic Calendar** if you want the script's preferred
   name. The script falls back to the first tab, so any tab name works.
3. Put these headers in row 1, in this order:

   | A | B | C | D | E | F |
   |---|---|---|---|---|---|
   | Date | Time | Title | Type | Description | Location |

4. Add events starting in row 2. Example:

   | Date | Time | Title | Type | Description | Location |
   |---|---|---|---|---|---|
   | 2026-11-20 | 10:00 AM | Data Structures | Class | Graph traversal | Room 201 |
   | 2026-11-22 | 02:30 PM | Class Test 2 | Exam | Chapters 1-4 | Room 201 |
   | 2026-11-23 | 11:59 PM | Assignment Submission | Deadline | Submit online | Online |
   | 2026-11-25 | 09:00 AM | Project Meeting | Meeting | Sprint review | Lab 2 |
   | 2026-11-26 | All Day | Semester Break | Holiday | No classes | — |
   | 2026-11-28 | 10:00 AM | CSE Fest | Event | Department festival | Main Auditorium |

5. Date formatting tips:
   - Use real date cells (Format > Number > Date) **or** text in `YYYY-MM-DD`
     form. Both work.
   - Keep time in its own column. Text (`10:00 AM`), time cells and 24-hour
     values (`14:30`) are all normalised by the script.
   - Check **File > Settings > Time zone**; it is used when converting date and
     time cells. The shared sheet is set to `Asia/Dhaka`; keep it there or your
     dates will shift.

6. Copy the spreadsheet ID from the sheet URL:

   ```
   https://docs.google.com/spreadsheets/d/<SPREADSHEET_ID>/edit
   ```

   You will paste it into the Apps Script's **Script Properties** in section 3.
   Do not put it in a file that is committed to the repository.

7. Keep the sheet **private**: Share → General access → **Restricted**. The Apps
   Script runs as you, so it can read the sheet without making it public.

A ready-to-import sample is at `sample/academic_calendar_sample.csv`.

### Supported `Type` values

| Type | Colour | Ring priority | Common matching values |
|---|---|---|---|
| Deadline | salmon `#F28C8C` | 1 (highest) | `Deadline`, `Due`, `Submission`, `Assignment`, `Homework`, any unknown value |
| Exam | yellow `#E6D44F` | 2 | `Exam`, `Test`, `Quiz`, `Midterm`, `Final`, `Viva`, `Class Test` |
| Class | light blue `#C9DDF8` | 3 | `Class`, `Lecture`, `Lab`, `Tutorial`, `Extra Class`, `Presentation` |
| Meeting | violet `#C9D1F4` | 4 | `Meeting`, `Seminar`, `Workshop`, `Discussion`, `Conference` |
| Holiday | green `#4CAF7D` | 5 | `Holiday`, `Vacation`, `Break`, `Recess`, `Closure` |
| Event | pink `#F3C6E3` | 6 (lowest) | `Event`, `Program`, `Fest`, `Ceremony`, `Sports`, `Tour`, `Cultural` |

Matching is case-insensitive and ignores spaces and punctuation, so
`extra-class`, `ExtraClass` and `EXTRACLASS` all become **Class**.

You do not configure colours per date. The mapping is two functions:

```text
EventType.fromRawType()  →  EventPalette.colorOf()       (legend / tint)
                         →  EventPalette.ringColorOf()   (date ring / dots)
                         →  EventPalette.strongColorOf() (accent / badge text)
```

When one date has several events, `EventType.highestPriorityOf()` picks the ring
colour. The small dots under the date still show up to three individual types.

---

## 3. Deploy the Google Apps Script

The script works as a standalone Apps Script project. You can also bind it to
the sheet with **Extensions → Apps Script**; a bound script finds the sheet
automatically and the property below is optional.

1. Open <https://script.google.com> and create a new project (or open the sheet
   and choose **Extensions → Apps Script**).
2. Delete the placeholder `myFunction` and paste the full contents of
   [`apps_script/AcademicCalendarApi.gs`](apps_script/AcademicCalendarApi.gs).
3. Open **Project Settings → Script Properties → Add script property** and add:
   - **Property:** `SPREADSHEET_ID`
   - **Value:** the ID you copied in section 2
4. Save (Ctrl/Cmd + S). Optionally run `testReadEvents` from the editor and
   check the execution log to confirm the JSON.
5. Click **Deploy → New deployment**.
6. Choose **Web app**.
7. Configure:
   - **Description:** KUET CSE 22 Calender API
   - **Execute as:** Me
   - **Who has access:** **Anyone**
8. Click **Deploy**, review the permissions and click **Authorize access**
   (choose your Google account, then allow the script).
9. Copy the **Web app URL**. It looks like:

   ```
   https://script.google.com/macros/s/AKfycb.../exec
   ```

   Keep it out of the repository; section 4 shows where to put it.

> **Access must be "Anyone"**, not "Anyone with a Google account". The app does
> not send Google credentials, so an authenticated deployment will return a
> login page instead of JSON.

> **The sheet link is not the API link.** The app cannot read
> `https://docs.google.com/spreadsheets/d/.../edit` directly. It needs the
> Apps Script `/exec` URL.

### Updating the script later

Editing the code is not enough. Go to **Deploy → Manage deployments**, edit the
active deployment, set **Version** to **New version**, and click **Deploy**. The
`/exec` URL stays the same.

This matters for the web build: the `?callback=` support described below only
works after the updated script is deployed as a new version.

### Testing the endpoint

Open the `/exec` URL in a browser. You should see raw JSON starting with
`{"ok":true,...}`. If you see an HTML sign-in page, the access setting is wrong.
If you see `{"ok":false,"error":"..."}`, the message describes the sheet problem.

Test JSONP by adding a callback:

```
https://script.google.com/macros/s/AKfycb.../exec?callback=testCb
```

You should see:

```js
testCb("{\"ok\":true,...}");
```

The callback name must be a simple JavaScript identifier. Invalid names fall
back to plain JSON, so the parameter cannot inject code.

---

## 4. Connect the Flutter app

The deployment URL is **not** stored in this repository. `lib/config/app_config.dart`
reads it from a compile-time define:

```dart
static const String calendarEndpoint = String.fromEnvironment(
  'CALENDAR_ENDPOINT',
);
```

Pass it when you run or build:

```sh
flutter run --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

For the deploy script, either set the environment variable for the session or
copy the example secrets file. Both locations are git-ignored:

```powershell
$env:CALENDAR_ENDPOINT = "https://script.google.com/macros/s/.../exec"

# or, once:
Copy-Item tool/secrets.example.json tool/secrets.json   # then edit the file
```

`tool/secrets.json`, `.env` and `tool/secrets.local.ps1` are ignored by git.
Never commit the real URL, and do not paste it into the README or an issue.

The URL is validated at startup. When it is missing or malformed the app shows a
"Calendar not connected" card with setup instructions instead of crashing, so a
fresh clone runs safely without pointing at someone else's deployment.

The same URL is used on Android and on the web. You do not configure a second
endpoint for the browser: the web build detects that it is running in a browser
and switches to JSONP automatically.

`android/app/src/main/AndroidManifest.xml` already includes the `INTERNET`
permission and the **KUET CSE 22 Calender** app label.

---

## 5. Run the app

### Requirements

- Flutter 3.47+ with Dart 3.13.3+ (tested with Flutter 3.47.4)
- For Android: Android Studio with an Android SDK and emulator, or a physical
  device
- For web: Chrome or Edge

### Android (VS Code)

1. Open the `academic_calendar` folder.
2. Run `flutter pub get` in the integrated terminal.
3. Start an emulator (or connect a device with USB debugging).
4. Press **F5**, or run (the endpoint is required):

   ```sh
   flutter run --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
   ```

### Android (Android Studio)

1. **File → Open** and select the `academic_calendar` folder.
2. Wait for the Gradle sync and `flutter pub get` to finish.
3. Select an emulator/device in the toolbar and click **Run**.
4. Without the define the app starts in its "Calendar not connected" state. To
   pass the URL from Android Studio, add it to the run configuration's
   **Additional run args**:

   ```
   --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
   ```

### Web (development)

```sh
flutter run -d chrome --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

`flutter run -d edge` works too. The app opens at a local development URL and
hot reload works normally.

### Web (release build)

```sh
flutter build web --release --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

For GitHub Pages, add the subpath:

```sh
flutter build web --release --base-href /kuet-cse-22-calender/ `
  --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

The output is written to `build/web/`. It must be served over HTTP(S); opening
`build/web/index.html` from the filesystem (`file://`) will not work.

Local preview:

```sh
cd build/web
python -m http.server 8080
```

Then open <http://localhost:8080>. Any static file server works
(`npx serve build/web`, `dart pub global run dhttpd`, etc.).

### Hosting the web build

The app is published on GitHub Pages:

**<https://tahmid2k22.github.io/kuet-cse-22-calender/>**

| Item | Value |
|---|---|
| Repository | <https://github.com/Tahmid2K22/kuet-cse-22-calender> |
| Source branch | `main` (Flutter project) |
| Published branch | `gh-pages` (contents of `build/web/`, plus `.nojekyll`) |
| Base href | `/kuet-cse-22-calender/` |

To publish a new build after changing the code:

```powershell
$env:CALENDAR_ENDPOINT = "https://script.google.com/macros/s/.../exec"
powershell -ExecutionPolicy Bypass -File tool\deploy_web.ps1
```

Or store the URL once in `tool/secrets.json` (git-ignored) and run only the
script. The script reads the URL, builds with the correct base href and define,
and force-pushes the result to `gh-pages`. GitHub Pages then republishes within
a minute or so. Event data comes from the sheet at runtime, so adding or editing
events does **not** need a rebuild.

`gh-pages` is generated output: do not edit it by hand. Change the source in
`main` and redeploy.

You can also upload the contents of `build/web/` to any other static host:
Firebase Hosting, Netlify, Cloudflare Pages, an S3 bucket, or your university's
web server.

If the app is served from a different subpath, build with a matching base href:

```sh
flutter build web --release --base-href /calendar/
```

No server-side proxy is needed. The browser loads the Apps Script response with
a `<script>` tag (JSONP), which is not subject to CORS.

### Release APK

```sh
flutter build apk --release --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The
define is required: without it the app installs but shows the "Calendar not
connected" card.

---

## 6. Behaviour and design notes

- **Calendar:** `table_calendar` in month mode, Monday-first week, six rows
  enforced so the layout does not jump between months. Adjacent-month days are
  dimmed; tapping one jumps to that month.
- **Date ring:** a date with at least one event draws a 2.2 px ring around its
  number using the highest-priority type colour. The ring is drawn outside a
  small white gap, so it stays visible when the date is selected (green fill) or
  is today.
- **Priority:** Deadline (red) → Exam (yellow) → Class (blue) → Meeting
  (violet) → Holiday (green) → Event (pink). This is the enum order and the
  `priority` getter in `EventType`.
- **Dots:** up to three small dots under the number show the individual types on
  that date, including types that did not win the ring.
- **Selection:** the detail section always follows the visible month. Moving to
  another month selects today (if it is in that month) or the first day.
- **Sorting:** date, then parsed time; untimed events appear last on their day.
- **Refresh:** pull down or tap the app-bar icon. A failed refresh keeps the
  last successful data on screen and shows a snackbar. A failed first load shows
  a retry card.
- **Skipped rows:** malformed sheet rows do not break the refresh; a subtle
  warning above the event list tells the user how many were skipped.
- **Responsive layout:** below 900 px the screen is the original single-column
  mobile layout. At 900 px and above, the calendar (left, 6/11 of the content)
  and the selected-date events (right, 5/11) are placed side by side inside a
  centred 1180 px column. Pull-to-refresh remains available; the app-bar
  refresh button works at every size.
- **Web loading:** `web/index.html` shows a small green-branded splash until
  Flutter paints its first frame, then removes it.
- **No extra features:** no Firebase, login, notifications, or admin UI.

### Web, CORS and JSONP

Google Apps Script's `ContentService` does not send
`Access-Control-Allow-Origin`, so a normal `fetch`/XHR from a browser is blocked
by CORS. The app does not use a proxy and does not weaken browser security.
Instead:

1. On the web, `calendar_transport_factory.dart` resolves to
   `jsonp_calendar_transport.dart` because of the
   `if (dart.library.js_interop)` conditional export.
2. That transport injects `<script src="<WEB_APP_URL>&callback=<uniqueName>">`.
3. The Apps Script sees `callback`, validates it as a simple identifier, and
   replies with `uniqueName("...json...");` using the JavaScript MIME type.
4. The script calls the temporary global function, the transport removes the
   script and the global, and the JSON is parsed by `SheetsService`.

Script tags are not subject to CORS, so this works from any static host. Native
builds use `http_calendar_transport.dart` and ordinary HTTP.

`<` is escaped as `\u003c` in both response forms, so a sheet cell cannot
terminate the script tag or start an HTML comment. JSONP executes the response
as JavaScript: only point the app at your own Apps Script deployment.

The web build ships its own policy in `web/index.html`. It allows same-origin
files, the Apps Script JSONP origins, Google's font CDN (CanvasKit downloads
Roboto from `fonts.gstatic.com`) and the Flutter WebAssembly engine. CanvasKit
itself is served from `canvaskit/` in the build, not from Google's CDN, because
`web/flutter_bootstrap.js` sets `canvasKitBaseUrl`. If you add another host,
update the meta tag and rebuild.

```text
script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'
           https://script.google.com https://script.googleusercontent.com;
connect-src 'self' blob: https://script.google.com
            https://script.googleusercontent.com https://fonts.gstatic.com;
font-src 'self' data: https://fonts.gstatic.com;
```

### Verification commands

```sh
flutter analyze
flutter test
flutter build web --release --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec
```

Tests cover date/time parsing (including invalid and range values), all six type
mappings and their aliases, priority ordering, sorting/grouping, skipped rows,
snapshot retention on failure, service parsing and cache busting, HTTP transport
status/timeout/network errors, widget rendering for populated and empty
calendars, the priority ring, and the responsive two-column layout.

---

## 7. Security

The calendar is meant to be readable by the whole batch, so the *event data* is
public by design. The protections below stop the repository and the deployment
from exposing anything beyond that.

### What is not in the repository

| Item | Where it lives instead |
|---|---|
| Spreadsheet ID | Apps Script **Script Properties** (`SPREADSHEET_ID`) |
| Apps Script `/exec` URL | `CALENDAR_ENDPOINT` at build time, or `tool/secrets.json` (git-ignored) |

`tool/secrets.json`, `.env` and `tool/secrets.local.ps1` are listed in
`.gitignore`. The source history was rebuilt to remove earlier copies of the
URL and sheet ID.

### Backend hardening (`apps_script/AcademicCalendarApi.gs`)

- Only `doGet` is implemented; `doPost` returns "Method not allowed".
- Requests are capped at 90 per minute per deployment using `CacheService`, and
  a burst returns a readable "Too many requests" error instead of reading the
  sheet.
- JSONP callback names must be a simple JavaScript identifier; anything else
  falls back to plain JSON, so the parameter cannot inject code.
- `<`, U+2028 and U+2029 are escaped, so a sheet cell cannot terminate the
  script tag or break a string literal.
- Errors are logged server-side and replaced with a short generic message.
  Sheet IDs, URLs and stack traces never reach the client.
- An empty `Type` is sent as `Unspecified` (red) rather than `Academic` (blue).

### Web hardening (`web/index.html`)

- A `Content-Security-Policy` meta tag allows only same-origin files, the Apps
  Script JSONP origins and the Flutter WebAssembly engine. `object-src 'none'`
  and `form-action 'none'` are set.
- `referrer` is `no-referrer`, so the app URL is not sent to Google with the
  JSONP request.
- `robots.txt` plus `<meta name="robots" content="noindex, nofollow, ...">` keep
  the site out of search results. This is obscurity, not access control.
- Release builds ship no source maps, and the Dart code is minified.

### The honest limitation

Without a server-side proxy, the deployment URL is compiled into
`main.dart.js` and is visible to anyone who opens DevTools. **No static web app
can hide an endpoint it calls.** With that in mind:

1. Keep the sheet itself **Restricted**. The script runs as you, so it can read
   the sheet without sharing it.
2. If the URL is ever exposed, create a **new deployment** and update
   `CALENDAR_ENDPOINT`. The old `/exec` stops working.
3. The rate limit keeps bulk scraping unattractive.

If you later want the URL truly hidden, put a small proxy (Cloudflare Worker,
Netlify Function, and so on) in front and keep the `/exec` URL as its secret.
Only the proxy URL would appear in the bundle.

### If a link leaks

1. Apps Script → **Deploy → Manage deployments** → archive the current
   deployment.
2. **Deploy → New deployment → Web app**, then copy the new `/exec` URL.
3. Update `CALENDAR_ENDPOINT` locally and redeploy the web app.
4. Rebuild the APK, since it embeds the URL too.

Rotating is the only real fix; deleting the string from a public repository does
not invalidate a URL that someone already copied.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Calendar not connected" | No `CALENDAR_ENDPOINT` was passed at build time, or it is malformed | Build or run with `--dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/.../exec` |
| `{"ok":false,"error":"The calendar is not configured..."}` | The `SPREADSHEET_ID` script property is missing | Add it under **Project Settings → Script Properties** and redeploy |
| `{"ok":false,"error":"Too many requests..."}` | More than 90 requests in a minute from the whole deployment | Wait a minute; raise `RATE_LIMIT_MAX_REQUESTS` only if you expect heavy use |
| HTML / sign-in page instead of JSON | Web App access is restricted | Redeploy with **Who has access: Anyone** |
| `{"ok":false,"error":"..."}` | Sheet/tab missing or script error | Check the tab name, run `testReadEvents`, read the error message |
| HTTP 404 / "Sorry, unable to open the file" | Wrong deployment URL or deleted deployment | Copy the URL from **Manage deployments** again |
| Changes in the sheet are not visible | Browser/CDN cache or app not refreshed | Pull down in the app; the app adds a cache-busting parameter |
| Script edits have no effect | Deployment version was not updated | **Manage deployments → Edit → New version → Deploy** |
| Events land on the wrong day | Sheet timezone or non-date text | Set **File → Settings → Time zone**; use date cells or `YYYY-MM-DD` |
| Some rows missing | Missing/invalid date or empty title | Check the warning count and the Date/Title columns |
| A type shows the wrong colour | The `Type` cell does not contain a recognised keyword | Use one of the values in the type table; unknown values intentionally render red |
| A date with several types shows only one ring | This is by design | The ring uses the highest priority; the dots below the number show the other types |
| App can't load on Android release | Missing internet permission | Already handled in `AndroidManifest.xml`; keep it when customising |
| Web: "Connection problem" or the request never finishes | Apps Script was not redeployed with `callback` support, or the URL is not the `/exec` URL | Deploy a new version; open `<url>?callback=testCb` and confirm it returns `testCb(...)` |
| Web: "did not return a JSONP response" | The endpoint returned a sign-in page or plain JSON instead of padded JavaScript | Set access to **Anyone**; use the `/exec` URL, not the sheet `/edit` URL |
| Web: browser console reports a CSP violation | The policy in `web/index.html` does not allow a new host you added | Add the host to `script-src`/`connect-src` in the meta tag, then rebuild |
| Web: app loads but the sheet link shows an error | The sheet URL was pasted instead of the Web App URL | Deploy the Apps Script and use its `/exec` URL |
| Web: blank page from `build/web/index.html` | Opened with `file://` | Serve the folder over HTTP, e.g. `python -m http.server` |
| Web: an old version keeps loading after redeploying | The Flutter service worker cached the previous build | Hard-refresh the page or clear site data for the app's origin |
| Web: "No events" although the sheet has rows | The selected day has no events, or the tab name is wrong | Pick a day with events; confirm the tab name or that the script is reading the first tab |
