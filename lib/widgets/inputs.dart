import 'package:flutter/material.dart';

import '../core/format.dart';

Future<DateTime?> pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final base = (initial ?? now).toLocal();
  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 1, 12, 31),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Tap to pick a date and time, with a one-tap "now" button.
class DateTimeField extends StatelessWidget {
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged, this.errorText});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await pickDateTime(context, value);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: IconButton(
            tooltip: 'Use current time',
            icon: const Icon(Icons.schedule),
            onPressed: () => onChanged(DateTime.now()),
          ),
        ),
        child: Text(value == null ? 'Tap to set' : fmtDateTime(value)),
      ),
    );
  }
}

/// Yes / No / Not set. "Not set" leaves the field out of the request.
class TriField extends StatelessWidget {
  const TriField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, bool? v) => ChoiceChip(
          label: Text(text),
          selected: value == v,
          onSelected: (_) => onChanged(v),
        );
    return Row(
      children: [
        Expanded(child: Text(label)),
        Wrap(spacing: 6, children: [chip('Yes', true), chip('No', false), chip('Not set', null)]),
      ],
    );
  }
}

/// A row of numbered chips, e.g. mood 1 to 5.
class ScaleField extends StatelessWidget {
  const ScaleField({super.key, required this.label, required this.min, required this.max, required this.value, required this.onChanged});

  final String label;
  final int min;
  final int max;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (var i = min; i <= max; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: value == i,
                onSelected: (on) => onChanged(on ? i : null),
              ),
          ],
        ),
      ],
    );
  }
}

/// Dropdown over a fixed list, optionally with "Add new…".
class ChoiceField extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.onAddNew,
    this.errorText,
  });

  final String fieldKey;
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Future<void> Function(String value)? onAddNew;
  final String? errorText;

  static const _none = '__none__';
  static const _add = '__add__';

  Future<void> _promptNew(BuildContext context) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('New ${label.toLowerCase()}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(hintText: 'e.g. liquidity sweep'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Add')),
        ],
      ),
    );
    controller.dispose();
    final clean = text?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty) {
      await onAddNew!(clean);
      onChanged(clean);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = <String>{...options, if (value != null) value!}.toList();
    return DropdownButtonFormField<String>(
      value: value ?? _none,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: [
        const DropdownMenuItem(value: _none, child: Text('Not set')),
        for (final o in all) DropdownMenuItem(value: o, child: Text(labelFor(fieldKey, o))),
        if (onAddNew != null) const DropdownMenuItem(value: _add, child: Text('+ Add new…')),
      ],
      onChanged: (v) {
        if (v == _add) {
          _promptNew(context);
        } else {
          onChanged(v == _none ? null : v);
        }
      },
    );
  }
}

/// Chips plus a text box. Values are stored lowercase and trimmed.
class TagInput extends StatefulWidget {
  const TagInput({super.key, required this.label, required this.values, required this.onChanged, this.suggestions = const [], this.hint});

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final String? hint;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty || widget.values.contains(tag)) return;
    widget.onChanged([...widget.values, tag]);
    _controller.clear();
  }

  void _remove(String tag) => widget.onChanged(widget.values.where((v) => v != tag).toList());

  @override
  Widget build(BuildContext context) {
    final remaining = widget.suggestions.where((s) => !widget.values.contains(s)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 6),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final v in widget.values)
                InputChip(label: Text(v), onDeleted: () => _remove(v)),
            ],
          ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in remaining) ActionChip(label: Text(s), onPressed: () => _add(s)),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Add your own',
            suffixIcon: IconButton(
              tooltip: 'Add',
              icon: const Icon(Icons.add),
              onPressed: () => _add(_controller.text),
            ),
          ),
          onSubmitted: _add,
        ),
      ],
    );
  }
}
