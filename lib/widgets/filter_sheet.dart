import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/options.dart';
import '../journal/filters.dart';

/// Bottom sheet to edit pair, direction, setup, session, timeframe, market
/// condition and date range. Returns the new filters, or null if dismissed.
Future<TradeFilters?> showFilterSheet(
  BuildContext context, {
  required TradeFilters current,
  required List<String> setups,
}) {
  return showModalBottomSheet<TradeFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(initial: current.copy(), setups: setups),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.setups});

  final TradeFilters initial;
  final List<String> setups;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TradeFilters _f = widget.initial;

  Widget _dropdown(String label, String key, List<String> options, String? value, ValueChanged<String?> onChanged) {
    final all = <String>{...options, if (value != null) value}.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value ?? '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Any')),
          for (final o in all) DropdownMenuItem(value: o, child: Text(labelFor(key, o))),
        ],
        onChanged: (v) => setState(() => onChanged((v == null || v.isEmpty) ? null : v)),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _f.from : _f.to) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() {
      isFrom ? _f.from = picked : _f.to = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _dropdown('Pair', 'pair', pairOptions, _f.pair, (v) => _f.pair = v),
            _dropdown('Direction', 'direction', const ['long', 'short'], _f.direction, (v) => _f.direction = v),
            _dropdown('Setup', 'setup', widget.setups, _f.setup, (v) => _f.setup = v),
            _dropdown('Session', 'session', sessionOptions, _f.session, (v) => _f.session = v),
            _dropdown('Timeframe', 'timeframe', timeframes, _f.timeframe, (v) => _f.timeframe = v),
            _dropdown('Market condition', 'marketCondition', marketConditions, _f.marketCondition, (v) => _f.marketCondition = v),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(_f.from == null ? 'From date' : 'From ${fmtDate(_f.from)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(_f.to == null ? 'To date' : 'To ${fmtDate(_f.to)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(_f.clear),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context, _f), child: const Text('Apply')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
