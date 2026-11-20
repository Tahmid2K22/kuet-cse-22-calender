import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../models/calendar_event.dart';
import '../services/calendar_exception.dart';
import '../services/event_repository.dart';
import '../utils/date_time_utils.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_list.dart';
import '../widgets/status_views.dart';

enum _ViewStatus { loading, ready, error }

/// Width at which the calendar and the selected-day events sit side by side.
const double _wideLayoutBreakpoint = 900;

/// Main screen: owns the load state, month focus and selected day.
///
/// Uses one column on phones and two columns (calendar + selected-day events)
/// from [_wideLayoutBreakpoint] upwards.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.repository});

  /// Injected in tests; a real repository is created when omitted.
  final EventRepository? repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final EventRepository _repository;
  late final bool _ownsRepository;

  late final DateTime _firstDay;
  late final DateTime _lastDay;

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  _ViewStatus _status = _ViewStatus.loading;
  CalendarException? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? EventRepository();
    _ownsRepository = widget.repository == null;

    final now = today();
    _firstDay = DateTime(now.year - 10, 1, 1);
    _lastDay = DateTime(now.year + 10, 12, 31);
    _focusedDay = now;
    _selectedDay = now;

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (_ownsRepository) _repository.dispose();
    super.dispose();
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (!_repository.hasLoaded) _status = _ViewStatus.loading;
    });

    try {
      await _repository.load();
      if (!mounted) return;

      setState(() => _status = _ViewStatus.ready);

      if (isRefresh) {
        final count = _repository.events.length;
        _showSnackBar(
          count == 0
              ? 'Calendar updated · no events found'
              : 'Calendar updated · $count ${count == 1 ? 'event' : 'events'}',
        );
      }
    } on CalendarException catch (error) {
      _handleLoadFailure(error, isRefresh: isRefresh);
    } catch (error) {
      _handleLoadFailure(
        CalendarException(
          kind: CalendarErrorKind.invalidResponse,
          message: 'Something went wrong while loading the calendar.',
          details: error.toString(),
        ),
        isRefresh: isRefresh,
      );
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleLoadFailure(CalendarException error, {required bool isRefresh}) {
    if (!mounted) return;

    final hadData = _repository.hasLoaded;

    setState(() {
      _isLoading = false;
      _error = error;
      _status = hadData ? _ViewStatus.ready : _ViewStatus.error;
    });

    if (hadData && isRefresh) {
      _showSnackBar(error.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.ink : AppColors.primary,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = dateOnly(selectedDay);
      _focusedDay = dateOnly(focusedDay);
    });
  }

  /// Handles both swipe navigation and the header arrows.
  ///
  /// When the visible month changes, the selection follows so the detail
  /// section always describes a date the user can see.
  void _onMonthChanged(DateTime month) {
    final target = DateTime(month.year, month.month);
    final minMonth = DateTime(_firstDay.year, _firstDay.month);
    final maxMonth = DateTime(_lastDay.year, _lastDay.month);

    final clamped = target.isBefore(minMonth)
        ? minMonth
        : target.isAfter(maxMonth)
        ? maxMonth
        : target;

    setState(() {
      _focusedDay = clamped;

      if (!isSameMonth(_selectedDay, clamped)) {
        final now = today();
        _selectedDay = isSameMonth(now, clamped) ? now : clamped;
      }
    });
  }

  void _goToToday() {
    final now = today();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _repository.eventsOn(_selectedDay);

    final countLabel = switch (_status) {
      _ViewStatus.loading => 'Loading…',
      _ViewStatus.error => 'Unavailable',
      _ViewStatus.ready =>
        events.isEmpty
            ? 'No events'
            : '${events.length} ${events.length == 1 ? 'event' : 'events'}',
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.24),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                AppConfig.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Refresh calendar',
              onPressed: _isLoading ? null : () => _load(isRefresh: true),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading && _status == _ViewStatus.ready
              ? const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                )
              : const SizedBox(height: 2),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

          return RefreshIndicator(
            onRefresh: () => _load(isRefresh: true),
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            edgeOffset: 2,
            child: isWide
                ? _buildWideBody(events, countLabel)
                : _buildNarrowBody(events, countLabel),
          );
        },
      ),
    );
  }

  Widget _buildNarrowBody(List<CalendarEvent> events, String countLabel) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _buildCalendar(),
        const SizedBox(height: 22),
        _buildEventPanel(events, countLabel),
      ],
    );
  }

  Widget _buildWideBody(List<CalendarEvent> events, String countLabel) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildCalendar()),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: _buildEventPanel(events, countLabel)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return CalendarWidget(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      firstDay: _firstDay,
      lastDay: _lastDay,
      monthEventCount: _repository.eventCountInMonth(_focusedDay),
      eventsForDay: _repository.eventsOn,
      onDaySelected: _onDaySelected,
      onMonthChanged: _onMonthChanged,
      onTodayPressed: _goToToday,
      canGoPrevious: DateTime(
        _focusedDay.year,
        _focusedDay.month,
      ).isAfter(DateTime(_firstDay.year, _firstDay.month)),
      canGoNext: DateTime(
        _focusedDay.year,
        _focusedDay.month,
      ).isBefore(DateTime(_lastDay.year, _lastDay.month)),
    );
  }

  Widget _buildEventPanel(List<CalendarEvent> events, String countLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventSectionHeader(
          selectedDay: _selectedDay,
          countLabel: countLabel,
          countHighlighted: _status == _ViewStatus.ready && events.isNotEmpty,
        ),
        const SizedBox(height: 12),
        if (_status == _ViewStatus.ready && _repository.skippedRows > 0) ...[
          SkippedRowsNotice(count: _repository.skippedRows),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildEventSection(events),
        ),
      ],
    );
  }

  Widget _buildEventSection(List<CalendarEvent> events) {
    switch (_status) {
      case _ViewStatus.loading:
        return const EventLoadingView(key: ValueKey('events-loading'));

      case _ViewStatus.error:
        return EventErrorView(
          key: const ValueKey('events-error'),
          error:
              _error ??
              const CalendarException(
                kind: CalendarErrorKind.invalidResponse,
                message: 'Unable to load events.',
              ),
          onRetry: () => _load(),
        );

      case _ViewStatus.ready:
        if (events.isEmpty) {
          return const EmptyEventsView(key: ValueKey('events-empty'));
        }
        return EventList(
          key: ValueKey(
            'events-${_selectedDay.toIso8601String()}-${events.length}',
          ),
          events: events,
        );
    }
  }
}

class _EventSectionHeader extends StatelessWidget {
  const _EventSectionHeader({
    required this.selectedDay,
    required this.countLabel,
    required this.countHighlighted,
  });

  final DateTime selectedDay;
  final String countLabel;
  final bool countHighlighted;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(selectedDay, today());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECTED DATE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.inkMuted.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      formatFullDate(selectedDay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: countHighlighted
                ? AppColors.primary.withValues(alpha: 0.09)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: countHighlighted
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.border,
            ),
          ),
          child: Text(
            countLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: countHighlighted ? AppColors.primary : AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
