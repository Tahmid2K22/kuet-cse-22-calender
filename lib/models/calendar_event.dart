import '../utils/date_time_utils.dart';
import 'event_type.dart';

/// A single row of the Academic Calendar sheet, normalised for the UI.
class CalendarEvent {
  const CalendarEvent({
    required this.date,
    required this.timeLabel,
    required this.timeMinutes,
    required this.title,
    required this.type,
    required this.category,
    required this.description,
    required this.location,
  });

  /// Local, date-only value (midnight).
  final DateTime date;

  /// Human readable time, e.g. "10:00 AM" or "10:00 AM - 11:30 AM".
  final String timeLabel;

  /// Minutes since midnight. `null` when the sheet time is unreadable.
  final int? timeMinutes;

  final String title;

  /// Original label from the sheet, e.g. "Class Test".
  final String type;

  /// Derived colour category. Never null.
  final EventType category;

  final String description;
  final String location;

  bool get hasDescription => description.isNotEmpty;
  bool get hasLocation => location.isNotEmpty;

  /// Builds an event from one JSON object returned by the Web App.
  ///
  /// Returns `null` for unusable rows (missing/invalid date or missing title)
  /// so the repository can skip them without failing the whole refresh.
  static CalendarEvent? tryParse(Map<String, dynamic> json) {
    final date = parseEventDate(_read(json, 'date'));
    final title = _read(json, 'title').trim();
    if (date == null || title.isEmpty) return null;

    final rawType = _read(json, 'type').trim();
    final time = parseEventTime(_read(json, 'time'));

    return CalendarEvent(
      date: date,
      timeLabel: time.label,
      timeMinutes: time.minutes,
      title: title,
      type: rawType.isEmpty ? 'Unspecified' : rawType,
      category: EventType.fromRawType(rawType),
      description: _read(json, 'description').trim(),
      location: _read(json, 'location').trim(),
    );
  }

  /// Chronological order: date, then time, then title.
  ///
  /// Events without a readable time are placed after timed events on the same
  /// day so that the list stays deterministic.
  int compareTo(CalendarEvent other) {
    final byDate = date.compareTo(other.date);
    if (byDate != 0) return byDate;

    final a = timeMinutes;
    final b = other.timeMinutes;
    if (a == null && b == null) return _byTitle(other);
    if (a == null) return 1;
    if (b == null) return -1;

    final byTime = a.compareTo(b);
    if (byTime != 0) return byTime;

    return _byTitle(other);
  }

  int _byTitle(CalendarEvent other) =>
      title.toLowerCase().compareTo(other.title.toLowerCase());

  /// Reads a value by key, tolerating differently-cased keys.
  static String _read(Map<String, dynamic> json, String key) {
    final direct = json[key];
    if (direct != null) return direct.toString();

    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == key) {
        return entry.value?.toString() ?? '';
      }
    }
    return '';
  }

  @override
  String toString() => 'CalendarEvent($date, $timeLabel, $title, $type)';
}
