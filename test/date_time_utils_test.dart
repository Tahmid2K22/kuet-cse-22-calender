import 'package:academic_calendar/models/calendar_event.dart';
import 'package:academic_calendar/models/event_type.dart';
import 'package:academic_calendar/utils/date_time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEventDate', () {
    test('parses ISO dates and ignores the time part', () {
      expect(parseEventDate('2026-11-20'), DateTime(2026, 11, 20));
      expect(
        parseEventDate('2026-11-20T00:00:00.000Z'),
        DateTime(2026, 11, 20),
      );
      expect(parseEventDate(' 2026-11-20 '), DateTime(2026, 11, 20));
    });

    test('rejects blank and impossible dates', () {
      expect(parseEventDate(null), isNull);
      expect(parseEventDate(''), isNull);
      expect(parseEventDate('2026-02-31'), isNull);
      expect(parseEventDate('not a date'), isNull);
    });
  });

  group('parseEventTime', () {
    test('parses 12-hour, 24-hour and seconds formats', () {
      expect(parseEventTime('10:00 AM').minutes, 600);
      expect(parseEventTime('10:00 AM').label, '10:00 AM');
      expect(parseEventTime('02:30 PM').minutes, 870);
      expect(parseEventTime('14:30').minutes, 870);
      expect(parseEventTime('14:30').label, '2:30 PM');
      expect(parseEventTime('10:00:00').minutes, 600);
      expect(parseEventTime('12:00 AM').minutes, 0);
      expect(parseEventTime('12:00 PM').minutes, 720);
    });

    test('sorts ranges by their first time but keeps the full label', () {
      final range = parseEventTime('10:00 AM - 11:30 AM');
      expect(range.minutes, 600);
      expect(range.label, '10:00 AM - 11:30 AM');
    });

    test('handles empty and unparseable values', () {
      expect(parseEventTime('').label, 'Time not specified');
      expect(parseEventTime('').minutes, isNull);
      expect(parseEventTime('TBA').minutes, isNull);
      expect(parseEventTime('TBA').label, 'TBA');
    });
  });

  group('EventType.fromRawType', () {
    test('maps the six sheet types and common aliases', () {
      expect(EventType.fromRawType('Class'), EventType.classSession);
      expect(EventType.fromRawType('Lecture'), EventType.classSession);
      expect(EventType.fromRawType('Exam'), EventType.exam);
      expect(EventType.fromRawType('Class Test'), EventType.exam);
      expect(EventType.fromRawType('Deadline'), EventType.deadline);
      expect(
        EventType.fromRawType('Assignment Submission'),
        EventType.deadline,
      );
      expect(EventType.fromRawType('Holiday'), EventType.holiday);
      expect(EventType.fromRawType('Semester Break'), EventType.holiday);
      expect(EventType.fromRawType('Event'), EventType.event);
      expect(EventType.fromRawType('CSE Fest'), EventType.event);
      expect(EventType.fromRawType('Meeting'), EventType.meeting);
      expect(EventType.fromRawType('Project Meeting'), EventType.meeting);
    });

    test('ignores case, spaces and punctuation', () {
      expect(EventType.fromRawType('extra-class'), EventType.classSession);
      expect(EventType.fromRawType('FINAL EXAM'), EventType.exam);
      expect(EventType.fromRawType('  public holiday  '), EventType.holiday);
    });

    test('falls back to deadline for empty and unknown values', () {
      expect(EventType.fromRawType(null), EventType.deadline);
      expect(EventType.fromRawType(''), EventType.deadline);
      expect(EventType.fromRawType('Miscellaneous'), EventType.deadline);
    });

    test('uses red-yellow-blue-violet-green-pink priority', () {
      expect(EventType.deadline.priority, 0);
      expect(EventType.exam.priority, 1);
      expect(EventType.classSession.priority, 2);
      expect(EventType.meeting.priority, 3);
      expect(EventType.holiday.priority, 4);
      expect(EventType.event.priority, 5);

      expect(
        EventType.highestPriorityOf([
          EventType.event,
          EventType.holiday,
          EventType.classSession,
          EventType.deadline,
          EventType.meeting,
          EventType.exam,
        ]),
        EventType.deadline,
      );
      expect(
        EventType.highestPriorityOf([EventType.event, EventType.meeting]),
        EventType.meeting,
      );
      expect(EventType.highestPriorityOf(const []), isNull);
    });
  });

  group('CalendarEvent.tryParse', () {
    test('maps a class event to the blue category', () {
      final event = CalendarEvent.tryParse({
        'date': '2026-11-22',
        'time': '02:30 PM',
        'title': 'Data Structures',
        'type': 'Class',
        'description': 'Graph traversal',
        'location': 'Room 302',
      });

      expect(event, isNotNull);
      expect(event!.category, EventType.classSession);
      expect(event.timeMinutes, 870);
      expect(event.location, 'Room 302');
    });

    test('treats unknown or missing types as deadline', () {
      final unknown = CalendarEvent.tryParse({
        'date': '2026-11-23',
        'title': 'Miscellaneous',
        'type': 'Miscellaneous',
      });
      final missing = CalendarEvent.tryParse({
        'date': '2026-11-23',
        'title': 'Untyped',
      });

      expect(unknown!.category, EventType.deadline);
      expect(unknown.type, 'Miscellaneous');
      expect(missing!.category, EventType.deadline);
      expect(missing.type, 'Unspecified');
    });

    test('skips rows without a valid date or title', () {
      expect(CalendarEvent.tryParse({'title': 'No date'}), isNull);
      expect(
        CalendarEvent.tryParse({'date': '2026-11-20', 'title': '   '}),
        isNull,
      );
    });

    test('sorts by date, then time, with untimed events last', () {
      final late = CalendarEvent.tryParse({
        'date': '2026-11-20',
        'time': '02:00 PM',
        'title': 'Late',
      })!;
      final early = CalendarEvent.tryParse({
        'date': '2026-11-20',
        'time': '09:00 AM',
        'title': 'Early',
      })!;
      final untimed = CalendarEvent.tryParse({
        'date': '2026-11-20',
        'title': 'Untimed',
      })!;
      final nextDay = CalendarEvent.tryParse({
        'date': '2026-11-21',
        'title': 'Next day',
      })!;

      final sorted = [nextDay, untimed, late, early]
        ..sort((a, b) => a.compareTo(b));

      expect(sorted.map((event) => event.title), [
        'Early',
        'Late',
        'Untimed',
        'Next day',
      ]);
    });
  });
}
