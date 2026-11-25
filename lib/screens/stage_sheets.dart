import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/options.dart';
import '../core/trade_math.dart';
import '../journal/journal_controller.dart';
import '../journal/models/trade.dart';
import '../widgets/info_banner.dart';
import '../widgets/inputs.dart';
import '../widgets/ui.dart';

/// "Move to open": the few fields needed to start a planned trade.
Future<bool?> showMoveToOpenSheet(BuildContext context, JournalController journal, Trade trade) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MoveToOpenSheet(journal: journal, trade: trade),
  );
}

/// "Close trade": exit details plus a quick review.
Future<bool?> showCloseTradeSheet(BuildContext context, JournalController journal, Trade trade) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CloseTradeSheet(journal: journal, trade: trade),
  );
}

double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

class _MoveToOpenSheet extends StatefulWidget {
  const _MoveToOpenSheet({required this.journal, required this.trade});

  final JournalController journal;
  final Trade trade;

  @override
  State<_MoveToOpenSheet> createState() => _MoveToOpenSheetState();
}

class _MoveToOpenSheetState extends State<_MoveToOpenSheet> {
  late final TextEditingController _entry =
      TextEditingController(text: widget.trade.entryPrice?.toString() ?? '');
  late final TextEditingController _stop =
      TextEditingController(text: widget.trade.stopLoss?.toString() ?? '');
  DateTime _entryTime = DateTime.now();
  final Map<String, String> _errors = {};
  String? _banner;
  bool _saving = false;

  @override
  void dispose() {
    _entry.dispose();
    _stop.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final entry = _parse(_entry.text);
    final stop = _parse(_stop.text);
    final errors = <String, String>{};
    if (entry == null || entry <= 0) errors['entryPrice'] = 'Enter the entry price';
    if (stop == null || stop <= 0) errors['stopLoss'] = 'Enter the stop loss';
    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      return;
    }

    final payload = <String, dynamic>{
      'status': 'open',
      'entryTime': _entryTime.toUtc().toIso8601String(),
      if (entry != widget.trade.entryPrice) 'entryPrice': entry,
      if (stop != widget.trade.stopLoss) 'stopLoss': stop,
    };
    setState(() {
      _saving = true;
      _banner = null;
    });
    final result = await widget.journal.update(widget.trade.id, payload);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _errors
          ..clear()
          ..addAll(result.fieldErrors);
        _banner = result.error ?? 'Please fix the highlighted fields.';
      });
    }
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
            Text('Move to open', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_banner != null) InfoBanner(icon: Icons.error_outline, message: _banner!, isError: true),
            DateTimeField(
              label: 'Entry time',
              value: _entryTime,
              errorText: _errors['entryTime'],
              onChanged: (d) => setState(() => _entryTime = d),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _entry,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Entry price', errorText: _errors['entryPrice']),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stop,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Stop loss', errorText: _errors['stopLoss']),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Open trade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseTradeSheet extends StatefulWidget {
  const _CloseTradeSheet({required this.journal, required this.trade});

  final JournalController journal;
  final Trade trade;

  @override
  State<_CloseTradeSheet> createState() => _CloseTradeSheetState();
}

class _CloseTradeSheetState extends State<_CloseTradeSheet> {
  final TextEditingController _exit = TextEditingController();
  final TextEditingController _lesson = TextEditingController();
  DateTime _exitTime = DateTime.now();
  bool? _followed;
  String? _emotionAfter;
  final Map<String, String> _errors = {};
  String? _banner;
  bool _saving = false;

  @override
  void dispose() {
    _exit.dispose();
    _lesson.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final exit = _parse(_exit.text);
    if (exit == null || exit <= 0) {
      setState(() => _errors['exitPrice'] = 'Enter the exit price');
      return;
    }
    final lesson = _lesson.text.trim();
    final payload = <String, dynamic>{
      'status': 'closed',
      'exitTime': _exitTime.toUtc().toIso8601String(),
      'exitPrice': exit,
      if (_followed != null) 'followedRules': _followed,
      if (_emotionAfter != null) 'emotionAfter': _emotionAfter,
      if (lesson.isNotEmpty) 'lesson': lesson,
    };
    setState(() {
      _saving = true;
      _banner = null;
      _errors.clear();
    });
    final result = await widget.journal.update(widget.trade.id, payload);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _errors.addAll(result.fieldErrors);
        _banner = result.error ?? 'Please fix the highlighted fields.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trade;
    final preview = realizedR(t.direction, t.entryPrice, t.stopLoss, _parse(_exit.text));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Close trade', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_banner != null) InfoBanner(icon: Icons.error_outline, message: _banner!, isError: true),
            DateTimeField(
              label: 'Exit time',
              value: _exitTime,
              errorText: _errors['exitTime'],
              onChanged: (d) => setState(() => _exitTime = d),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _exit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Exit price', errorText: _errors['exitPrice']),
              onChanged: (_) => setState(() {}),
            ),
            if (preview != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Text('Result (preview): '),
                    RValue(preview, size: 16),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            TriField(label: 'Followed my rules', value: _followed, onChanged: (v) => setState(() => _followed = v)),
            const SizedBox(height: 14),
            ChoiceField(
              fieldKey: 'emotionAfter',
              label: 'Emotion after',
              options: emotions,
              value: _emotionAfter,
              onChanged: (v) => setState(() => _emotionAfter = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _lesson,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Lesson', errorText: _errors['lesson']),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Close trade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
