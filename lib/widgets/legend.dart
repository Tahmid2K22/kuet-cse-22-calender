import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/event_type.dart';

/// Colour key for the six event categories.
class Legend extends StatelessWidget {
  const Legend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 7,
      children: [
        _LegendItem(type: EventType.deadline),
        _LegendItem(type: EventType.exam),
        _LegendItem(type: EventType.classSession),
        _LegendItem(type: EventType.meeting),
        _LegendItem(type: EventType.holiday),
        _LegendItem(type: EventType.event),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: EventPalette.colorOf(type),
            shape: BoxShape.circle,
            border: Border.all(
              color: EventPalette.strongColorOf(type),
              width: 1.6,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          type.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
