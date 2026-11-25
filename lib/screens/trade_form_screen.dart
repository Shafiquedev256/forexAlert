import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/options.dart';
import '../core/trade_math.dart';
import '../journal/field_specs.dart';
import '../journal/journal_controller.dart';
import '../journal/models/trade.dart';
import '../journal/trade_payload.dart';
import '../widgets/info_banner.dart';
import '../widgets/inputs.dart';
import '../widgets/ui.dart';

/// One form for create and edit. Sections appear according to the trade's
/// status, and edits send only the fields that changed.
class TradeFormScreen extends StatefulWidget {
  const TradeFormScreen({super.key, required this.journal, this.existing});

  final JournalController journal;
  final Trade? existing;

  @override
  State<TradeFormScreen> createState() => _TradeFormScreenState();
}

class _TradeFormScreenState extends State<TradeFormScreen> {
  static const _parseError = 'Enter a number';
  static const _basicKeys = {'status', 'pair', 'direction'};

  late final Map<String, dynamic> _initial;
  late final Map<String, dynamic> _values;
  final Map<String, String> _errors = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _banner;

  Trade? get _existing => widget.existing;
  String get _status => _values['status'] as String;

  @override
  void initState() {
    super.initState();
    _initial = _existing?.toFormValues() ?? <String, dynamic>{};
    _values = {..._initial};
    if (_existing == null) {
      _values['status'] = 'planned';
      _values['direction'] = 'long';
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- State helpers -----------------------------------------------------

  TextEditingController _controller(String key) => _controllers.putIfAbsent(key, () {
        final v = _values[key];
        return TextEditingController(text: v == null ? '' : v.toString());
      });

  /// Stores a value; empty values are removed so they are never sent.
  void _set(String key, dynamic value) {
    setState(() {
      final empty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
      if (empty) {
        _values.remove(key);
      } else {
        _values[key] = value;
      }
      _errors.remove(key);
    });
  }

  void _setNumber(FieldSpec spec, String text) {
    final t = text.trim().replaceAll(',', '.');
    setState(() {
      if (t.isEmpty) {
        _values.remove(spec.key);
        _errors.remove(spec.key);
        return;
      }
      final d = double.tryParse(t);
      if (d == null) {
        _values.remove(spec.key);
        _errors[spec.key] = _parseError;
      } else {
        _values[spec.key] = d;
        _errors.remove(spec.key);
      }
    });
  }

  static bool _same(dynamic a, dynamic b) {
    if (a is DateTime && b is DateTime) return a.isAtSameMomentAs(b);
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  // ---- Save --------------------------------------------------------------

  Future<void> _save() async {
    final existing = _existing;
    final visible = <String>{
      ..._basicKeys,
      ...tradeFields.where((s) => s.visibleFor(_status)).map((s) => s.key),
    };

    final errors = validateTrade(_values);
    for (final e in _errors.entries) {
      if (e.value == _parseError) errors[e.key] = e.value;
    }

    final List<String> keys;
    if (existing == null) {
      keys = visible.where(_values.containsKey).toList();
    } else {
      keys = [];
      for (final k in {..._initial.keys, ..._values.keys}) {
        if (!visible.contains(k) || _same(_initial[k], _values[k])) continue;
        if (_values[k] == null) {
          errors.putIfAbsent(k, () => "Saved values can't be cleared yet");
        } else {
          keys.add(k);
        }
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _banner = 'Please fix the highlighted fields.';
      });
      return;
    }
    if (existing != null && keys.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final payload = buildPayload(_values, keys);
    setState(() {
      _saving = true;
      _banner = null;
    });
    final result = existing == null
        ? await widget.journal.create(payload)
        : await widget.journal.update(existing.id, payload);
    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pop(result.trade);
      return;
    }

    final matched = <String, String>{};
    final other = <String>[];
    for (final e in result.fieldErrors.entries) {
      if (_basicKeys.contains(e.key) || specByKey.containsKey(e.key)) {
        matched[e.key] = e.value;
      } else {
        other.add(e.value);
      }
    }
    setState(() {
      _saving = false;
      _errors
        ..clear()
        ..addAll(matched);
      _banner = result.error ??
          (other.isNotEmpty ? other.join('\n') : 'Please fix the highlighted fields.');
    });
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEdit = _existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit trade' : 'Log trade')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(isEdit ? 'Save changes' : 'Save trade'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (_banner != null) InfoBanner(icon: Icons.error_outline, message: _banner!, isError: true),
          _basics(),
          _preview(),
          for (final section in FieldSection.values) _section(section),
        ],
      ),
    );
  }

  Widget _basics() {
    final pair = _controller('pair');
    return SectionCard(
      title: 'Basics',
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            for (final s in tradeStatuses) ButtonSegment(value: s, label: Text(titleCase(s))),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _values['status'] = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: pair,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: InputDecoration(labelText: 'Pair', errorText: _errors['pair']),
          onChanged: (t) => _set('pair', t.trim()),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in pairOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(p),
                    onPressed: () {
                      pair.text = p;
                      _set('pair', p);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'long', label: Text('Long')),
            ButtonSegment(value: 'short', label: Text('Short')),
          ],
          selected: {_values['direction'] as String? ?? 'long'},
          onSelectionChanged: (s) => setState(() => _values['direction'] = s.first),
        ),
        if (_errors['direction'] != null) _errorText(_errors['direction']!),
      ],
    );
  }

  Widget _preview() {
    final entry = _values['entryPrice'] as double?;
    final stop = _values['stopLoss'] as double?;
    final tp = _values['takeProfit'] as double?;
    final exit = _values['exitPrice'] as double?;
    final planned = plannedRR(entry, stop, tp);
    final r = _status == 'closed' ? realizedR(_values['direction'] as String?, entry, stop, exit) : null;
    if (planned == null && r == null) return const SizedBox.shrink();

    return SectionCard(
      title: 'Preview',
      children: [
        Row(
          children: [
            Expanded(child: _stat('Planned R:R', Text(fmtNum(planned), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))),
            if (_status == 'closed') Expanded(child: _stat('Result', RValue(r, size: 20))),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Calculated here as a preview. The server value is used after saving.',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _stat(String label, Widget value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          value,
        ],
      );

  Widget _errorText(String message) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(message, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
      );

  String _sectionTitle(FieldSection s) => switch (s) {
        FieldSection.plan => 'Plan',
        FieldSection.entry => 'Entry',
        FieldSection.exit => 'Exit',
        FieldSection.psychology => 'Psychology',
        FieldSection.review => 'Review',
      };

  Widget _section(FieldSection section) {
    final fields = tradeFields.where((s) => s.section == section && s.visibleFor(_status)).toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: _sectionTitle(section),
      children: [
        for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
      ],
    );
  }

  Widget _field(FieldSpec s) {
    final error = _errors[s.key];
    switch (s.kind) {
      case FieldKind.number:
      case FieldKind.integer:
        return TextField(
          controller: _controller(s.key),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: s.label, errorText: error),
          onChanged: (t) => _setNumber(s, t),
        );
      case FieldKind.text:
      case FieldKind.url:
      case FieldKind.longText:
        return TextField(
          controller: _controller(s.key),
          keyboardType: s.kind == FieldKind.url ? TextInputType.url : TextInputType.multiline,
          minLines: s.kind == FieldKind.longText ? 2 : 1,
          maxLines: s.kind == FieldKind.longText ? 4 : 1,
          decoration: InputDecoration(labelText: s.label, errorText: error),
          onChanged: (t) => _set(s.key, t),
        );
      case FieldKind.dateTime:
        return DateTimeField(
          label: s.label,
          value: _values[s.key] as DateTime?,
          errorText: error,
          onChanged: (d) => _set(s.key, d),
        );
      case FieldKind.tri:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TriField(label: s.label, value: _values[s.key] as bool?, onChanged: (v) => _set(s.key, v)),
            if (error != null) _errorText(error),
          ],
        );
      case FieldKind.choice:
        return ChoiceField(
          fieldKey: s.key,
          label: s.label,
          options: s.key == 'setup' ? widget.journal.setupOptions : s.options,
          value: _values[s.key] as String?,
          errorText: error,
          onChanged: (v) => _set(s.key, v),
          onAddNew: s.allowCustom
              ? (v) async {
                  await widget.journal.addSetup(v);
                }
              : null,
        );
      case FieldKind.scale:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScaleField(
              label: s.label,
              min: (s.min ?? 1).toInt(),
              max: (s.max ?? 5).toInt(),
              value: _values[s.key] as int?,
              onChanged: (v) => _set(s.key, v),
            ),
            if (error != null) _errorText(error),
          ],
        );
      case FieldKind.tags:
        return TagInput(
          label: s.label,
          values: (_values[s.key] as List?)?.cast<String>() ?? const [],
          suggestions: s.suggestions,
          hint: s.hint,
          onChanged: (l) => _set(s.key, l),
        );
    }
  }
}
