import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

const Color kGain = Color(0xFF16A34A);
const Color kLoss = Color(0xFFDC2626);
const Color kShort = Color(0xFFEA580C);

/// R multiple with colour and an explicit sign (colour is never the only cue).
class RValue extends StatelessWidget {
  const RValue(this.value, {super.key, this.size = 16});

  final double? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final color = v == null
        ? scheme.onSurfaceVariant
        : v > 0.004
            ? kGain
            : v < -0.004
                ? kLoss
                : scheme.onSurface;
    return Text(fmtR(v), style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700));
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.background, this.foreground);

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    switch (status) {
      case 'open':
        return _Pill('OPEN', s.primary, s.onPrimary);
      case 'closed':
        return _Pill('CLOSED', s.primaryContainer, s.onPrimaryContainer);
      case 'skipped':
        return _Pill('SKIPPED', s.surfaceContainerHighest, s.onSurfaceVariant);
      default:
        return _Pill('PLANNED', s.secondaryContainer, s.onSecondaryContainer);
    }
  }
}

class DirectionBadge extends StatelessWidget {
  const DirectionBadge(this.direction, {super.key});

  final String direction;

  @override
  Widget build(BuildContext context) {
    final isLong = direction != 'short';
    final color = isLong ? Theme.of(context).colorScheme.primary : kShort;
    return _Pill(isLong ? '▲ LONG' : '▼ SHORT', color.withValues(alpha: 0.14), color);
  }
}

class SessionBadge extends StatelessWidget {
  const SessionBadge(this.session, {super.key});

  final String session;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return _Pill(labelFor('session', session), s.surfaceContainerHighest, s.onSurfaceVariant);
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, this.hint, this.valueColor});

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: valueColor ?? scheme.onSurface),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// A titled rounded card used on detail, form and analytics pages.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Green above zero, red below, default colour otherwise.
Color? signColor(double? v) {
  if (v == null) return null;
  if (v > 0.004) return kGain;
  if (v < -0.004) return kLoss;
  return null;
}
