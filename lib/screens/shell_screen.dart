import 'package:flutter/material.dart';

import '../journal/journal_controller.dart';
import '../state/app_state.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'trades_screen.dart';

/// Bottom navigation: Alerts, Dashboard, Trades, Analytics.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.state, required this.journal});

  final AppState state;
  final JournalController journal;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  // Tabs are built the first time they are opened, then kept alive.
  final Set<int> _visited = {0};

  void _select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  Widget _page(int i) {
    switch (i) {
      case 0:
        return HomeScreen(state: widget.state, journal: widget.journal);
      case 1:
        return DashboardScreen(state: widget.state, journal: widget.journal, onOpenTab: _select);
      case 2:
        return TradesScreen(state: widget.state, journal: widget.journal);
      default:
        return AnalyticsScreen(state: widget.state, journal: widget.journal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < 4; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Trades',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
