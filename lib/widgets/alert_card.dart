import 'package:flutter/material.dart';

import '../core/instruments.dart';
import '../core/theme.dart';
import '../models/price_alert.dart';
import '../models/quote.dart';

enum _CardAction { edit, delete }

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.quote,
    required this.firedAt,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onRearm,
  });

  final PriceAlert alert;
  final Quote? quote;

  /// Epoch ms when it fired, or null while it is still waiting.
  final int? firedAt;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRearm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final instrument = instrumentFor(alert.symbol);
    final price = quote?.price;
    final triggered = firedAt != null;

    return Opacity(
      opacity: (alert.enabled || triggered) ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.notifications_active_outlined, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.symbol, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${alert.direction.verb} ${instrument.format(alert.target)}',
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!triggered) Switch(value: alert.enabled, onChanged: onToggle),
                PopupMenuButton<_CardAction>(
                  onSelected: (a) => a == _CardAction.edit ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: _CardAction.edit, child: Text('Edit')),
                    PopupMenuItem(value: _CardAction.delete, child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (price != null) ...[
              const SizedBox(height: 12),
              _distanceRow(context, instrument, price),
            ],
            if (alert.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(alert.note, style: text.bodyMedium),
            ],
            if (triggered) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Triggered at ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(firedAt!)).format(context)}',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    TextButton(onPressed: onRearm, child: const Text('Re-arm')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _distanceRow(BuildContext context, Instrument instrument, double price) {
    final scheme = Theme.of(context).colorScheme;
    final diff = alert.target - price;
    final percent = price == 0 ? 0 : diff / price * 100;
    return Row(
      children: [
        Icon(Icons.show_chart, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        Text('Now ${instrument.format(price)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Text(
          '${diff >= 0 ? '+' : '-'}${instrument.format(diff.abs())} (${percent.abs().toStringAsFixed(2)}%) to target',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}
