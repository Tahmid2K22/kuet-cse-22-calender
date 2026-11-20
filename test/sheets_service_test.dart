import 'dart:convert';

import 'package:academic_calendar/services/calendar_exception.dart';
import 'package:academic_calendar/services/calendar_transport.dart';
import 'package:academic_calendar/services/sheets_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uri get _endpoint =>
    Uri.parse('https://script.google.com/macros/s/test-deployment/exec');

class _FakeTransport extends CalendarTransport {
  _FakeTransport(this.handler);

  final Future<CalendarTransportResponse> Function(Uri uri) handler;
  Uri? lastUri;

  @override
  Future<CalendarTransportResponse> get(Uri uri) {
    lastUri = uri;
    return handler(uri);
  }
}

_FakeTransport _jsonTransport(Object payload) {
  return _FakeTransport(
    (_) async =>
        CalendarTransportResponse(statusCode: 200, body: jsonEncode(payload)),
  );
}

void main() {
  test(
    'parses a successful Apps Script payload and adds cache busting',
    () async {
      final transport = _jsonTransport({
        'ok': true,
        'count': 1,
        'events': [
          {
            'date': '2026-11-20',
            'time': '10:00 AM',
            'title': 'Class Test 1',
            'type': 'Class Test',
            'description': 'Chapter 1',
            'location': 'Room 201',
          },
        ],
      });

      final service = SheetsService(transport: transport, endpoint: _endpoint);
      final rows = await service.fetchRows();

      expect(transport.lastUri?.host, 'script.google.com');
      expect(transport.lastUri?.queryParameters.containsKey('_ts'), isTrue);
      expect(rows, hasLength(1));
      expect(rows.first['title'], 'Class Test 1');
      service.dispose();
    },
  );

  test('accepts a bare JSON array', () async {
    final service = SheetsService(
      transport: _jsonTransport([
        {'date': '2026-11-20', 'title': 'Quiz'},
      ]),
      endpoint: _endpoint,
    );

    final rows = await service.fetchRows();

    expect(rows.single['title'], 'Quiz');
    service.dispose();
  });

  test('surfaces ok:false errors from the Web App', () async {
    final service = SheetsService(
      transport: _jsonTransport({'ok': false, 'error': 'Sheet not found'}),
      endpoint: _endpoint,
    );

    await expectLater(
      service.fetchRows(),
      throwsA(
        isA<CalendarException>()
            .having((error) => error.kind, 'kind', CalendarErrorKind.server)
            .having(
              (error) => error.details,
              'details',
              contains('Sheet not found'),
            ),
      ),
    );
    service.dispose();
  });

  test('reports non-200 responses as server errors', () async {
    final service = SheetsService(
      transport: _FakeTransport(
        (_) async =>
            const CalendarTransportResponse(statusCode: 500, body: 'nope'),
      ),
      endpoint: _endpoint,
    );

    await expectLater(
      service.fetchRows(),
      throwsA(
        isA<CalendarException>()
            .having((error) => error.kind, 'kind', CalendarErrorKind.server)
            .having((error) => error.details, 'details', 'nope'),
      ),
    );
    service.dispose();
  });

  test('reports HTML or malformed bodies as invalid responses', () async {
    final service = SheetsService(
      transport: _FakeTransport(
        (_) async => const CalendarTransportResponse(
          statusCode: 200,
          body: '<html>Sign in</html>',
        ),
      ),
      endpoint: _endpoint,
    );

    await expectLater(
      service.fetchRows(),
      throwsA(
        isA<CalendarException>().having(
          (error) => error.kind,
          'kind',
          CalendarErrorKind.invalidResponse,
        ),
      ),
    );
    service.dispose();
  });

  test('strips a UTF-8 BOM and surrounding whitespace', () async {
    final service = SheetsService(
      transport: _FakeTransport(
        (_) async => CalendarTransportResponse(
          statusCode: 200,
          body: '\uFEFF  ${jsonEncode({'events': []})}  ',
        ),
      ),
      endpoint: _endpoint,
    );

    expect(await service.fetchRows(), isEmpty);
    service.dispose();
  });

  test('propagates transport failures unchanged', () async {
    final service = SheetsService(
      transport: _FakeTransport(
        (_) async => throw const CalendarException(
          kind: CalendarErrorKind.timeout,
          message: 'slow',
        ),
      ),
      endpoint: _endpoint,
    );

    await expectLater(
      service.fetchRows(),
      throwsA(
        isA<CalendarException>().having(
          (error) => error.kind,
          'kind',
          CalendarErrorKind.timeout,
        ),
      ),
    );
    service.dispose();
  });

  test('reports a missing endpoint as a configuration error', () async {
    final service = SheetsService(
      transport: _FakeTransport(
        (_) async =>
            const CalendarTransportResponse(statusCode: 200, body: '{}'),
      ),
      endpoint: null,
      useAppConfig: false,
    );

    await expectLater(
      service.fetchRows(),
      throwsA(
        isA<CalendarException>().having(
          (error) => error.kind,
          'kind',
          CalendarErrorKind.configuration,
        ),
      ),
    );
    service.dispose();
  });
}
