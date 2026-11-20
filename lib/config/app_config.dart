/// Static application configuration.
///
/// The Apps Script deployment URL is **not** committed to this repository.
/// Supply it when you build or run:
///
/// ```sh
/// flutter run --dart-define=CALENDAR_ENDPOINT=https://script.google.com/macros/s/XXXX/exec
/// ```
///
/// `tool/deploy_web.ps1` reads it from the `CALENDAR_ENDPOINT` environment
/// variable or from the git-ignored `tool/secrets.json`.
abstract final class AppConfig {
  static const String appName = 'KUET CSE 22 Calender';

  /// Name of the tab in the Google Spreadsheet. The Apps Script falls back to
  /// the first tab when a tab with this exact name is not found.
  static const String sheetName = 'Academic Calendar';

  /// Google Apps Script Web App URL, ending in `/exec`.
  ///
  /// Empty unless `--dart-define=CALENDAR_ENDPOINT=...` is passed at build
  /// time. The same URL is used on every platform. Web builds fetch it with
  /// JSONP because Apps Script responses do not include CORS headers; native
  /// builds use a normal HTTP request.
  ///
  /// When it is empty the app shows the "Calendar not connected" card instead
  /// of making a request, so a clone of this repository never points at
  /// someone else's deployment.
  static const String calendarEndpoint = String.fromEnvironment(
    'CALENDAR_ENDPOINT',
  );

  /// Maximum time to wait for the Web App before showing a retry option.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Parsed endpoint, or `null` when it is missing/invalid.
  static Uri? get endpointUri {
    final raw = calendarEndpoint.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;

    // Guard against the placeholder from older setup guides.
    if (uri.path.contains('REPLACE_WITH')) return null;

    return uri;
  }

  static bool get isConfigured => endpointUri != null;
}
