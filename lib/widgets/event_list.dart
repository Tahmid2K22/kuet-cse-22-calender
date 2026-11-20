import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import 'event_card.dart';

/// Vertical list of event cards, already sorted by time by the repository.
class EventList extends StatelessWidget {
  const EventList({super.key, required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < events.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          EventCard(
            key: ValueKey(
              '${events[index].date.toIso8601String()}-${events[index].title}-$index',
            ),
            event: events[index],
          ),
        ],
      ],
    );
  }
}
