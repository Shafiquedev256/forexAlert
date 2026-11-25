import 'package:flutter/material.dart';

import '../core/format.dart';
import '../journal/field_specs.dart';
import '../journal/journal_api.dart';
import '../journal/journal_controller.dart';
import '../journal/models/trade.dart';
import '../widgets/price_ladder.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'stage_sheets.dart';
import 'trade_flow.dart';

class TradeDetailScreen extends StatefulWidget {
  const TradeDetailScreen({super.key, required this.journal, required this.id});

  final JournalController journal;
  final String id;

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  late Future<Trade> _future = widget.journal.api.getTrade(widget.id);

  @override
  void initState() {
    super.initState();
    widget.journal.addListener(_reload);
  }

  @override
  void dispose() {
    widget.journal.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {
      _future = widget.journal.api.getTrade(widget.id);
    });
  }

  Future<void> _confirmDelete(Trade trade) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this trade?'),
        content: Text('${trade.pair} will be removed from your journal and your statistics.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await widget.journal.delete(trade.id);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Trade>(
      future: _future,
      builder: (context, snapshot) {
        final trade = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(trade?.pair ?? 'Trade'),
            actions: [
              if (trade != null) ...[
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => openEditTrade(context, widget.journal, trade),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(trade),
                ),
              ],
            ],
          ),
          bottomNavigationBar: trade == null ? null : _stageBar(trade),
          body: _body(snapshot, trade),
        );
      },
    );
  }

  Widget? _stageBar(Trade trade) {
    String? label;
    Future<bool?> Function()? action;
    if (trade.status == 'planned') {
      label = 'Move to open';
      action = () => showMoveToOpenSheet(context, widget.journal, trade);
    } else if (trade.status == 'open') {
      label = 'Close trade';
      action = () => showCloseTradeSheet(context, widget.journal, trade);
    }
    if (label == null || action == null) return null;
    final run = action;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(height: 52, child: FilledButton(onPressed: run, child: Text(label))),
      ),
    );
  }

  Widget _body(AsyncSnapshot<Trade> snapshot, Trade? trade) {
    if (snapshot.connectionState != ConnectionState.done && trade == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      final e = snapshot.error;
      if (e is ApiException && e.isNotFound) {
        return  ListView(
          children: [
            EmptyState(
              icon: Icons.search_off,
              title: 'Trade not found',
              message: 'It may have been deleted.',
            ),
          ],
        );
      }
      return ListView(
        children: [
          ErrorState(
            message: e is ApiException ? JournalController.friendly(e) : 'Could not load this trade.',
            onRetry: _reload,
          ),
        ],
      );
    }
    return _content(trade!);
  }

  Widget _content(Trade t) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          title: 'Result',
          trailing: StatusBadge(t.status),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RValue(t.rMultiple, size: 40),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Planned R:R ${fmtNum(t.plannedRR)}', style: muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DirectionBadge(t.direction),
                if (t.session != null) SessionBadge(t.session!),
                if (t.setup != null) Text(titleCase(t.setup!), style: muted),
              ],
            ),
            const SizedBox(height: 8),
            Text('Entered ${fmtDateTime(t.entryTime)}', style: muted),
            if (t.exitTime != null) Text('Exited ${fmtDateTime(t.exitTime)}', style: muted),
          ],
        ),
        SectionCard(title: 'Price ladder', children: [PriceLadder(trade: t)]),
        _fieldsCard('Strategy', t, [FieldSection.plan]),
        _fieldsCard('Execution', t, [FieldSection.entry, FieldSection.exit]),
        _fieldsCard('Psychology', t, [FieldSection.psychology]),
        _fieldsCard('Review', t, [FieldSection.review]),
        _screenshots(t),
        Text('Created ${fmtDateTime(t.createdAt)}  ·  Updated ${fmtDateTime(t.updatedAt)}', style: muted),
      ],
    );
  }

  Widget _screenshots(Trade t) {
    final entry = t.str('entryScreenshot');
    final exit = t.str('exitScreenshot');
    if (entry == null && exit == null) return const SizedBox.shrink();

    Widget shot(String label, String? url) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            if (url == null)
              const Text('-')
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    alignment: Alignment.center,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Text('Image unavailable'),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return SectionCard(
      title: 'Screenshots',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [shot('Entry', entry), const SizedBox(width: 12), shot('Exit', exit)],
        ),
      ],
    );
  }

  Widget _fieldsCard(String title, Trade t, List<FieldSection> sections) {
    final rows = <Widget>[];
    for (final spec in tradeFields) {
      if (!sections.contains(spec.section) || spec.kind == FieldKind.url) continue;
      final row = _row(spec, t);
      if (row != null) rows.add(row);
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(title: title, children: rows);
  }

  Widget? _row(FieldSpec s, Trade t) {
    final scheme = Theme.of(context).colorScheme;
    final label = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);

    if (s.kind == FieldKind.tags) {
      final tags = t.list(s.key);
      if (tags.isEmpty) return null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.label, style: label),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [for (final v in tags) Chip(label: Text(v))]),
          ],
        ),
      );
    }

    final value = _valueText(s, t);
    if (value == null) return null;

    if (s.kind == FieldKind.longText) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(s.label, style: label), const SizedBox(height: 2), Text(value)],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(s.label, style: label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String? _valueText(FieldSpec s, Trade t) {
    const priceKeys = {'entryPrice', 'stopLoss', 'takeProfit', 'exitPrice'};
    switch (s.kind) {
      case FieldKind.number:
        final v = t.dbl(s.key);
        if (v == null) return null;
        return priceKeys.contains(s.key) ? fmtPrice(t.pair, v) : fmtNum(v);
      case FieldKind.integer:
      case FieldKind.scale:
        final v = t.integer(s.key);
        return v?.toString();
      case FieldKind.dateTime:
        final d = t.date(s.key);
        return d == null ? null : fmtDateTime(d);
      case FieldKind.tri:
        final b = t.flag(s.key);
        return b == null ? null : (b ? 'Yes' : 'No');
      case FieldKind.choice:
        final v = t.str(s.key);
        return v == null ? null : labelFor(s.key, v);
      case FieldKind.text:
      case FieldKind.longText:
      case FieldKind.url:
        return t.str(s.key);
      case FieldKind.tags:
        return null;
    }
  }
}
