import 'package:flutter/material.dart';

import '../models/price_alert.dart';
import '../state/app_state.dart';
import '../widgets/alert_card.dart';
import '../widgets/info_banner.dart';
import 'alert_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  void _openForm(BuildContext context, [PriceAlert? alert]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AlertFormScreen(state: state, existing: alert),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, PriceAlert alert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete alert?'),
        content: Text('${alert.symbol} · ${alert.target}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteAlert(alert.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final alerts = state.alerts.reversed.toList();
        final fired = state.fired;
        final quotes = state.quotes;
        final sleeping = state.sleeping;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('Forex Alert'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: sleeping ? 'Wake app' : 'Put app to sleep',
                icon: Icon(sleeping ? Icons.wb_sunny_outlined : Icons.bedtime_outlined),
                onPressed: () => state.setSleeping(!sleeping),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(state: state)),
                ),
              ),
            ],
          ),
          floatingActionButton: sleeping
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New alert'),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (sleeping)
                InfoBanner(
                  icon: Icons.bedtime_outlined,
                  message: 'App is asleep. Alerts are off and no network requests are made.',
                  actionLabel: 'Wake up',
                  onAction: () => state.setSleeping(false),
                ),
              if (!sleeping && state.feedError != null)
                InfoBanner(
                  icon: Icons.cloud_off_outlined,
                  message: 'Price feed: ${state.feedError}',
                  isError: true,
                ),
              if (alerts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 72, color: scheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No alerts yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Tap “New alert” to create your first one.',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              for (final alert in alerts)
                AlertCard(
                  key: ValueKey(alert.id),
                  alert: alert,
                  quote: quotes[alert.symbol],
                  firedAt: alert.firedAt(fired),
                  onToggle: (on) => state.setEnabled(alert.id, on),
                  onEdit: () => _openForm(context, alert),
                  onDelete: () => _confirmDelete(context, alert),
                  onRearm: () => state.rearm(alert.id),
                ),
            ],
          ),
        );
      },
    );
  }
}
