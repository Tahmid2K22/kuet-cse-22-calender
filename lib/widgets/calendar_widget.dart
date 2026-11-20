import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../config/app_theme.dart';
import '../models/calendar_event.dart';
import '../models/event_type.dart';
import '../utils/date_time_utils.dart';
import 'legend.dart';

/// The monthly calendar card: custom month header, grid, date rings, legend.
///
/// A date with events gets a coloured ring around its number. When a date has
/// several event types, the ring uses the highest-priority one
/// (deadline → exam → class → meeting → holiday → event). Small dots below the
/// number keep the remaining types visible.
class CalendarWidget extends StatelessWidget {
  const CalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.firstDay,
    required this.lastDay,
    required this.monthEventCount,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onMonthChanged,
    required this.onTodayPressed,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final DateTime firstDay;
  final DateTime lastDay;
  final int monthEventCount;
  final List<CalendarEvent> Function(DateTime day) eventsForDay;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onTodayPressed;
  final bool canGoPrevious;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final monthLabel = formatMonthYear(focusedDay);
    final countLabel = monthEventCount == 0
        ? 'No events this month'
        : '$monthEventCount ${monthEventCount == 1 ? 'event' : 'events'} this month';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        countLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _MonthNavButton(
                  icon: Icons.today_outlined,
                  tooltip: 'Jump to today',
                  onPressed: onTodayPressed,
                ),
                const SizedBox(width: 6),
                _MonthNavButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous month',
                  onPressed: canGoPrevious
                      ? () => onMonthChanged(
                          DateTime(focusedDay.year, focusedDay.month - 1),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                _MonthNavButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next month',
                  onPressed: canGoNext
                      ? () => onMonthChanged(
                          DateTime(focusedDay.year, focusedDay.month + 1),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TableCalendar<CalendarEvent>(
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: focusedDay,
            currentDay: DateTime.now(),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerVisible: false,
            sixWeekMonthsEnforced: true,
            pageJumpingEnabled: true,
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: 46,
            daysOfWeekHeight: 30,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: onDaySelected,
            onPageChanged: onMonthChanged,
            eventLoader: (day) => eventsForDay(dateOnly(day)),
            daysOfWeekStyle: DaysOfWeekStyle(
              dowTextFormatter: (date, locale) => formatWeekdayShort(date),
              weekdayStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
                letterSpacing: 0.4,
              ),
              weekendStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
                letterSpacing: 0.4,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              isTodayHighlighted: true,
              canMarkersOverflow: false,
              markersAutoAligned: false,
              markerSize: 5,
              cellMargin: const EdgeInsets.symmetric(
                horizontal: 3,
                vertical: 4,
              ),
              cellPadding: EdgeInsets.zero,
              tablePadding: const EdgeInsets.only(top: 2),
              defaultTextStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              weekendTextStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4F6558),
              ),
              outsideTextStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.inkMuted.withValues(alpha: 0.4),
              ),
              disabledTextStyle: TextStyle(
                fontSize: 13,
                color: AppColors.inkMuted.withValues(alpha: 0.3),
              ),
              todayTextStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              selectedTextStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            calendarBuilders: CalendarBuilders<CalendarEvent>(
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(day),
              todayBuilder: (context, day, focusedDay) => _buildDayCell(day),
              selectedBuilder: (context, day, focusedDay) => _buildDayCell(day),
              outsideBuilder: (context, day, focusedDay) => _buildDayCell(day),
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final event in events.take(3))
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: EventPalette.ringColorOf(event.category),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Legend(),
          ),
        ],
      ),
    );
  }

  /// Draws one date cell, adding the priority ring when the day has events.
  Widget _buildDayCell(DateTime day) {
    final events = eventsForDay(dateOnly(day));
    final isSelected = isSameDay(day, selectedDay);
    final isToday = isSameDay(day, DateTime.now());
    final isOutside = day.month != focusedDay.month;

    final ringType = EventType.highestPriorityOf(
      events.map((event) => event.category),
    );
    final hasRing = ringType != null;

    final ringColor = hasRing
        ? (isOutside
              ? EventPalette.ringColorOf(ringType).withValues(alpha: 0.45)
              : EventPalette.ringColorOf(ringType))
        : (isToday ? AppColors.primary.withValues(alpha: 0.45) : null);

    final fillColor = isSelected
        ? AppColors.primary
        : isToday
        ? AppColors.primary.withValues(alpha: 0.10)
        : Colors.transparent;

    final textColor = isSelected
        ? Colors.white
        : isOutside
        ? AppColors.inkMuted.withValues(alpha: 0.38)
        : isToday
        ? AppColors.primary
        : AppColors.ink;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        padding: EdgeInsets.all(hasRing ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasRing ? AppColors.surface : Colors.transparent,
          border: ringColor == null
              ? null
              : Border.all(color: ringColor, width: hasRing ? 2.2 : 1.2),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: fillColor),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected || isToday
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          backgroundColor: enabled
              ? AppColors.background
              : AppColors.background.withValues(alpha: 0.5),
          foregroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.inkMuted.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
