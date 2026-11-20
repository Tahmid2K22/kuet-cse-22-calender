/// Selects the transport that matches the current platform.
///
/// - Android, iOS and desktop: HTTP (`dart:io` / `package:http`).
/// - Web: JSONP, because Apps Script responses do not include CORS headers.
library;

export 'http_calendar_transport.dart'
    if (dart.library.js_interop) 'jsonp_calendar_transport.dart';
