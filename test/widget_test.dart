import 'package:academic_calendar/app.dart';
import 'package:academic_calendar/config/app_theme.dart';
import 'package:academic_calendar/models/event_type.dart';
import 'package:academic_calendar/services/calendar_data_source.dart';
import 'package:academic_calendar/services/event_repository.dart';
import 'package:academic_calendar/utils/date_time_utils.dart';
import 'package:academic_calendar/widgets/calendar_widget.dart';
import 'package:academic_calendar/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource extends CalendarDataSource {
  _FakeDataSource(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() async => rows;
}

String _iso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

void _useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _useTallPhoneSurface(WidgetTester tester) {
  _useSurface(tester, const Size(420, 1400));
}

void main() {
  testWidgets('renders the calendar and events for today', (tester) async {
    _useTallPhoneSurface(tester);

    final repository = EventRepository(
      dataSource: _FakeDataSource([
        {
          'date': _iso(today()),
          'time': '10:00 AM',
          'title': 'Class Test 1',
          'type': 'Exam',
          'description': 'Chapter 1',
          'location': 'Room 201',
        },
        {
          'date': _iso(today()),
          'time': '02:30 PM',
          'title': 'Data Structures',
          'type': 'Class',
          'description': 'Additional class',
          'location': 'Room 302',
        },
      ]),
    );

    await tester.pumpWidget(AcademicCalendarApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('KUET CSE 22 Calender'), findsOneWidget);
    expect(find.text('Class Test 1'), findsOneWidget);
    expect(find.byType(EventCard), findsNWidgets(2));
    expect(find.text('Room 201'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Additional class'), findsOneWidget);
    expect(find.text('2 events'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

    // On a phone the selected-day details sit below the calendar.
    final calendar = tester.getRect(find.byType(CalendarWidget));
    final firstCard = tester.getRect(find.byType(EventCard).first);
    expect(firstCard.top, greaterThan(calendar.bottom));
  });

  testWidgets('shows the empty state when the sheet has no events', (
    tester,
  ) async {
    _useTallPhoneSurface(tester);

    final repository = EventRepository(dataSource: _FakeDataSource(const []));

    await tester.pumpWidget(AcademicCalendarApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('No events scheduled for this date.'), findsOneWidget);
    expect(find.text('No events'), findsOneWidget);
  });

  testWidgets('places the events beside the calendar on wide screens', (
    tester,
  ) async {
    _useSurface(tester, const Size(1440, 1000));

    final repository = EventRepository(
      dataSource: _FakeDataSource([
        {
          'date': _iso(today()),
          'time': '10:00 AM',
          'title': 'Class Test 1',
          'type': 'Class Test',
          'description': 'Chapter 1',
          'location': 'Room 201',
        },
      ]),
    );

    await tester.pumpWidget(AcademicCalendarApp(repository: repository));
    await tester.pumpAndSettle();

    final calendar = tester.getRect(find.byType(CalendarWidget));
    final eventCard = tester.getRect(find.byType(EventCard));

    expect(eventCard.left, greaterThan(calendar.right));
    expect(eventCard.top, lessThan(calendar.bottom));
    expect(find.text('Class Test 1'), findsOneWidget);
  });

  testWidgets('keeps the two-column layout at the 900 px breakpoint', (
    tester,
  ) async {
    _useSurface(tester, const Size(900, 1000));

    final repository = EventRepository(
      dataSource: _FakeDataSource([
        {
          'date': _iso(today()),
          'time': '10:00 AM',
          'title': 'Class Test 1',
          'type': 'Class Test',
        },
        {
          'date': _iso(today()),
          'time': '02:30 PM',
          'title': 'Extra Class',
          'type': 'Extra Class',
        },
      ]),
    );

    await tester.pumpWidget(AcademicCalendarApp(repository: repository));
    await tester.pumpAndSettle();

    final calendar = tester.getRect(find.byType(CalendarWidget));
    final eventCard = tester.getRect(find.byType(EventCard).first);

    expect(eventCard.left, greaterThan(calendar.right));
    expect(find.text('2 events'), findsOneWidget);
  });

  testWidgets('uses the highest-priority type colour for the date ring', (
    tester,
  ) async {
    _useTallPhoneSurface(tester);

    final repository = EventRepository(
      dataSource: _FakeDataSource([
        {'date': _iso(today()), 'title': 'Semester Break', 'type': 'Holiday'},
        {
          'date': _iso(today()),
          'title': 'Assignment Submission',
          'type': 'Deadline',
        },
      ]),
    );

    await tester.pumpWidget(AcademicCalendarApp(repository: repository));
    await tester.pumpAndSettle();

    final rings = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((container) {
          final decoration = container.decoration;
          if (decoration is! BoxDecoration) return false;
          final border = decoration.border;
          return border is Border &&
              border.top.color == EventPalette.ringColorOf(EventType.deadline);
        });

    expect(rings, isNotEmpty);
  });
}
