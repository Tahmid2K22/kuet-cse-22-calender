/**
 * KUET CSE 22 Calender — Google Apps Script Web App
 * =================================================
 *
 * Reads the "Academic Calendar" sheet and returns JSON for the Flutter app.
 *
 * Sheet columns (row 1 must contain these headers):
 *   A: Date | B: Time | C: Title | D: Type | E: Description | F: Location
 *
 * The app runs on Android and on the web. Native builds fetch plain JSON.
 * Web builds send `?callback=name` and receive `name("...json...");` because
 * browsers block cross-origin JSON requests to Apps Script (no CORS headers).
 *
 * Setup:
 *   1. Open your Google Sheet named "Academic Calendar".
 *   2. Extensions > Apps Script, delete the placeholder code and paste this file.
 *   3. Project Settings > Script Properties, add:
 *        SPREADSHEET_ID = <the spreadsheet id from the sheet URL>
 *      Skip this only when the script is bound to the sheet.
 *   4. Save, then Deploy > New deployment > Web app.
 *      - Description: KUET CSE 22 Calender API
 *      - Execute as: Me
 *      - Who has access: Anyone
 *   5. Authorize, copy the /exec URL and keep it out of source control. Pass it
 *      to the Flutter app with --dart-define=CALENDAR_ENDPOINT=...
 *
 * After editing this code you must deploy a NEW VERSION:
 *   Deploy > Manage deployments > edit the active deployment > Version: New version.
 *
 * This file is standalone (no libraries) and deliberately contains no
 * spreadsheet ID or deployment URL, so it is safe to keep in a public repo.
 */

const SHEET_NAME = 'Academic Calendar';
const HEADER_ROW = 1;

/** Script property that holds the spreadsheet ID. */
const SPREADSHEET_ID_PROPERTY = 'SPREADSHEET_ID';

/**
 * Abuse guard. Apps Script does not expose the caller's IP, so this is a
 * global cap per minute rather than a per-client limit. It is deliberately
 * generous: a normal user refreshes a handful of times per minute.
 */
const RATE_LIMIT_WINDOW_SECONDS = 60;
const RATE_LIMIT_MAX_REQUESTS = 90;

/** Error codes that are safe to show in the app. */
const PUBLIC_ERRORS = {
  'missing-spreadsheet-id':
    'The calendar is not configured. Set the SPREADSHEET_ID script property.',
  'missing-sheet': 'No sheet was found in the spreadsheet.',
};

/** Fallback column indexes if the header names are missing (0-based). */
const COLUMN_INDEX = {
  date: 0,
  time: 1,
  title: 2,
  type: 3,
  description: 4,
  location: 5,
};

/**
 * GET endpoint used by the Flutter app.
 *
 * Plain request: JSON. Request with `?callback=name`: JSONP for the web app.
 */
function doGet(e) {
  const callback = e && e.parameter ? e.parameter.callback : '';

  if (!allowRequest_()) {
    return jsonResponse_(
      {
        ok: false,
        count: 0,
        error: 'Too many requests. Please try again in a minute.',
        events: [],
      },
      callback
    );
  }

  try {
    return jsonResponse_(readEvents_(), callback);
  } catch (error) {
    // Full details go to the server log only; the client gets a safe message.
    console.error(error && error.stack ? error.stack : error);
    return jsonResponse_(
      {
        ok: false,
        count: 0,
        error: publicErrorMessage_(error),
        events: [],
      },
      callback
    );
  }
}

/** Anything other than GET is rejected instead of hitting the sheet. */
function doPost() {
  return jsonResponse_(
    { ok: false, count: 0, error: 'Method not allowed.', events: [] },
    ''
  );
}

/**
 * Counts requests in the current one-minute window and refuses once the cap
 * is reached. CacheService is shared by the whole deployment.
 */
function allowRequest_() {
  try {
    const cache = CacheService.getScriptCache();
    const window = Math.floor(
      Date.now() / (RATE_LIMIT_WINDOW_SECONDS * 1000)
    );
    const key = 'rate:' + window;
    const used = Number(cache.get(key) || 0);

    if (used >= RATE_LIMIT_MAX_REQUESTS) return false;

    cache.put(key, String(used + 1), RATE_LIMIT_WINDOW_SECONDS + 5);
    return true;
  } catch (error) {
    // If the cache is unavailable, prefer serving the calendar over failing.
    console.error('Rate limiter unavailable: ' + error);
    return true;
  }
}

/**
 * Reads every data row and returns a sorted, JSON-safe payload.
 */
function readEvents_() {
  const spreadsheet = getSpreadsheet_();
  const sheet =
    spreadsheet.getSheetByName(SHEET_NAME) || spreadsheet.getSheets()[0];

  if (!sheet) {
    throw new Error('missing-sheet');
  }

  const timezone =
    spreadsheet.getSpreadsheetTimeZone() ||
    Session.getScriptTimeZone() ||
    'UTC';

  const values = sheet.getDataRange().getValues();
  const emptyPayload = {
    ok: true,
    count: 0,
    skipped: 0,
    timezone: timezone,
    generatedAt: new Date().toISOString(),
    events: [],
  };

  if (values.length < HEADER_ROW + 1) return emptyPayload;

  const headers = values[HEADER_ROW - 1].map(normalizeHeader_);
  const index = {};
  Object.keys(COLUMN_INDEX).forEach(function (key) {
    const found = headers.indexOf(key);
    index[key] = found === -1 ? COLUMN_INDEX[key] : found;
  });

  const events = [];
  let skipped = 0;

  for (let rowIndex = HEADER_ROW; rowIndex < values.length; rowIndex++) {
    const row = values[rowIndex];

    // Skip fully empty rows (including rows with only whitespace).
    if (!row || row.every(isBlank_)) continue;

    const date = normalizeDate_(row[index.date], timezone);
    const title = clean_(row[index.title]);

    // A row without a readable date or title cannot be placed on the calendar.
    if (!date || !title) {
      skipped++;
      continue;
    }

    const type = clean_(row[index.type]);

    events.push({
      date: date,
      time: normalizeTime_(row[index.time], timezone),
      title: title,
      type: type || 'Unspecified',
      description: clean_(row[index.description]),
      location: clean_(row[index.location]),
    });
  }

  events.sort(function (a, b) {
    if (a.date !== b.date) return a.date < b.date ? -1 : 1;
    const timeDiff = timeToMinutes_(a.time) - timeToMinutes_(b.time);
    if (timeDiff !== 0) return timeDiff;
    return a.title.toLowerCase() < b.title.toLowerCase() ? -1 : 1;
  });

  return {
    ok: true,
    count: events.length,
    skipped: skipped,
    timezone: timezone,
    generatedAt: new Date().toISOString(),
    events: events,
  };
}

/* -------------------------------------------------------------------------- */
/* Helpers                                                                     */
/* -------------------------------------------------------------------------- */

function getSpreadsheet_() {
  const configured = PropertiesService.getScriptProperties().getProperty(
    SPREADSHEET_ID_PROPERTY
  );

  if (configured) return SpreadsheetApp.openById(configured);

  const active = SpreadsheetApp.getActiveSpreadsheet();
  if (!active) {
    throw new Error('missing-spreadsheet-id');
  }
  return active;
}

function normalizeHeader_(value) {
  return String(value === null || value === undefined ? '' : value)
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function isBlank_(value) {
  return value === null || value === undefined || String(value).trim() === '';
}

function clean_(value) {
  if (value === null || value === undefined) return '';
  return String(value).trim();
}

/**
 * Converts a sheet date cell into `YYYY-MM-DD`.
 *
 * Handles real date cells (Date), ISO text, timestamps and numeric serials.
 * Returns an empty string when the value cannot be interpreted.
 */
function normalizeDate_(value, timezone) {
  if (isBlank_(value)) return '';

  if (value instanceof Date && !isNaN(value.getTime())) {
    return Utilities.formatDate(value, timezone, 'yyyy-MM-dd');
  }

  // Google Sheets serial number (days since 1899-12-30).
  if (typeof value === 'number' && isFinite(value)) {
    const utcMillis = Math.round((value - 25569) * 86400 * 1000);
    return Utilities.formatDate(new Date(utcMillis), 'UTC', 'yyyy-MM-dd');
  }

  const text = String(value).trim();
  const match = text.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);

  if (match) {
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);

    // Reject impossible dates such as 2026-02-31.
    const probe = new Date(Date.UTC(year, month - 1, day));
    if (
      probe.getUTCFullYear() !== year ||
      probe.getUTCMonth() !== month - 1 ||
      probe.getUTCDate() !== day
    ) {
      return '';
    }

    return (
      pad4_(year) + '-' + pad2_(month) + '-' + pad2_(day)
    );
  }

  const parsed = new Date(text);
  if (!isNaN(parsed.getTime())) {
    return Utilities.formatDate(parsed, timezone, 'yyyy-MM-dd');
  }

  return '';
}

/**
 * Converts a sheet time cell into a display string such as `10:00 AM`.
 *
 * Handles real time cells (Date), 12/24-hour text, seconds and ISO timestamps.
 * Ranges such as `10:00 AM - 11:30 AM` are preserved.
 */
function normalizeTime_(value, timezone) {
  if (isBlank_(value)) return '';

  if (value instanceof Date && !isNaN(value.getTime())) {
    return Utilities.formatDate(value, timezone, 'h:mm a');
  }

  if (typeof value === 'number' && isFinite(value)) {
    const totalMinutes = Math.round((value % 1) * 24 * 60) % (24 * 60);
    return formatMinutes_(totalMinutes);
  }

  const text = String(value).trim().replace(/^'/, '');

  const match = text.match(
    /^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([APap][Mm])?$/
  );

  if (match) {
    let hour = Number(match[1]);
    const minute = Number(match[2]);
    const period = match[4] ? match[4].toUpperCase() : '';

    if (period) {
      if (hour < 1 || hour > 12) return text;
      hour = hour % 12;
      if (period === 'PM') hour += 12;
    } else if (hour > 23) {
      return text;
    }

    return formatMinutes_(hour * 60 + minute);
  }

  const isoMatch = text.match(/T(\d{1,2}):(\d{2})/);
  if (isoMatch) {
    return formatMinutes_(Number(isoMatch[1]) * 60 + Number(isoMatch[2]));
  }

  // Unrecognised formats are passed through so the app can still show them.
  return text;
}

function formatMinutes_(minutes) {
  const hour24 = Math.floor(minutes / 60) % 24;
  const minute = minutes % 60;
  const period = hour24 >= 12 ? 'PM' : 'AM';
  const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;
  return hour12 + ':' + pad2_(minute) + ' ' + period;
}

/** Minutes since midnight for sorting. Unknown times go last. */
function timeToMinutes_(value) {
  const firstPart = String(value || '')
    .split(/\s*(?:-|–|—|to)\s*/i)[0]
    .trim();

  const match = firstPart.match(/^(\d{1,2}):(\d{2})\s*([APap][Mm])?$/);
  if (!match) return 24 * 60 + 1;

  let hour = Number(match[1]);
  const minute = Number(match[2]);
  const period = match[3] ? match[3].toUpperCase() : '';

  if (period === 'AM' && hour === 12) hour = 0;
  if (period === 'PM' && hour !== 12) hour += 12;

  return hour * 60 + minute;
}

function pad2_(value) {
  return String(value).padStart(2, '0');
}

function pad4_(value) {
  return String(value).padStart(4, '0');
}

/**
 * Builds the response. Without a callback this is plain JSON; with a valid
 * callback it is `callback("...json...");`.
 *
 * `<` is escaped as `\u003c` so the payload can never terminate a script tag
 * or start an HTML comment, even if a sheet cell contains markup.
 */
function jsonResponse_(payload, callback) {
  const json = escapeForScript_(JSON.stringify(payload));
  const safeCallback = normalizeCallback_(callback);

  if (!safeCallback) {
    return ContentService.createTextOutput(json).setMimeType(
      ContentService.MimeType.JSON
    );
  }

  const body = safeCallback + '(' + JSON.stringify(json) + ');';
  return ContentService.createTextOutput(body).setMimeType(
    ContentService.MimeType.JAVASCRIPT
  );
}

/**
 * Escapes characters that can end a `<script>` element or break a JavaScript
 * string literal, even when a sheet cell contains markup. JSON.stringify does
 * not escape U+2028/U+2029, which are invalid in older JS string literals.
 */
function escapeForScript_(text) {
  return String(text)
    .replace(/</g, '\\u003c')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
}

/**
 * Accepts only a simple JavaScript identifier such as `__academicCalendar...`.
 * Anything else falls back to plain JSON, so the parameter cannot inject code.
 */
function normalizeCallback_(callback) {
  const value = clean_(callback);
  return /^[A-Za-z_$][0-9A-Za-z_$]*$/.test(value) ? value : '';
}

/**
 * Maps internal errors to short, safe messages. Anything unrecognised becomes
 * a generic message so sheet IDs, URLs and stack details never reach the app.
 */
function publicErrorMessage_(error) {
  const message = error && error.message ? String(error.message) : String(error);
  return PUBLIC_ERRORS[message] || 'Unable to read the calendar right now.';
}

/**
 * Run this from the Apps Script editor (Run > checkSetup) when the Web App
 * reports "not configured". It prints which script properties exist and
 * whether the spreadsheet opens, without printing the full sheet ID.
 */
function checkSetup() {
  const properties = PropertiesService.getScriptProperties().getProperties();
  const keys = Object.keys(properties);

  Logger.log('Script property keys: ' + (keys.length ? keys.join(', ') : '(none)'));
  Logger.log(
    'SPREADSHEET_ID: ' +
      (properties[SPREADSHEET_ID_PROPERTY]
        ? 'set (' + properties[SPREADSHEET_ID_PROPERTY].length + ' characters)'
        : 'MISSING')
  );

  const id = properties[SPREADSHEET_ID_PROPERTY];
  if (!id) return;

  try {
    const spreadsheet = SpreadsheetApp.openById(id.trim());
    Logger.log('Spreadsheet: ' + spreadsheet.getName());
    Logger.log(
      'Sheets: ' +
        spreadsheet
          .getSheets()
          .map(function (sheet) {
            return sheet.getName();
          })
          .join(', ')
    );
  } catch (error) {
    Logger.log('openById failed: ' + error);
  }
}

/**
 * Run this from the Apps Script editor (Run > testReadEvents) to inspect the
 * JSON payload in the execution log before deploying.
 */
function testReadEvents() {
  Logger.log(JSON.stringify(readEvents_(), null, 2));
}
