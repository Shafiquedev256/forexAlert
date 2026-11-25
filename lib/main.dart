import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'journal/journal_controller.dart';
import 'screens/ringing_screen.dart';
import 'screens/shell_screen.dart';
import 'services/monitor_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) MonitorService.init();
  final state = await AppState.create();
  runApp(ForexAlertApp(state: state, journal: JournalController(state.storage)));
  unawaited(state.requestInitialPermissions());
}

class ForexAlertApp extends StatelessWidget {
  const ForexAlertApp({super.key, required this.state, required this.journal});

  final AppState state;
  final JournalController journal;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Forex Alert',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: state.themeMode,
          home: ShellScreen(state: state, journal: journal),
          // The ringing screen sits above every route so it is always reachable.
          builder: (context, child) => Stack(
            textDirection: TextDirection.ltr,
            children: [
              child ?? const SizedBox.shrink(),
              if (state.ring.active) Positioned.fill(child: RingingScreen(state: state)),
            ],
          ),
        );
      },
    );
  }
}
