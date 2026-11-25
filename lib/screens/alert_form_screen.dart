import 'package:flutter/material.dart';

import '../core/instruments.dart';
import '../models/price_alert.dart';
import '../services/price_service.dart';
import '../services/tone_store.dart';
import '../state/app_state.dart';

/// Create or edit an alert: pair, direction, target price, note and ringtone.
class AlertFormScreen extends StatefulWidget {
  const AlertFormScreen({super.key, required this.state, this.existing});

  final AppState state;
  final PriceAlert? existing;

  @override
  State<AlertFormScreen> createState() => _AlertFormScreenState();
}

class _AlertFormScreenState extends State<AlertFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Instrument _instrument;
  late AlertDirection _direction;
  late final TextEditingController _target;
  late final TextEditingController _note;
  String? _tonePath;

  double? _price;
  String? _priceError;
  bool _loadingPrice = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _instrument = instrumentFor(e?.symbol ?? instruments.first.symbol);
    _direction = e?.direction ?? AlertDirection.above;
    _target = TextEditingController(text: e == null ? '' : e.target.toString());
    _note = TextEditingController(text: e?.note ?? '');
    _tonePath = e?.ringtonePath;
    _loadPrice();
  }

  @override
  void dispose() {
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    setState(() {
      _loadingPrice = true;
      _priceError = null;
    });
    try {
      final price = await widget.state.fetchPrice(_instrument);
      if (!mounted) return;
      setState(() {
      _price = price;
    });
    } on PriceException catch (e) {
      if (!mounted) return;
      setState(() {
        _price = null;
        _priceError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _price = null;
        _priceError = 'Could not load the current price';
      });
    } finally {
      if (mounted) setState(() {
      _loadingPrice = false;
    });
    }
  }

  double? get _targetValue => double.tryParse(_target.text.trim().replaceAll(',', '.'));

  String? get _warning {
    final target = _targetValue;
    final price = _price;
    if (target == null || price == null) return null;
    if (_direction == AlertDirection.above && price >= target) {
      return 'The price is already at or above this target, so it would ring immediately.';
    }
    if (_direction == AlertDirection.below && price <= target) {
      return 'The price is already at or below this target, so it would ring immediately.';
    }
    return null;
  }

  Future<void> _chooseTone() async {
    final path = await widget.state.pickTone();
    if (path != null && mounted) setState(() {
      _tonePath = path;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = _targetValue!;
    final old = widget.existing;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = old == null ||
        old.symbol != _instrument.symbol ||
        old.target != target ||
        old.direction != _direction;

    await widget.state.saveAlert(PriceAlert(
      id: old?.id ?? PriceAlert.newId(),
      symbol: _instrument.symbol,
      target: target,
      direction: _direction,
      note: _note.text.trim(),
      enabled: old?.enabled ?? true,
      ringtonePath: _tonePath,
      armedAt: (changed || old == null) ? now : old.armedAt,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelLarge;
    final warning = _warning;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New alert' : 'Edit alert')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Pair', style: label),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _instrument.symbol,
              items: [
                for (final i in instruments)
                  DropdownMenuItem(value: i.symbol, child: Text('${i.symbol}  ·  ${i.name}')),
              ],
              onChanged: (symbol) {
                if (symbol == null) return;
                setState(() {
                  _instrument = instrumentFor(symbol);
                  _price = null;
                });
                _loadPrice();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.show_chart, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _loadingPrice
                        ? 'Loading price…'
                        : _price != null
                            ? 'Current: ${_instrument.format(_price!)}'
                            : (_priceError ?? 'Current price unavailable'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh price',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadingPrice ? null : _loadPrice,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Trigger', style: label),
            const SizedBox(height: 8),
            SegmentedButton<AlertDirection>(
              segments: [
                for (final d in AlertDirection.values) ButtonSegment(value: d, label: Text(d.short)),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 6),
            Text(_direction.hint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 16),
            Text('Target price', style: label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 2650.00'),
              onChanged: (_) => setState(() {}),
              validator: (_) {
                final v = _targetValue;
                return (v == null || v <= 0) ? 'Enter a valid price' : null;
              },
            ),
            if (warning != null) ...[
              const SizedBox(height: 6),
              Text(warning, style: TextStyle(color: scheme.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Text('Note', style: label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLength: 140,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Shown when the alert rings'),
            ),
            const SizedBox(height: 8),
            Text('Ringtone', style: label),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tonePath == null ? 'Use default tone' : ToneStore.displayName(_tonePath),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => widget.state.previewTone(_tonePath),
                  ),
                  TextButton(onPressed: _chooseTone, child: const Text('Choose')),
                  if (_tonePath != null)
                    IconButton(
                      tooltip: 'Use default',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _tonePath = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(onPressed: _save, child: const Text('Save alert')),
            ),
          ],
        ),
      ),
    );
  }
}
