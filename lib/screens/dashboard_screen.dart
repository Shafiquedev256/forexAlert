import 'package:flutter/material.dart';

import '../charts/charts.dart';
import '../core/format.dart';
import '../journal/journal_api.dart';
import '../journal/journal_controller.dart';
import '../journal/models/stats.dart';
import '../journal/models/trade.dart';
import '../state/app_state.dart';
import '../widgets/info_banner.dart';
import '../widgets/state_views.dart';
import '../widgets/trade_tile.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart';
import 'trade_flow.dart';

enum _Range { week, month, all }

class _DashboardData {
  const _DashboardData(this.stats, this.open, this.recent);

  final Stats stats;
  final List<Trade> open;
  final List<Trade> recent;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.state, required this.journal, required this.onOpenTab});

  final AppState state;
  final JournalController journal;
  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Range _range = _Range.week;
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    widget.journal.addListener(_reload);
    _future = _start();
  }

  @override
  void dispose() {
    widget.journal.removeListener(_reload);
    super.dispose();
  }

  Future<_DashboardData>? _start() => widget.journal.configured ? _load() : null;

  void _reload() {
    if (mounted) setState(() {
      _future = _start();
    });
  }

  String? _from() {
    final now = DateTime.now();
    switch (_range) {
      case _Range.week:
        final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        return monday.toUtc().toIso8601String();
      case _Range.month:
        return DateTime(now.year, now.month, 1).toUtc().toIso8601String();
      case _Range.all:
        return null;
    }
  }

  Future<_DashboardData> _load() async {
    final api = widget.journal.api;
    final from = _from();
    final (stats, open, recent) = await (
      api.stats({if (from != null) 'from': from}),
      api.listTrades({'status': 'open', 'limit': '50', 'sort': '-entryTime'}),
      api.listTrades({'status': 'closed', 'limit': '5', 'sort': '-entryTime'}),
    ).wait;
    return _DashboardData(stats, open.items, recent.items);
  }

  String _message(Object? e) =>
      e is ApiException ? JournalController.friendly(e) : 'Could not load your journal.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [settingsButton(context, widget.state, widget.journal)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewTrade(context, widget.journal),
        icon: const Icon(Icons.add),
        label: const Text('Log trade'),
      ),
      body: !widget.journal.configured
          ? SetupPrompt(onOpenSettings: () => openSettings(context, widget.state, widget.journal))
          : RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: FutureBuilder<_DashboardData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return ListView(
                      children: const [SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))],
                    );
                  }
                  if (snap.hasError) {
                    return ListView(children: [ErrorState(message: _message(snap.error), onRetry: _reload)]);
                  }
                  return _content(snap.data!);
                },
              ),
            ),
    );
  }

  Widget _content(_DashboardData d) {
    final s = d.stats;
    final nothingAtAll = s.overall.trades == 0 && d.open.isEmpty && d.recent.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        SegmentedButton<_Range>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Range.week, label: Text('This week')),
            ButtonSegment(value: _Range.month, label: Text('This month')),
            ButtonSegment(value: _Range.all, label: Text('All time')),
          ],
          selected: {_range},
          onSelectionChanged: (v) {
            _range = v.first;
            _reload();
          },
        ),
        const SizedBox(height: 14),
        if (s.sampleWarning != null) InfoBanner(icon: Icons.info_outline, message: s.sampleWarning!),
        if (nothingAtAll)
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Your journal is empty',
            message: 'Log your first trade to start tracking your edge.',
            actionLabel: 'Log trade',
            onAction: () => openNewTrade(context, widget.journal),
          )
        else ...[
          if (s.overall.trades == 0)
            const InfoBanner(icon: Icons.insights_outlined, message: 'No closed trades in this range yet.')
          else ...[
            _kpis(s),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Equity curve (R)',
              children: [LineSeriesChart(values: s.equityCurve.map((e) => e.cumulativeR).toList(), suffix: 'R')],
            ),
          ],
          _tradeSection('Open trades', d.open, 'No open trades.'),
          _tradeSection('Last closed trades', d.recent, 'No closed trades yet.', onSeeAll: () => widget.onOpenTab(2)),
        ],
      ],
    );
  }

  Widget _kpis(Stats s) {
    final o = s.overall;
    final items = <Widget>[
      KpiCard(label: 'Expectancy', value: fmtR(o.expectancyR), hint: 'per trade', valueColor: signColor(o.expectancyR)),
      KpiCard(label: 'Win rate', value: fmtPct(pctFromFraction(o.winRate)), hint: '${o.wins}W / ${o.losses}L'),
      KpiCard(label: 'Total R', value: fmtR(o.totalR), hint: '${o.trades} closed', valueColor: signColor(o.totalR)),
      KpiCard(label: 'Profit factor', value: fmtNum(o.profitFactor)),
      KpiCard(label: 'Rule adherence', value: fmtPct(s.adherencePct)),
      KpiCard(label: 'Max drawdown', value: '${fmtNum(s.maxDrawdownR)}R', hint: 'losing streak ${s.maxLosingStreak}'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final i in items) SizedBox(width: w, child: i)],
        );
      },
    );
  }

  Widget _tradeSection(String title, List<Trade> trades, String empty, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 6),
          if (trades.isEmpty)
            Text(empty, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            for (final t in trades)
              TradeTile(trade: t, onTap: () => openTrade(context, widget.journal, t.id)),
        ],
      ),
    );
  }
}
