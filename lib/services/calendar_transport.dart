/// A raw response returned by a [CalendarTransport].
///
/// The transport only moves bytes; interpreting the status code and decoding
/// the JSON stays in `SheetsService` so every platform behaves the same.
class CalendarTransportResponse {
  const CalendarTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// Platform-specific way of fetching the calendar endpoint.
///
/// Native builds (Android, iOS, desktop) use HTTP. Web builds use JSONP
/// because Google Apps Script cannot send CORS headers.
abstract class CalendarTransport {
  Future<CalendarTransportResponse> get(Uri uri);

  /// Releases any resources owned by the transport.
  void dispose() {}
}
