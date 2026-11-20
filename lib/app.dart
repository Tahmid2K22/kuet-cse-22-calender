import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'screens/calendar_screen.dart';
import 'services/event_repository.dart';

class AcademicCalendarApp extends StatelessWidget {
  const AcademicCalendarApp({super.key, this.repository});

  /// Optional repository injection for tests.
  final EventRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: CalendarScreen(repository: repository),
    );
  }
}
