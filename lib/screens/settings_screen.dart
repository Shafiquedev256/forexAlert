import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/tone_store.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late final TextEditingController _keyController =
      TextEditingController(text: widget.state.apiKey);
  late Future<({bool notifications, bool battery})> _permissions = _loadPermissions();
  bool _hideKey = true;

  Future<({bool notifications, bool battery})> _loadPermissions() async => (
        notifications: await widget.state.notificationsGranted(),
        battery: await widget.state.batteryUnrestricted(),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Coming back from a system settings page: re-check permissions.
    if (lifecycleState == AppLifecycleState.resumed) {
      setState(() => _permissions = _loadPermissions());
    }
  }

  Future<void> _chooseDefaultTone() async {
    final path = await widget.state.pickTone();
    if (path != null) await widget.state.setDefaultTone(path);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final perDay = state.activeForexSymbolCount * (86400 ~/ state.forexIntervalSec);

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(title: 'Appearance', children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (s) => state.setThemeMode(s.first),
                ),
              ]),
              _Section(title: 'Price feed', children: [
                const Text('Gold and forex use Twelve Data (free key). BTC uses Binance, no key needed.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: _hideKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Twelve Data API key',
                    suffixIcon: IconButton(
                      icon: Icon(_hideKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hideKey = !_hideKey),
                    ),
                  ),
                  onSubmitted: state.setApiKey,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await state.setApiKey(_keyController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('API key saved')));
                      }
                    },
                    child: const Text('Save key'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: const [60, 120, 180, 300, 600].contains(state.forexIntervalSec)
                      ? state.forexIntervalSec
                      : 300,
                  decoration: const InputDecoration(labelText: 'Gold / forex check interval'),
                  items: const [
                    DropdownMenuItem(value: 60, child: Text('Every 1 minute')),
                    DropdownMenuItem(value: 120, child: Text('Every 2 minutes')),
                    DropdownMenuItem(value: 180, child: Text('Every 3 minutes')),
                    DropdownMenuItem(value: 300, child: Text('Every 5 minutes')),
                    DropdownMenuItem(value: 600, child: Text('Every 10 minutes')),
                  ],
                  onChanged: (v) => v == null ? null : state.setForexInterval(v),
                ),
                if (state.activeForexSymbolCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'About $perDay credits/day on weekdays (free plan allows 800).',
                    style: TextStyle(
                      fontSize: 12,
                      color: perDay > 800 ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ]),
              _Section(title: 'Default ringtone', children: [
                Row(
                  children: [
                    Expanded(child: Text(ToneStore.displayName(state.defaultTonePath))),
                    IconButton(
                      tooltip: 'Play',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => state.previewTone(null),
                    ),
                    TextButton(onPressed: _chooseDefaultTone, child: const Text('Choose')),
                    if (state.defaultTonePath != null)
                      IconButton(
                        tooltip: 'Use built-in alarm',
                        icon: const Icon(Icons.close),
                        onPressed: () => state.setDefaultTone(null),
                      ),
                  ],
                ),
              ]),
              _Section(title: 'Reliability', children: [
                FutureBuilder(
                  future: _permissions,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Column(
                      children: [
                        _PermissionRow(
                          label: 'Notifications',
                          ok: data?.notifications ?? false,
                          onFix: () async {
                            await state.requestNotifications();
                            setState(() => _permissions = _loadPermissions());
                          },
                        ),
                        _PermissionRow(
                          label: 'Unrestricted battery',
                          ok: data?.battery ?? false,
                          onFix: state.requestBatteryUnrestricted,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Both are needed for alerts to ring reliably with the screen off. '
                  'After restarting your phone, open the app once.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ]),
              _Section(title: 'Privacy', children: [
                const Text(
                  'No account, analytics or ads. Alerts and settings never leave your phone. '
                  'The only network requests go to Binance (BTC) and Twelve Data (gold and forex) '
                  'over HTTPS. Put the app to sleep to switch everything off.',
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.ok, required this.onFix});

  final String label;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? scheme.primary : scheme.error),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (!ok) TextButton(onPressed: onFix, child: const Text('Fix')),
      ],
    );
  }
}
