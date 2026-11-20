import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/calendar_exception.dart';

/// Shown in the event section while the first load is in flight.
class EventLoadingView extends StatelessWidget {
  const EventLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 14),
          Text(
            'Loading events…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the first load fails (or a retry is requested).
class EventErrorView extends StatelessWidget {
  const EventErrorView({super.key, required this.error, required this.onRetry});

  final CalendarException error;
  final VoidCallback onRetry;

  bool _showsDetails(CalendarException error) {
    final details = error.details?.trim();
    if (details == null || details.isEmpty) return false;

    return error.kind == CalendarErrorKind.server ||
        error.kind == CalendarErrorKind.invalidResponse;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (error.kind) {
      CalendarErrorKind.configuration => 'Calendar not connected',
      CalendarErrorKind.network => 'Connection problem',
      CalendarErrorKind.timeout => 'Request timed out',
      CalendarErrorKind.server => 'Calendar service error',
      CalendarErrorKind.invalidResponse => 'Unexpected response',
    };

    final hint = switch (error.kind) {
      CalendarErrorKind.configuration =>
        'Paste your Apps Script Web App URL into lib/config/app_config.dart, '
            'or pass --dart-define=CALENDAR_ENDPOINT=… when running or '
            'building the app.',
      CalendarErrorKind.network =>
        'Check your internet connection, then try again.',
      CalendarErrorKind.timeout => 'Try again in a moment.',
      CalendarErrorKind.server =>
        'Open the Apps Script editor and deploy a new version of the Web App.',
      CalendarErrorKind.invalidResponse =>
        'Make sure the Web App is deployed with "Execute as: Me" and '
            '"Who has access: Anyone".',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 23,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppColors.inkMuted.withValues(alpha: 0.9),
            ),
          ),
          if (_showsDetails(error)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error.details!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
          if (error.kind != CalendarErrorKind.configuration) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the selected date has no scheduled events.
class EmptyEventsView extends StatelessWidget {
  const EmptyEventsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 24,
              color: AppColors.primary.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No events scheduled for this date.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick another day or use the refresh button.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Non-blocking notice for malformed rows that were skipped by the parser.
class SkippedRowsNotice extends StatelessWidget {
  const SkippedRowsNotice({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '1 row in the sheet could not be read and was skipped.'
        : '$count rows in the sheet could not be read and were skipped.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label Check the Date and Title columns.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
