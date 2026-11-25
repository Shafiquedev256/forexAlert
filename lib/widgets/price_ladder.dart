import 'package:flutter/material.dart';

import '../core/format.dart';
import '../journal/models/trade.dart';
import 'ui.dart';

/// Take profit, entry, stop loss and exit, ordered from the highest price down.
class PriceLadder extends StatelessWidget {
  const PriceLadder({super.key, required this.trade});

  final Trade trade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <({String label, double price, Color color})>[
      if (trade.takeProfit != null) (label: 'Take profit', price: trade.takeProfit!, color: kGain),
      if (trade.entryPrice != null) (label: 'Entry', price: trade.entryPrice!, color: scheme.primary),
      if (trade.stopLoss != null) (label: 'Stop loss', price: trade.stopLoss!, color: kLoss),
      if (trade.exitPrice != null) (label: 'Exit', price: trade.exitPrice!, color: scheme.onSurface),
    ]..sort((a, b) => b.price.compareTo(a.price));

    if (rows.isEmpty) {
      return Text('No prices set yet.', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(r.label)),
                Text(
                  fmtPrice(trade.pair, r.price),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
