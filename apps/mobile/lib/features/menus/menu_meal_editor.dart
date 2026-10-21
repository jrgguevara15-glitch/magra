import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../questionnaire/questionnaire.dart';
import '../today/food_catalog.dart';
import 'weekly_menu.dart';

/// Editar una comida del menú: cantidades (los nutrientes siguen la
/// proporción), quitar ingredientes o agregar otros de la base. Devuelve la
/// comida editada al guardar.
class MenuMealEditor extends StatefulWidget {
  const MenuMealEditor({super.key, required this.meal, required this.questionnaire, this.targetKcal});

  final MenuMeal meal;
  final Questionnaire questionnaire;
  final double? targetKcal;

  @override
  State<MenuMealEditor> createState() => _MenuMealEditorState();
}

class _Row {
  _Row(this.base) : qty = TextEditingController(text: _num(base.quantity));

  final MenuItem base;
  final TextEditingController qty;

  static String _num(double v) => v % 1 == 0 ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

  /// El ingrediente con la cantidad escrita (nutrientes en proporción).
  MenuItem? get item {
    final q = parseNum(qty.text);
    if (q == null || q <= 0) return null;
    final k = base.quantity > 0 ? q / base.quantity : 1.0;
    return MenuItem(
      food: base.food,
      quantity: q,
      unit: base.unit,
      kcal: base.kcal * k,
      protein: base.protein * k,
      carbs: base.carbs * k,
      fat: base.fat * k,
      category: base.category,
      brand: base.brand,
    );
  }
}

class _MenuMealEditorState extends State<MenuMealEditor> {
  late final List<_Row> _rows = [for (final i in widget.meal.items) _Row(i)];
  final _search = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final r in _rows) {
      r.qty.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  void _addFood(CatalogFood f) {
    final grams = f.unitGrams ?? 100;
    final n = f.nutrientsFor(grams);
    setState(() {
      _rows.add(_Row(MenuItem(
        food: f.name,
        quantity: grams,
        unit: f.unit,
        kcal: n.kcal,
        protein: n.protein,
        carbs: n.carbs,
        fat: n.fat,
      )));
      _search.clear();
    });
  }

  void _save() {
    final items = <MenuItem>[];
    for (final r in _rows) {
      final i = r.item;
      if (i == null) {
        setState(() => _error = 'Revisa la cantidad de ${r.base.food}.');
        return;
      }
      items.add(i);
    }
    if (items.isEmpty) {
      setState(() => _error = 'Deja al menos un ingrediente.');
      return;
    }
    final m = widget.meal;
    Navigator.of(context).pop(MenuMeal(name: m.name, prep: m.prep, items: items, seasoning: m.seasoning));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [for (final r in _rows) r.item].whereType<MenuItem>();
    final kcal = items.fold<double>(0, (a, i) => a + i.kcal);
    final protein = items.fold<double>(0, (a, i) => a + i.protein);
    final results = _search.text.trim().isEmpty
        ? const <CatalogFood>[]
        : searchCatalog(widget.questionnaire, _search.text).take(6).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editar ${widget.meal.name}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.targetKcal == null
                  ? '${fmt(kcal)} kcal · proteína ${fmt(protein)} g'
                  : '${fmt(kcal)} / ${fmt(widget.targetKcal)} kcal · proteína ${fmt(protein)} g',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            for (final r in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(r.base.food)),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: r.qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Cantidad',
                          suffixText: r.base.unit == 'unidad' ? 'u' : r.base.unit,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar ${r.base.food}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _rows.remove(r)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.add),
                labelText: 'Agregar o reemplazar ingrediente',
                hintText: 'Ej: arroz, palta, pollo',
              ),
              onChanged: (_) => setState(() {}),
            ),
            for (final f in results)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f.name),
                subtitle: Text('${fmt(f.kcal)} kcal por 100 ${f.unit}'),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => _addFood(f),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Guardar comida'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
