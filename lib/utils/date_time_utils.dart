import 'package:intl/intl.dart';

final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
final DateFormat _fullDateFormat = DateFormat('EEEE, d MMMM yyyy');
final DateFormat _compactDateFormat = DateFormat('d MMM yyyy');
final DateFormat _weekdayFormat = DateFormat('E');

final RegExp _isoDatePattern = RegExp(
  r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:$|[T\s])',
);
final RegExp _clockPattern = RegExp(
  r'^(\d{1,2})(?::(\d{1,2}))?(?::(\d{1,2}))?\s*([ap]\.?m\.?)?$',
  caseSensitive: false,
);
final RegExp _rangeSeparator = RegExp(
  r'\s*(?:[-–—]|\bto\b)\s*',
  caseSensitive: false,
);
final RegExp _isoTimePattern = RegExp(r'T(\d{1,2}):(\d{2})');

/// Removes the time component so dates can be used as map keys and compared.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime today() => dateOnly(DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// Parses the sheet's date cell into a local, date-only [DateTime].
///
/// Accepts `YYYY-MM-DD` (the contract produced by the Apps Script) as well as
/// ISO timestamps such as `2026-11-20T00:00:00.000Z`. Returns `null` for blank
/// or impossible dates (e.g. `2026-02-31`), so the repository can skip them.
DateTime? parseEventDate(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  final match = _isoDatePattern.firstMatch(value);
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);
    // Guards against overflow such as 2026-02-31 -> 2026-03-03.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  // Fallback for timestamps without a leading date match.
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return dateOnly(parsed);
}

/// Parses the sheet's time cell.
///
/// Supports 12-hour (`10:00 AM`, `2:30 p.m.`), 24-hour (`14:30`), seconds
/// (`10:00:00`), ISO timestamps and ranges (`10:00 AM - 11:30 AM`). For a range
/// the first time is used for sorting while the full range stays visible.
TimeInfo parseEventTime(String? raw) {
  final value = (raw ?? '').replaceAll('\u00A0', ' ').trim();
  if (value.isEmpty) return TimeInfo.unspecified;

  final isoMatch = _isoTimePattern.firstMatch(value);
  final hasRange = isoMatch == null && _rangeSeparator.hasMatch(value);

  final source = isoMatch != null
      ? '${isoMatch.group(1)}:${isoMatch.group(2)}'
      : value;
  final firstPart = hasRange
      ? value.split(_rangeSeparator).first.trim()
      : source;

  final match = _clockPattern.firstMatch(firstPart);
  if (match == null) return TimeInfo(label: value);

  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  final meridiem = match.group(4)?.toLowerCase().replaceAll('.', '');

  if (minute > 59) return TimeInfo(label: value);

  final int normalizedHour;
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return TimeInfo(label: value);
    normalizedHour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
  } else {
    if (hour > 23) return TimeInfo(label: value);
    normalizedHour = hour;
  }

  final minutes = normalizedHour * 60 + minute;
  return TimeInfo(
    minutes: minutes,
    label: hasRange ? value : formatMinutesAsClock(minutes),
  );
}

String formatMinutesAsClock(int minutes) {
  final hour24 = (minutes ~/ 60) % 24;
  final minute = minutes % 60;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

String formatFullDate(DateTime date) => _fullDateFormat.format(date);

String formatCompactDate(DateTime date) => _compactDateFormat.format(date);

String formatWeekdayShort(DateTime date) => _weekdayFormat.format(date);

/// Parsed time information used by [CalendarEvent].
class TimeInfo {
  const TimeInfo({required this.label, this.minutes});

  /// Text shown in the UI. Always non-empty.
  final String label;

  /// Minutes since midnight, used for sorting. `null` when unparseable.
  final int? minutes;

  bool get hasTime => minutes != null;

  static const TimeInfo unspecified = TimeInfo(label: 'Time not specified');
}
