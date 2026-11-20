/// Machine-readable reasons for a failed calendar load.
enum CalendarErrorKind {
  /// No Web App URL has been configured yet.
  configuration,

  /// The device could not reach the service.
  network,

  /// The request exceeded [AppConfig.requestTimeout].
  timeout,

  /// The Web App responded with a non-200 status.
  server,

  /// The response was not JSON in the expected shape.
  invalidResponse,
}

/// An expected, user-presentable failure while loading calendar data.
class CalendarException implements Exception {
  const CalendarException({
    required this.kind,
    required this.message,
    this.details,
  });

  final CalendarErrorKind kind;
  final String message;

  /// Short technical context for the error card. Never shown as a stack trace.
  final String? details;

  @override
  String toString() => 'CalendarException($kind): $message';
}
