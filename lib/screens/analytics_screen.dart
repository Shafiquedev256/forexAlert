import 'package:flutter/material.dart';

import '../charts/charts.dart';
import '../core/app_config.dart';
import '../core/format.dart';
import '../journal/filters.dart';
import '../journal/journal_api.dart';
import '../journal/journal_controller.dart';
import '../journal/models/stats.dart';
import '../journal/models/trade.dart';
import '../state/app_state.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/info_banner.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'settings_screen.dart';

const _segmentTabs = <(String, String)>[
  ('setup', 'Setup'),
  ('pair', 'Pair'),
  ('session', 'Session'),
  ('direction', 'Direction'),
  ('timeframe', 'Timeframe'),
  ('marketCondition', 'Market'),
  ('emotionAtEntry', 'Emotion'),
  ('followedRules', 'Rules'),
  ('dayOfWeek', 'Weekday'),
];

class _AnalyticsData {
  const _AnalyticsData(this.stats, this.closed);

  final Stats stats;

  /// Up to 200 closed trades, used for mistake and emotion frequency.
  final List<Trade> closed;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.state, required this.journal});

  final AppState state;
  final JournalController journal;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final TradeFilters _filters = TradeFilters();
  String _segment = 'setup';
  Future<_AnalyticsData>? _future;

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

  Future<_AnalyticsData>? _start() => widget.journal.configured ? _load() : null;

  void _reload() {
    if (mounted) setState(() {
      _future = _start();
    });
  }

  Future<_AnalyticsData> _load() async {
    final api = widget.journal.api;
    final statsQuery = _filters.toQuery(includeStatus: false, includeSort: false);
    final listQuery = {..._filters.toQuery(includeStatus: false), 'status': 'closed', 'limit': '200'};
    final (stats, closed) = await (api.stats(statsQuery), api.listTrades(listQuery)).wait;
    return _AnalyticsData(stats, closed.items);
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, current: _filters, setups: widget.journal.setupOptions);
    if (result == null) return;
    _filters
      ..pair = result.pair
      ..direction = result.direction
      ..setup = result.setup
      ..session = result.session
      ..timeframe = result.timeframe
      ..marketCondition = result.marketCondition
      ..from = result.from
      ..to = result.to;
    _reload();
  }

  String _message(Object? e) =>
      e is ApiException ? JournalController.friendly(e) : 'Could not load your analytics.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: Badge(
              label: Text('${_filters.activeCount}'),
              isLabelVisible: _filters.activeCount > 0,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilters,
          ),
          settingsButton(context, widget.state, widget.journal),
        ],
      ),
      body: !widget.journal.configured
          ? SetupPrompt(onOpenSettings: () => openSettings(context, widget.state, widget.journal))
          : RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: FutureBuilder<_AnalyticsData>(
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

  Widget _content(_AnalyticsData d) {
    final s = d.stats;
    if (s.overall.trades == 0) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.insights_outlined,
            title: 'Nothing to analyse yet',
            message: 'Statistics use closed trades only. Close a trade and it will show up here.',
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final o = s.overall;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (s.sampleWarning != null) InfoBanner(icon: Icons.info_outline, message: s.sampleWarning!),
        _kpis(s),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Equity curve (R)',
          children: [LineSeriesChart(values: s.equityCurve.map((e) => e.cumulativeR).toList(), suffix: 'R')],
        ),
        SectionCard(
          title: 'Rolling ${s.rollingWindow} trades',
          children: s.rolling.isEmpty
              ? [
                  Text(
                    'This view appears once you have ${s.rollingWindow} closed trades (you have ${o.trades}).',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ]
              : [
                  const Text('Expectancy (R)'),
                  LineSeriesChart(values: s.rolling.map((p) => p.expectancyR).toList(), suffix: 'R', height: 150),
                  const SizedBox(height: 12),
                  const Text('Win rate (%)'),
                  LineSeriesChart(
                    values: s.rolling.map((p) => pctFromFraction(p.winRate) ?? 0).toList(),
                    suffix: '%',
                    height: 150,
                  ),
                ],
        ),
        SectionCard(
          title: 'Weekly result (R)',
          children: s.weekly.isEmpty
              ? [Text('No weekly data yet.', style: TextStyle(color: scheme.onSurfaceVariant))]
              : [
                  SignedBarsChart(
                    data: [
                      for (final w in s.weekly)
                        BarDatum(w.week.length >= 10 ? w.week.substring(5) : w.week, w.totalR),
                    ],
                    suffix: 'R',
                  ),
                ],
        ),
        _segments(s),
        _insightsCard(s),
        _frequencyCard(d.closed),
        Text(
          'Weeks and weekdays are counted in UTC, so they can differ by a day from your local time near midnight.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _kpis(Stats s) {
    final o = s.overall;
    final items = <Widget>[
      KpiCard(label: 'Expectancy', value: fmtR(o.expectancyR), valueColor: signColor(o.expectancyR)),
      KpiCard(label: 'Win rate', value: fmtPct(pctFromFraction(o.winRate)), hint: '${o.trades} trades'),
      KpiCard(label: 'Total R', value: fmtR(o.totalR), valueColor: signColor(o.totalR)),
      KpiCard(label: 'Profit factor', value: fmtNum(o.profitFactor)),
      KpiCard(label: 'Avg win / loss', value: '${fmtNum(o.avgWinR)} / ${fmtNum(o.avgLossR)}', hint: 'in R'),
      KpiCard(label: 'Profitable weeks', value: fmtPct(s.profitableWeeksPct)),
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

  Widget _segments(Stats s) {
    final scheme = Theme.of(context).colorScheme;
    final rows = s.segments[_segment] ?? const <SegmentRow>[];

    return SectionCard(
      title: 'Breakdown',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (key, label) in _segmentTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _segment == key,
                    onSelected: (_) => setState(() => _segment = key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text('No data for this breakdown yet.', style: TextStyle(color: scheme.onSurfaceVariant))
        else ...[
          SignedBarsChart(
            data: [
              for (final r in rows.take(12))
                BarDatum(
                  _short(labelFor(_segment, r.key)),
                  r.summary.expectancyR ?? 0,
                  faded: r.summary.trades < AppConfig.lowSampleTrades,
                ),
            ],
            suffix: 'R',
            height: 180,
          ),
          const SizedBox(height: 4),
          Text('Bars show expectancy (R). Faded bars have fewer than ${AppConfig.lowSampleTrades} trades.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          for (final r in rows) _segmentRow(r),
        ],
      ],
    );
  }

  String _short(String s) => s.length <= 8 ? s : '${s.substring(0, 7)}…';

  Widget _segmentRow(SegmentRow r) {
    final scheme = Theme.of(context).colorScheme;
    final low = r.summary.trades < AppConfig.lowSampleTrades;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(labelFor(_segment, r.key), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (low)
                  Text('low sample', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${r.summary.trades} trades', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 2,
            child: Text(fmtPct(pctFromFraction(r.summary.winRate)), style: const TextStyle(fontSize: 12)),
          ),
          RValue(r.summary.expectancyR, size: 13),
        ],
      ),
    );
  }

  // ---- Insights (calculated in code) -------------------------------------

  List<SegmentRow> _ranked(Stats s, String segment) {
    final rows = (s.segments[segment] ?? const <SegmentRow>[]).where((r) => r.summary.expectancyR != null).toList();
    rows.sort((a, b) => b.summary.expectancyR!.compareTo(a.summary.expectancyR!));
    return rows;
  }

  String _tag(SegmentRow r) => r.summary.trades < AppConfig.lowSampleTrades ? ' (low sample)' : '';

  List<String> _insights(Stats s) {
    final out = <String>[];

    void bestWorst(String segment, String noun) {
      final rows = _ranked(s, segment);
      if (rows.isEmpty) return;
      final best = rows.first;
      out.add('Best $noun: ${labelFor(segment, best.key)} (${fmtR(best.summary.expectancyR)} per trade)${_tag(best)}.');
      if (rows.length > 1) {
        final worst = rows.last;
        out.add('Weakest $noun: ${labelFor(segment, worst.key)} (${fmtR(worst.summary.expectancyR)} per trade)${_tag(worst)}.');
      }
    }

    bestWorst('setup', 'setup');
    bestWorst('session', 'session');

    final rules = s.segments['followedRules'] ?? const <SegmentRow>[];
    SegmentRow? followed;
    SegmentRow? broke;
    for (final r in rules) {
      final k = r.key.toLowerCase();
      if (k == 'true' || k == 'yes') followed = r;
      if (k == 'false' || k == 'no') broke = r;
    }
    if (followed != null && broke != null) {
      out.add('When you followed your rules: ${fmtR(followed.summary.expectancyR)} per trade. '
          'When you did not: ${fmtR(broke.summary.expectancyR)}.');
    }
    return out;
  }

  Widget _insightsCard(Stats s) {
    final items = _insights(s);
    return SectionCard(
      title: 'Insights',
      children: items.isEmpty
          ? [
              Text('Insights appear as you log more closed trades.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]
          : [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i)),
                    ],
                  ),
                ),
            ],
    );
  }

  Widget _frequencyCard(List<Trade> closed) {
    Map<String, int> count(Iterable<String> values) {
      final m = <String, int>{};
      for (final v in values) {
        m[v] = (m[v] ?? 0) + 1;
      }
      return m;
    }

    final mistakes = count(closed.expand((t) => t.list('mistakes')));
    final emotions = count(closed.map((t) => t.str('emotionAfter')).whereType<String>());

    return SectionCard(
      title: 'Behaviour',
      children: [
        _frequency('Most common mistakes', 'mistakes', mistakes),
        const SizedBox(height: 14),
        _frequency('Emotion after trades', 'emotionAfter', emotions),
        const SizedBox(height: 6),
        Text(
          'Based on up to your latest 200 closed trades.',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _frequency(String title, String key, Map<String, int> counts) {
    final scheme = Theme.of(context).colorScheme;
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (top.isEmpty)
          Text('Nothing recorded yet.', style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final e in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 96, child: Text(labelFor(key, e.key), overflow: TextOverflow.ellipsis)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: e.value / max, minHeight: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}'),
                ],
              ),
            ),
      ],
    );
  }
}
