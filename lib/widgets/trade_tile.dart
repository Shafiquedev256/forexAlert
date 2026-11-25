import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../journal/models/trade.dart';
import 'ui.dart';

/// One trade in a list: pair, direction, status, R and key prices.
class TradeTile extends StatelessWidget {
  const TradeTile({super.key, required this.trade, required this.onTap});

  final Trade trade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    final followed = trade.followedRules;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trade.pair, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    DirectionBadge(trade.direction),
                    const Spacer(),
                    RValue(trade.rMultiple, size: 17),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(trade.status),
                    if (trade.session != null) SessionBadge(trade.session!),
                    if (trade.setup != null) Text(titleCase(trade.setup!), style: muted),
                    if (followed != null)
                      Icon(
                        followed ? Icons.rule_folder_outlined : Icons.report_gmailerrorred_outlined,
                        size: 16,
                        color: followed ? kGain : kLoss,
                        semanticLabel: followed ? 'Followed rules' : 'Broke rules',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  fmtDateTime(trade.entryTime ?? trade.createdAt),
                  style: muted,
                ),
                if (trade.entryPrice != null || trade.stopLoss != null || trade.takeProfit != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Entry ${fmtPrice(trade.pair, trade.entryPrice)}   SL ${fmtPrice(trade.pair, trade.stopLoss)}   TP ${fmtPrice(trade.pair, trade.takeProfit)}',
                    style: muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
