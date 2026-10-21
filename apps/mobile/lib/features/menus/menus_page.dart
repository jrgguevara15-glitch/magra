import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/weekly_adjustment.dart';
import '../../core/theme.dart';
import '../plan/plan_inputs.dart';
import '../today/food_catalog.dart';
import 'weekly_menu.dart';

/// Pestaña Menús: menú de la semana con la IA y lista de compras.
class MenusPage extends StatelessWidget {
  const MenusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanGate(
      what: 'tu menú semanal',
      builder: (context, inputs) => MenusView(inputs: inputs),
    );
  }
}

const _dayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class MenusView extends ConsumerStatefulWidget {
  const MenusView({super.key, required this.inputs});

  final PlanInputs inputs;

  @override
  ConsumerState<MenusView> createState() => _MenusViewState();
}

class _MenusViewState extends ConsumerState<MenusView> {
  bool _shopping = false;
  int? _day;
  bool _generating = false;
  String? _swapping;
  String? _error;

  /// Menú que la IA ya armó pero no se pudo guardar: se reintenta sin
  /// volver a pagar la generación.
  WeeklyMenu? _pending;

  DateTime get _today => DateTime(widget.inputs.today.year,
      widget.inputs.today.month, widget.inputs.today.day);

  Future<void> _generate(NutritionPlan plan, DateTime week) async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final slots = [for (final m in plan.meals) MenuSlot.fromPlanned(m)];
      final days = await ref.read(menuGeneratorProvider).week(
            slots: slots,
            prefs: menuPrefs(widget.inputs.questionnaire),
          );
      _pending = WeeklyMenu(weekStart: week, slots: slots, days: days);
      await _savePending();
    } on MenuException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'La IA respondió algo inesperado. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _savePending() async {
    final menu = _pending;
    if (menu == null) return;
    try {
      await ref.read(menuRepositoryProvider).save(menu);
      _pending = null;
      if (mounted) setState(() => _error = null);
      ref.invalidate(menuProvider(menu.weekStart));
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _error = 'El menú quedó listo pero no se pudo guardar '
            '(${e.code ?? 'error'}: ${e.message}). ¿Ejecutaste la migración '
            '0008 en Supabase?');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'El menú quedó listo pero no se pudo guardar. Revisa tu conexión.');
      }
    }
  }

  Future<void> _regenerate(NutritionPlan plan, DateTime week) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nuevo menú'),
        content: const Text('Se reemplaza el menú de esta semana y su lista de '
            'compras. ¿Seguir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Generar')),
        ],
      ),
    );
    if (ok == true) await _generate(plan, week);
  }

  Future<void> _swap(WeeklyMenu menu, int day, int meal) async {
    setState(() {
      _swapping = '$day-$meal';
      _error = null;
    });
    try {
      final next = await ref.read(menuGeneratorProvider).meal(
            slots: menu.slots,
            prefs: menuPrefs(widget.inputs.questionnaire),
            day: day,
            meal: meal,
            avoid: {
              for (final d in menu.days)
                for (final m in d) m.name,
            }.toList(),
          );
      final days = [for (final d in menu.days) [...d]];
      days[day][meal] = next;
      await ref.read(menuRepositoryProvider).save(menu.copyWith(days: days));
      ref.invalidate(menuProvider(menu.weekStart));
    } on MenuException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _swapping = null);
    }
  }

  Future<void> _ate(WeeklyMenu menu, int day, int meal) async {
    final date = menu.dateOf(day);
    final m = menu.days[day][meal];
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(foodLogRepositoryProvider);
      for (final i in m.items) {
        await repo.add(FoodEntry(
          date: date,
          mealIndex: meal,
          name: i.food,
          quantity: i.quantity > 0 ? i.quantity : null,
          unit: i.unit,
          kcal: i.kcal,
          protein: i.protein,
          carbs: i.carbs,
          fat: i.fat,
          source: 'menu',
        ));
      }
      ref.invalidate(foodLogProvider(date));
      ref.invalidate(recentIntakeProvider);
      messenger.showSnackBar(SnackBar(
          content: Text('Registraste "${m.name}" en ${date == _today ? 'Hoy' : fmtDate(date)}.')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo registrar. Revisa tu conexión.')));
    }
  }

  Future<void> _toggle(WeeklyMenu menu, String key, bool on) async {
    final checked = {...menu.checked};
    on ? checked.add(key) : checked.remove(key);
    try {
      await ref.read(menuRepositoryProvider).save(menu.copyWith(checked: checked));
      ref.invalidate(menuProvider(menu.weekStart));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = widget.inputs.nutrition;
    final today = _today;
    final week = weekStartOf(today);
    final async = ref.watch(menuProvider(week));

    return PlanScroll(children: [
      Text('Menú de la semana', style: theme.textTheme.headlineSmall),
      Text('Semana del ${fmtDate(week)}', style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      if (_error != null) ...[
        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
      ],
      if (_pending != null && !_generating) ...[
        FilledButton.tonalIcon(
          onPressed: _savePending,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Reintentar guardar (sin volver a generar)'),
        ),
        const SizedBox(height: 8),
      ],
      async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(menuProvider(week)),
            child: const Text('No se pudo cargar el menú. Reintentar'),
          ),
        ),
        data: (menu) => menu == null
            ? _empty(theme, plan, week)
            : _menu(theme, plan, menu, today),
      ),
    ]);
  }

  Widget _generatingCard(ThemeData theme) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 8),
              Text('Armando tu menú de 7 días… puede tardar hasta un minuto.'),
            ],
          ),
        ),
      );

  Widget _empty(ThemeData theme, NutritionPlan plan, DateTime week) {
    if (_generating) return _generatingCard(theme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aún no tienes menú esta semana', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'MAGRA fija las ${plan.meals.length} comidas de tu plan con sus '
              'calorías y macros (${fmt(plan.kcal)} kcal al día) y la IA de '
              'Claude elige platos chilenos que calcen, según tu dieta, '
              'alergias, gustos, presupuesto y cuánto cocinas. Incluye la '
              'lista de compras.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _generate(plan, week),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Generar menú de la semana'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(ThemeData theme, NutritionPlan plan, WeeklyMenu menu, DateTime today) {
    final todayIndex = today.difference(menu.weekStart).inHours ~/ 24;
    final day = (_day ?? todayIndex).clamp(0, 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_generating) ...[
          _generatingCard(theme),
          const SizedBox(height: 8),
        ],
        if (menu.outdatedFor(plan))
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: MagraColors.warning),
              title: const Text('Tu plan cambió'),
              subtitle: const Text('Este menú se armó con otras metas. Genera '
                  'uno nuevo para que calce con tu plan actual.'),
              trailing: TextButton(
                onPressed: _generating ? null : () => _regenerate(plan, menu.weekStart),
                child: const Text('Generar'),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Menú'), icon: Icon(Icons.restaurant)),
                  ButtonSegment(value: true, label: Text('Compras'), icon: Icon(Icons.shopping_cart_outlined)),
                ],
                selected: {_shopping},
                onSelectionChanged: (s) => setState(() => _shopping = s.first),
              ),
            ),
            IconButton(
              tooltip: 'Nuevo menú',
              onPressed: _generating ? null : () => _regenerate(plan, menu.weekStart),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_shopping) _shoppingList(theme, menu) else ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var d = 0; d < 7; d++)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text('${_dayShort[d]} ${menu.dateOf(d).day}'),
                  selected: d == day,
                  onSelected: (_) => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total del día: ${fmt(menu.days[day].fold<double>(0, (a, m) => a + m.kcal))} '
            'kcal · meta ${fmt(menu.slots.fold<double>(0, (a, s) => a + s.kcal))}',
            style: theme.textTheme.bodySmall,
          ),
          for (var i = 0; i < menu.days[day].length; i++)
            _mealCard(theme, menu, day, i, today),
        ],
      ],
    );
  }

  Widget _mealCard(ThemeData theme, WeeklyMenu menu, int day, int i, DateTime today) {
    final meal = menu.days[day][i];
    final slot = i < menu.slots.length ? menu.slots[i] : null;
    final swapping = _swapping == '$day-$i';
    final future = menu.dateOf(day).isAfter(today);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${slot?.time ?? ''} · Comida ${i + 1}'
                    '${slot?.role == 'pre' ? ' · antes de entrenar' : slot?.role == 'post' ? ' · después de entrenar' : ''}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  slot == null
                      ? '${fmt(meal.kcal)} kcal'
                      : '${fmt(meal.kcal)} / ${fmt(slot.kcal)} kcal',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(meal.name, style: theme.textTheme.titleMedium),
            if (meal.prep.isNotEmpty)
              Text(meal.prep, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            for (final item in meal.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${item.quantityLabel} ${item.food} · ${fmt(item.kcal)} kcal'),
              ),
            Text('Proteína ${fmt(meal.protein)} g', style: theme.textTheme.bodySmall),
            if (meal.seasoning.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Sazón saludable', style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              for (final s in meal.seasoning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.eco_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: s.item,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (s.amount.isNotEmpty) TextSpan(text: ' · ${s.amount}'),
                          if (s.tip.isNotEmpty)
                            TextSpan(text: ' — ${s.tip}', style: theme.textTheme.bodySmall),
                        ])),
                      ),
                    ],
                  ),
                ),
            ],
            if (swapping) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: future || swapping ? null : () => _ate(menu, day, i),
                  icon: const Icon(Icons.check),
                  label: const Text('Lo comí'),
                ),
                TextButton.icon(
                  onPressed: _swapping != null || _generating ? null : () => _swap(menu, day, i),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Cambiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shoppingList(ThemeData theme, WeeklyMenu menu) {
    final items = shoppingList(menu);
    final done = items.where((i) => menu.checked.contains(i.key)).length;
    String? category;
    final children = <Widget>[];
    for (final item in items) {
      if (item.category != category) {
        category = item.category;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(category, style: theme.textTheme.titleSmall),
        ));
      }
      final on = menu.checked.contains(item.key);
      children.add(CheckboxListTile(
        dense: true,
        value: on,
        onChanged: (v) => _toggle(menu, item.key, v ?? false),
        title: Text(
          item.food,
          style: on ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text([
          item.quantityLabel,
          if (item.brand.isNotEmpty) 'ej. ${item.brand}',
        ].join(' · ')),
      ));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$done de ${items.length} listos · cantidades en crudo para '
                'los 7 días',
                style: theme.textTheme.bodySmall,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
