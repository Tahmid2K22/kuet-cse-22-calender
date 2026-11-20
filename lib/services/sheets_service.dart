import 'dart:convert';

import '../config/app_config.dart';
import 'calendar_data_source.dart';
import 'calendar_exception.dart';
import 'calendar_transport.dart';
import 'calendar_transport_factory.dart';

/// Fetches rows from the deployed Google Apps Script Web App.
///
/// The Web App is expected to return:
///
/// ```json
/// {
///   "ok": true,
///   "count": 2,
///   "events": [
///     {
///       "date": "2026-11-20",
///       "time": "10:00 AM",
///       "title": "Class Test 1",
///       "type": "Class Test",
///       "description": "Chapter 1",
///       "location": "Room 201"
///     }
///   ]
/// }
/// ```
///
/// A bare JSON array is also accepted for convenience when testing other
/// backends. All failures are converted into [CalendarException] so the UI
/// only needs to understand one error type.
///
/// The actual request is delegated to a [CalendarTransport]: HTTP on native
/// platforms and JSONP on the web. This class owns the transport only when it
/// creates the default one.
class SheetsService implements CalendarDataSource {
  SheetsService({
    CalendarTransport? transport,
    Uri? endpoint,
    bool useAppConfig = true,
  }) : _transport = transport ?? createCalendarTransport(),
       _ownsTransport = transport == null,
       _endpoint = endpoint ?? (useAppConfig ? AppConfig.endpointUri : null);

  final CalendarTransport _transport;
  final bool _ownsTransport;
  final Uri? _endpoint;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() async {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const CalendarException(
        kind: CalendarErrorKind.configuration,
        message: 'The Google Sheets endpoint is not configured.',
      );
    }

    // Apps Script responses can be cached by Google's CDN; a changing query
    // parameter keeps refresh results current.
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await _transport.get(uri);

    if (response.statusCode != 200) {
      throw CalendarException(
        kind: CalendarErrorKind.server,
        message:
            'The calendar service returned an error '
            '(HTTP ${response.statusCode}).',
        details: _shorten(response.body),
      );
    }

    final body = response.body.replaceFirst('\uFEFF', '').trim();

    if (body.isEmpty) {
      throw const CalendarException(
        kind: CalendarErrorKind.invalidResponse,
        message: 'The calendar service returned an empty response.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw CalendarException(
        kind: CalendarErrorKind.invalidResponse,
        message:
            'The calendar service did not return valid JSON. Check that the '
            'Web App is deployed with access set to "Anyone".',
        details: _shorten(body),
      );
    }

    return _extractRows(decoded);
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded) {
    if (decoded is List) {
      return _asRows(decoded);
    }

    if (decoded is Map) {
      final ok = decoded['ok'];
      if (ok == false) {
        throw CalendarException(
          kind: CalendarErrorKind.server,
          message: 'The calendar service reported an error.',
          details: decoded['error']?.toString(),
        );
      }

      for (final key in const ['events', 'data', 'rows']) {
        final value = decoded[key];
        if (value is List) return _asRows(value);
      }
    }

    throw const CalendarException(
      kind: CalendarErrorKind.invalidResponse,
      message:
          'The calendar response did not contain an events list. Check that '
          'the latest Apps Script version is deployed.',
    );
  }

  List<Map<String, dynamic>> _asRows(List<dynamic> rawRows) {
    final rows = <Map<String, dynamic>>[];
    for (final rawRow in rawRows) {
      if (rawRow is Map) {
        rows.add(
          rawRow.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    }
    return rows;
  }

  String _shorten(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 300) return compact;
    return '${compact.substring(0, 300)}…';
  }

  @override
  void dispose() {
    if (_ownsTransport) _transport.dispose();
  }
}
