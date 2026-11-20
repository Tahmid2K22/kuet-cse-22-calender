import 'package:academic_calendar/services/calendar_data_source.dart';
import 'package:academic_calendar/services/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource extends CalendarDataSource {
  _FakeDataSource(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() async => rows;
}

void main() {
  test('groups events by day, sorts them and counts skipped rows', () async {
    final repository = EventRepository(
      dataSource: _FakeDataSource([
        {
          'date': '2026-11-20',
          'time': '11:00 AM',
          'title': 'Database Quiz',
          'type': 'Quiz',
        },
        {
          'date': '2026-11-20',
          'time': '09:00 AM',
          'title': 'Class Test 1',
          'type': 'Class Test',
        },
        {
          'date': '2026-11-22',
          'time': '02:30 PM',
          'title': 'Extra Class',
          'type': 'Extra Class',
        },
        {'date': '', 'title': 'Broken row'},
        {'date': '2026-11-23', 'title': 'No type'},
      ]),
    );

    await repository.load();

    expect(repository.hasLoaded, isTrue);
    expect(repository.events.length, 4);
    expect(repository.skippedRows, 1);
    expect(repository.events.first.title, 'Class Test 1');

    final sameDay = repository.eventsOn(DateTime(2026, 11, 20));
    expect(sameDay.map((event) => event.title), [
      'Class Test 1',
      'Database Quiz',
    ]);

    expect(repository.eventsOn(DateTime(2026, 11, 21)), isEmpty);
    expect(repository.eventCountInMonth(DateTime(2026, 11)), 4);
    expect(repository.eventCountInMonth(DateTime(2026, 12)), 0);
  });

  test('keeps the previous snapshot when a later load fails', () async {
    final source = _FlakyDataSource();
    final repository = EventRepository(dataSource: source);

    await repository.load();
    expect(repository.events.length, 1);

    source.shouldFail = true;
    await expectLater(repository.load(), throwsA(isA<Exception>()));

    expect(repository.events.length, 1);
    expect(repository.hasLoaded, isTrue);
  });
}

class _FlakyDataSource extends CalendarDataSource {
  bool shouldFail = false;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() async {
    if (shouldFail) throw Exception('offline');
    return [
      {'date': '2026-11-20', 'title': 'Still here', 'type': 'Quiz'},
    ];
  }
}
