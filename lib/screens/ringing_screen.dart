import 'package:flutter/material.dart';

import '../core/instruments.dart';
import '../state/app_state.dart';

/// Full-screen overlay shown while an alarm is ringing.
class RingingScreen extends StatefulWidget {
  const RingingScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ringingIds = state.ring.alertIds;
    final ringing = state.alerts.where((a) => ringingIds.contains(a.id)).toList();
    final quotes = state.quotes;

    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2F7BFF), Color(0xFF123FBF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.9, end: 1.1)
                                .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                            child: const Icon(Icons.notifications_active_rounded, size: 120, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Price alert',
                            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 24),
                          for (final alert in ringing)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.symbol,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Target ${instrumentFor(alert.symbol).format(alert.target)}'
                                    '${quotes[alert.symbol] == null ? '' : '  ·  Now ${instrumentFor(alert.symbol).format(quotes[alert.symbol]!.price)}'}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                  if (alert.note.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(alert.note, style: const TextStyle(color: Colors.white, fontSize: 16)),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF123FBF),
                    ),
                    onPressed: state.stopAlarm,
                    child: const Text('STOP ALARM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
