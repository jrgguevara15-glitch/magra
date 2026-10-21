import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import 'food_catalog.dart';

/// Corregir un alimento ya registrado: nombre, cantidad (recalcula calorías
/// y macros en proporción) o los nutrientes directamente.
class EditFoodSheet extends ConsumerStatefulWidget {
  const EditFoodSheet({super.key, required this.entry});

  final FoodEntry entry;

  @override
  ConsumerState<EditFoodSheet> createState() => _EditFoodSheetState();
}

class _EditFoodSheetState extends ConsumerState<EditFoodSheet> {
  late final _name = TextEditingController(text: widget.entry.name);
  late final _qty = TextEditingController(text: _num(widget.entry.quantity));
  late final _kcal = TextEditingController(text: _num(widget.entry.kcal));
  late final _p = TextEditingController(text: _num(widget.entry.protein));
  late final _c = TextEditingController(text: _num(widget.entry.carbs));
  late final _f = TextEditingController(text: _num(widget.entry.fat));
  bool _busy = false;
  String? _error;

  static String _num(double? v) {
    if (v == null) return '';
    final r = (v * 10).round() / 10;
    return r % 1 == 0 ? r.round().toString() : r.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _kcal, _p, _c, _f]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Al cambiar la cantidad, los nutrientes siguen la misma proporción.
  void _rescale(String text) {
    final q0 = widget.entry.quantity;
    final q = parseNum(text);
    if (q0 == null || q0 <= 0 || q == null || q <= 0) return;
    final k = q / q0;
    final e = widget.entry;
    setState(() {
      _kcal.text = _num(e.kcal * k);
      _p.text = _num(e.protein * k);
      _c.text = _num(e.carbs * k);
      _f.text = _num(e.fat * k);
    });
  }

  Future<void> _save() async {
    final kcal = parseNum(_kcal.text);
    final qty = parseNum(_qty.text);
    if (_name.text.trim().isEmpty || kcal == null || kcal < 0 || kcal > 5000) {
      setState(() => _error = 'Escribe un nombre y las calorías (0–5.000).');
      return;
    }
    if (_qty.text.trim().isNotEmpty && (qty == null || qty <= 0 || qty > 3000)) {
      setState(() => _error = 'La cantidad va de 0 a 3.000.');
      return;
    }
    final e = widget.entry;
    final next = e.copyWith(
      name: _name.text.trim(),
      quantity: qty,
      kcal: kcal,
      protein: parseNum(_p.text) ?? 0,
      carbs: parseNum(_c.text) ?? 0,
      fat: parseNum(_f.text) ?? 0,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(foodLogRepositoryProvider).update(next);
      ref.invalidate(foodLogProvider(e.date));
      ref.invalidate(myFoodsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final hasQty = widget.entry.quantity != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editar alimento', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            if (hasQty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _qty,
                keyboardType: decimal,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  suffixText: widget.entry.unit,
                  helperText: 'Las calorías y los macros se ajustan solos',
                ),
                onChanged: _rescale,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _kcal,
              keyboardType: decimal,
              decoration: const InputDecoration(labelText: 'Calorías', suffixText: 'kcal'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (c, l) in [(_p, 'Proteína'), (_c, 'Carbos'), (_f, 'Grasas')]) ...[
                  Expanded(
                    child: TextField(
                      controller: c,
                      keyboardType: decimal,
                      decoration: InputDecoration(labelText: l, suffixText: 'g'),
                    ),
                  ),
                  if (c != _f) const SizedBox(width: 8),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
