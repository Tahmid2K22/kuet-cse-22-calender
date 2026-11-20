/// Broad event categories used for colour coding.
///
/// The sheet's `Type` column keeps its original label (e.g. "Class Test"),
/// while this enum decides which colour is used on the calendar.
///
/// Declaration order is also the marker priority used when one date has more
/// than one type: **Deadline → Exam → Class → Meeting → Holiday → Event**
/// (red, yellow, blue, violet, green, pink). The highest-priority type wins.
enum EventType {
  deadline,
  exam,
  classSession,
  meeting,
  holiday,
  event;

  /// Lower values win when a date has several event types.
  int get priority => switch (this) {
    EventType.deadline => 0,
    EventType.exam => 1,
    EventType.classSession => 2,
    EventType.meeting => 3,
    EventType.holiday => 4,
    EventType.event => 5,
  };

  /// Maps a raw `Type` cell to a category.
  ///
  /// Matching is case-insensitive and ignores spaces and punctuation, so
  /// "Extra Class", "extra-class" and "EXTRACLASS" all become
  /// [EventType.classSession]. Keyword checks run in priority order, which is
  /// why "Class Test" is an exam and "Assignment Submission" is a deadline.
  ///
  /// Empty and unrecognised values fall back to [EventType.deadline] so they
  /// keep the red marker, matching the original behaviour.
  static EventType fromRawType(String? rawType) {
    final normalized = (rawType ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );

    if (normalized.isEmpty) return EventType.deadline;

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) return entry.key;
      }
    }

    return EventType.deadline;
  }

  /// Returns the highest-priority type in [types], or `null` when empty.
  static EventType? highestPriorityOf(Iterable<EventType> types) {
    EventType? best;
    for (final type in types) {
      if (best == null || type.priority < best.priority) best = type;
    }
    return best;
  }

  String get label => switch (this) {
    EventType.deadline => 'Deadline',
    EventType.exam => 'Exam',
    EventType.classSession => 'Class',
    EventType.meeting => 'Meeting',
    EventType.holiday => 'Holiday',
    EventType.event => 'Event',
  };

  /// Keywords are checked in insertion order, which controls specificity:
  /// "Assignment Submission" matches deadline before the broader class rules.
  static const Map<EventType, List<String>> _keywords = {
    EventType.deadline: [
      'deadline',
      'due',
      'submit',
      'submission',
      'assignment',
      'homework',
      'lastdate',
    ],
    EventType.holiday: ['holiday', 'vacation', 'break', 'recess', 'closure'],
    EventType.meeting: [
      'meeting',
      'meet',
      'seminar',
      'workshop',
      'discussion',
      'conference',
      'colloquium',
    ],
    EventType.exam: [
      'exam',
      'test',
      'quiz',
      'midterm',
      'final',
      'viva',
      'assessment',
      'evaluation',
    ],
    EventType.classSession: [
      'class',
      'lecture',
      'lab',
      'tutorial',
      'practical',
      'presentation',
      'academic',
      'course',
    ],
    EventType.event: [
      'event',
      'program',
      'ceremony',
      'cultural',
      'sports',
      'tour',
      'picnic',
      'competition',
      'orientation',
      'reunion',
      'party',
      'concert',
      'fair',
      'fest',
      'celebration',
    ],
  };
}
