import 'dart:async';

import 'package:academic_calendar/services/calendar_exception.dart';
import 'package:academic_calendar/services/http_calendar_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Uri get _endpoint =>
    Uri.parse('https://script.google.com/macros/s/test-deployment/exec');

void main() {
  test('returns the status code and decoded body', () async {
    late http.Request captured;

    final transport = HttpCalendarTransport(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ok":true,"events":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await transport.get(_endpoint);

    expect(captured.headers['Accept'], 'application/json');
    expect(response.statusCode, 200);
    expect(response.body, '{"ok":true,"events":[]}');
    transport.dispose();
  });

  test('passes non-200 responses to the caller', () async {
    final transport = HttpCalendarTransport(
      client: MockClient((_) async => http.Response('nope', 503)),
    );

    final response = await transport.get(_endpoint);

    expect(response.statusCode, 503);
    expect(response.body, 'nope');
    transport.dispose();
  });

  test('maps a timeout to a timeout error', () async {
    final transport = HttpCalendarTransport(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      transport.get(_endpoint),
      throwsA(
        isA<CalendarException>().having(
          (error) => error.kind,
          'kind',
          CalendarErrorKind.timeout,
        ),
      ),
    );
    transport.dispose();
  });

  test('maps client failures to a network error', () async {
    final transport = HttpCalendarTransport(
      client: MockClient(
        (_) async => throw http.ClientException('offline', _endpoint),
      ),
    );

    await expectLater(
      transport.get(_endpoint),
      throwsA(
        isA<CalendarException>()
            .having((error) => error.kind, 'kind', CalendarErrorKind.network)
            .having((error) => error.details, 'details', 'offline'),
      ),
    );
    transport.dispose();
  });
}
