import '../models/calendar_event.dart';
import '../utils/date_time_utils.dart';
import 'calendar_data_source.dart';
import 'sheets_service.dart';

/// Turns raw sheet rows into sorted, indexed [CalendarEvent]s.
///
/// The repository keeps the last successful snapshot. If a refresh fails, the
/// screen can keep showing the existing data and surface a non-blocking error.
class EventRepository {
  EventRepository({CalendarDataSource? dataSource})
    : _dataSource = dataSource ?? SheetsService();

  final CalendarDataSource _dataSource;

  List<CalendarEvent> _events = const [];
  Map<DateTime, List<CalendarEvent>> _eventsByDay = const {};
  int _skippedRows = 0;
  bool _hasLoaded = false;

  /// All events, sorted by date then time.
  List<CalendarEvent> get events => _events;

  /// Number of rows that could not be parsed during the last load.
  int get skippedRows => _skippedRows;

  /// Whether at least one load has completed successfully.
  bool get hasLoaded => _hasLoaded;

  /// Downloads and parses all events. Throws [CalendarException] on failure.
  ///
  /// Existing data is left untouched when the download fails.
  Future<void> load() async {
    final rows = await _dataSource.fetchRows();

    final parsed = <CalendarEvent>[];
    var skipped = 0;

    for (final row in rows) {
      final event = CalendarEvent.tryParse(row);
      if (event == null) {
        skipped++;
        continue;
      }
      parsed.add(event);
    }

    parsed.sort((a, b) => a.compareTo(b));

    final grouped = <DateTime, List<CalendarEvent>>{};
    for (final event in parsed) {
      grouped.putIfAbsent(event.date, () => []).add(event);
    }

    _events = List<CalendarEvent>.unmodifiable(parsed);
    _eventsByDay = Map<DateTime, List<CalendarEvent>>.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<CalendarEvent>.unmodifiable(entry.value),
    });
    _skippedRows = skipped;
    _hasLoaded = true;
  }

  /// Events for one calendar day, already sorted by time.
  List<CalendarEvent> eventsOn(DateTime day) =>
      _eventsByDay[dateOnly(day)] ?? const [];

  /// Number of events whose date falls inside [month].
  int eventCountInMonth(DateTime month) =>
      _events.where((event) => isSameMonth(event.date, month)).length;

  void dispose() => _dataSource.dispose();
}
