import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/theme.dart';
import '../journal/journal_controller.dart';
import '../services/tone_store.dart';
import '../state/app_state.dart';

void openSettings(BuildContext context, AppState state, JournalController journal) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SettingsScreen(state: state, journal: journal)),
  );
}

/// App-bar button shared by every tab.
Widget settingsButton(BuildContext context, AppState state, JournalController journal) {
  return IconButton(
    tooltip: 'Settings',
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => openSettings(context, state, journal),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state, required this.journal});

  final AppState state;
  final JournalController journal;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  late final TextEditingController _priceKey = TextEditingController(text: widget.state.apiKey);
  late final TextEditingController _journalUrl = TextEditingController(text: widget.journal.baseUrl);
  late final TextEditingController _journalKey = TextEditingController(text: widget.journal.apiKey);
  late Future<({bool notifications, bool battery})> _permissions = _loadPermissions();
  bool _hidePriceKey = true;
  bool _hideJournalKey = true;
  bool _testing = false;

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
    _priceKey.dispose();
    _journalUrl.dispose();
    _journalKey.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // Coming back from a system settings page: re-check permissions.
    if (lifecycleState == AppLifecycleState.resumed) {
      setState(() {
      _permissions = _loadPermissions();
    });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseDefaultTone() async {
    final path = await widget.state.pickTone();
    if (path != null) await widget.state.setDefaultTone(path);
  }

  Future<void> _saveJournal() async {
    await widget.journal.saveConnection(_journalUrl.text, _journalKey.text);
    if (mounted) _snack('Journal connection saved');
  }

  Future<void> _testJournal() async {
    setState(() {
      _testing = true;
    });
    await widget.journal.saveConnection(_journalUrl.text, _journalKey.text);
    final message = await widget.journal.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
    });
    _snack(message);
  }

  String _intervalLabel(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    final m = seconds ~/ 60;
    return m == 1 ? '1 minute' : '$m minutes';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final symbols = state.activeForexSymbolCount;
        final effective = effectiveForexIntervalSec(state.forexIntervalSec, symbols);
        final perDay = symbols * (86400 ~/ effective);
        final perMinute = symbols * 60 / effective;
        final overLimit = perDay > AppConfig.freePlanCreditsPerDay || perMinute > AppConfig.freePlanCreditsPerMinute;

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
              _Section(title: 'Trade journal connection', children: [
                const Text(
                  'Your journal API. The key is stored only on this phone and is never part of the app or the code.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _journalUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'API base URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _journalKey,
                  obscureText: _hideJournalKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Journal API key',
                    suffixIcon: IconButton(
                      icon: Icon(_hideJournalKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hideJournalKey = !_hideJournalKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _saveJournal, child: const Text('Save'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _testing ? null : _testJournal,
                        child: _testing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Save and test'),
                      ),
                    ),
                  ],
                ),
              ]),
              _Section(title: 'Price feed', children: [
                Text('BTC updates every ${AppConfig.cryptoIntervalSec} seconds (Binance, no key needed).'),
                const SizedBox(height: 12),
                const Text('Gold and forex use Twelve Data (free key).'),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceKey,
                  obscureText: _hidePriceKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Twelve Data API key',
                    suffixIcon: IconButton(
                      icon: Icon(_hidePriceKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hidePriceKey = !_hidePriceKey),
                    ),
                  ),
                  onSubmitted: state.setApiKey,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await state.setApiKey(_priceKey.text);
                      if (mounted) _snack('Price API key saved');
                    },
                    child: const Text('Save key'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: const [0, 10, 30, 60, 120, 300, 600].contains(state.forexIntervalSec)
                      ? state.forexIntervalSec
                      : 0,
                  decoration: const InputDecoration(labelText: 'Gold / forex check interval'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Auto (fits the free plan)')),
                    DropdownMenuItem(value: 10, child: Text('Every 10 seconds')),
                    DropdownMenuItem(value: 30, child: Text('Every 30 seconds')),
                    DropdownMenuItem(value: 60, child: Text('Every 1 minute')),
                    DropdownMenuItem(value: 120, child: Text('Every 2 minutes')),
                    DropdownMenuItem(value: 300, child: Text('Every 5 minutes')),
                    DropdownMenuItem(value: 600, child: Text('Every 10 minutes')),
                  ],
                  onChanged: (v) => v == null ? null : state.setForexInterval(v),
                ),
                const SizedBox(height: 8),
                Text(
                  symbols == 0
                      ? 'No gold or forex alerts are active, so nothing is fetched.'
                      : 'Checking every ${_intervalLabel(effective)}. About $perDay credits/day '
                          '(free plan: ${AppConfig.freePlanCreditsPerDay}/day, ${AppConfig.freePlanCreditsPerMinute}/min).',
                  style: TextStyle(fontSize: 12, color: overLimit ? scheme.error : scheme.onSurfaceVariant),
                ),
                if (symbols > 0 && overLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'This is above the free plan, so checks will pause whenever the limit is hit. '
                      'A paid Twelve Data plan removes the limit.',
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  ),
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
                            setState(() {
      _permissions = _loadPermissions();
    });
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
                  'No account, analytics or ads. Alerts and settings stay on your phone. '
                  'Network requests go only to Binance (BTC), Twelve Data (gold and forex) and your own '
                  'journal API, all over HTTPS. Screenshot links you add are loaded from their own hosts '
                  'when you open a trade. Put the app to sleep to switch everything off.',
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
