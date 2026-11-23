import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isError ? scheme.errorContainer : scheme.primaryContainer;
    final foreground = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: foreground))),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
