import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'calendar_exception.dart';
import 'calendar_transport.dart';

/// Fetches the Web App over plain HTTP.
///
/// Used on Android, iOS and desktop. The browser never selects this file
/// because [createCalendarTransport] resolves to the JSONP implementation on
/// the web (see `calendar_transport_factory.dart`).
class HttpCalendarTransport extends CalendarTransport {
  HttpCalendarTransport({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _timeout = timeout ?? AppConfig.requestTimeout;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  @override
  Future<CalendarTransportResponse> get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw const CalendarException(
        kind: CalendarErrorKind.timeout,
        message: 'The calendar request timed out. Please try again.',
      );
    } on http.ClientException catch (error) {
      throw CalendarException(
        kind: CalendarErrorKind.network,
        message: 'Could not reach the calendar service. Check your internet connection.',
        details: error.message,
      );
    } catch (error) {
      throw CalendarException(
        kind: CalendarErrorKind.network,
        message: 'Could not reach the calendar service. Check your internet connection.',
        details: error.toString(),
      );
    }

    return CalendarTransportResponse(
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Factory selected by the conditional export on native platforms.
CalendarTransport createCalendarTransport() => HttpCalendarTransport();
