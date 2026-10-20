import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/theme.dart';
import '../plan/plan_inputs.dart';
import '../questionnaire/questionnaire.dart';
import 'food_catalog.dart';
import 'photo_analysis.dart';

/// Pestaña Hoy: lo que comió el usuario contra su plan.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanGate(
      what: 'tu registro diario',
      builder: (context, inputs) => TodayView(inputs: inputs),
    );
  }
}

class TodayView extends ConsumerStatefulWidget {
  const TodayView({super.key, required this.inputs});

  final PlanInputs inputs;

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  late DateTime _day = DateUtils.dateOnly(widget.inputs.today);

  DateTime get _today => DateUtils.dateOnly(widget.inputs.today);

  String get _dayLabel {
    final diff = _today.difference(_day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return fmtDate(_day);
  }

  double _remainingKcal = 0;

  Future<void> _add(int mealIndex, String title, PlannedMeal? meal) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(
        title: title,
        day: _day,
        mealIndex: mealIndex,
        questionnaire: widget.inputs.questionnaire,
        mealProtein: meal?.protein ?? 25,
        mealCarbs: meal?.carbs ?? 30,
        mealFat: meal?.fat ?? 10,
        remainingKcal: _remainingKcal,
      ),
    );
  }

  Future<void> _delete(FoodEntry e) async {
    try {
      await ref.read(foodLogRepositoryProvider).delete(e.id!);
      ref.invalidate(foodLogProvider(_day));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Quitaste ${e.name}.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo quitar. Revisa tu conexión.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputs = widget.inputs;
    final plan = recommendNutrition(
      profile: inputs.profile,
      weightKg: inputs.weightKg,
      questionnaire: inputs.questionnaire,
      today: inputs.today,
    );
    final log = ref.watch(foodLogProvider(_day));
    final theme = Theme.of(context);

    return PlanScroll(children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                () => _day = _day.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: Text(_dayLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
          ),
          IconButton(
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: _day.isBefore(_today)
                ? () => setState(() => _day = _day.add(const Duration(days: 1)))
                : null,
          ),
        ],
      ),
      const SizedBox(height: 8),
      log.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(foodLogProvider(_day)),
            child: const Text('No se pudo cargar el día. Reintentar'),
          ),
        ),
        data: (entries) {
          _remainingKcal =
              plan.kcal - entries.fold<double>(0, (a, e) => a + e.kcal);
          return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DaySummary(plan: plan, entries: entries),
            const SizedBox(height: 8),
            for (var i = 0; i < plan.meals.length; i++)
              _MealLog(
                title: '${plan.meals[i].time.format(context)} · Comida ${i + 1}',
                targetKcal: plan.meals[i].kcal,
                entries: [for (final e in entries) if (e.mealIndex == i) e],
                onAdd: () => _add(i, 'Comida ${i + 1}', plan.meals[i]),
                onDelete: _delete,
              ),
            _MealLog(
              title: 'Fuera del plan',
              targetKcal: null,
              entries: [
                for (final e in entries)
                  if (e.mealIndex >= plan.meals.length) e,
              ],
              onAdd: () => _add(plan.meals.length, 'Fuera del plan', null),
              onDelete: _delete,
            ),
          ],
        );
        },
      ),
    ]);
  }
}

/// Calorías y macros del día contra el plan.
class DaySummary extends StatelessWidget {
  const DaySummary({super.key, required this.plan, required this.entries});

  final NutritionPlan plan;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = entries.fold<double>(0, (a, e) => a + e.kcal);
    final protein = entries.fold<double>(0, (a, e) => a + e.protein);
    final carbs = entries.fold<double>(0, (a, e) => a + e.carbs);
    final fat = entries.fold<double>(0, (a, e) => a + e.fat);
    final left = plan.kcal - kcal;
    final over = left < -plan.kcal * 0.05;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${fmt(kcal)} / ${fmt(plan.kcal)} kcal',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('consumidas', style: theme.textTheme.bodySmall),
                  ],
                ),
                Text(
                  left >= 0
                      ? 'Te quedan ${fmt(left)} kcal'
                      : 'Te pasaste ${fmt(-left)} kcal',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: over ? MagraColors.bad : MagraColors.good),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Bar(value: kcal / plan.kcal, color: over ? MagraColors.bad : null),
            const SizedBox(height: 12),
            _MacroRow('Proteína', protein, plan.protein, MagraColors.protein),
            _MacroRow('Carbohidratos', carbs, plan.carbs, MagraColors.carb),
            _MacroRow('Grasas', fat, plan.fat, MagraColors.lipid),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: 8,
        color: color,
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow(this.label, this.value, this.target, this.color);

  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('${fmt(value)} / ${fmt(target)} g'),
            ],
          ),
          const SizedBox(height: 2),
          _Bar(value: target <= 0 ? 0 : value / target, color: color),
        ],
      ),
    );
  }
}

class _MealLog extends StatelessWidget {
  const _MealLog({
    required this.title,
    required this.targetKcal,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
  });

  final String title;
  final double? targetKcal;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<FoodEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = entries.fold<double>(0, (a, e) => a + e.kcal);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                Text(
                  targetKcal == null
                      ? '${fmt(kcal)} kcal'
                      : '${fmt(kcal)} / ${fmt(targetKcal)} kcal',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
              ],
            ),
            for (final e in entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.name),
                subtitle: Text([
                  if (e.quantityLabel.isNotEmpty) e.quantityLabel,
                  '${fmt(e.kcal)} kcal',
                  'P ${fmt(e.protein)} · C ${fmt(e.carbs)} · G ${fmt(e.fat)}',
                ].join(' · ')),
                trailing: e.id == null
                    ? null
                    : IconButton(
                        tooltip: 'Quitar ${e.name}',
                        icon: const Icon(Icons.close),
                        onPressed: () => onDelete(e),
                      ),
              ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Agregar alimento'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddMode { catalog, photo, manual }

/// Hoja para agregar un alimento: del catálogo, por foto o a mano.
class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({
    super.key,
    required this.title,
    required this.day,
    required this.mealIndex,
    required this.questionnaire,
    required this.mealProtein,
    required this.mealCarbs,
    required this.mealFat,
    this.remainingKcal,
  });

  final String title;
  final DateTime day;
  final int mealIndex;
  final Questionnaire questionnaire;
  final double mealProtein;
  final double mealCarbs;
  final double mealFat;

  /// Calorías que le quedan hoy (contexto para la IA).
  final double? remainingKcal;

  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet> {
  _AddMode _mode = _AddMode.catalog;
  bool get _manual => _mode == _AddMode.manual;
  PhotoMode _photoMode = PhotoMode.plate;
  final _photoNote = TextEditingController();
  Uint8List? _photo;
  PhotoAnalysis? _analysis;
  bool _analyzing = false;
  final _query = TextEditingController();
  final _qty = TextEditingController();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _f = TextEditingController();
  CatalogFood? _food;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_query, _qty, _name, _kcal, _p, _c, _f, _photoNote]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pick(CatalogFood f) {
    final g = suggestedGrams(f,
        mealProtein: widget.mealProtein,
        mealCarbs: widget.mealCarbs,
        mealFat: widget.mealFat);
    setState(() {
      _food = f;
      // Sin separador de miles: el campo se vuelve a leer con parseNum.
      _qty.text = g.round().toString();
      _error = null;
    });
  }

  bool get _canUseCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _takePhoto({required bool camera}) async {
    final picked = await ref.read(imagePickProvider)(camera: camera);
    if (picked == null || !mounted) return;
    setState(() {
      _photo = picked.bytes;
      _analysis = null;
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await ref.read(photoAnalyzerProvider).analyze(
            bytes: picked.bytes,
            mediaType: mediaTypeFor(picked.name, picked.mimeType),
            mode: _photoMode,
            note: _photoNote.text,
            remainingKcal: widget.remainingKcal,
          );
      if (!mounted) return;
      setState(() {
        _analysis = result;
        if (result.items.isEmpty) {
          _error = result.notes.isNotEmpty
              ? result.notes
              : 'No reconocí comida en la foto. Prueba con otra.';
        }
      });
    } on PhotoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _savePhotoItems() async {
    final items = _analysis?.items.where((i) => i.include).toList() ?? const [];
    if (items.isEmpty) {
      setState(() => _error = 'Marca al menos un alimento.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(foodLogRepositoryProvider);
      for (final i in items) {
        await repo.add(FoodEntry(
          date: widget.day,
          mealIndex: widget.mealIndex,
          name: i.name,
          quantity: i.quantity > 0 ? i.quantity : null,
          unit: i.unit,
          kcal: i.kcal,
          protein: i.protein,
          carbs: i.carbs,
          fat: i.fat,
          source: 'photo',
        ));
      }
      ref.invalidate(foodLogProvider(widget.day));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_mode == _AddMode.photo) return _savePhotoItems();
    FoodEntry entry;
    if (_manual) {
      final kcal = parseNum(_kcal.text);
      if (_name.text.trim().isEmpty || kcal == null || kcal < 0 || kcal > 5000) {
        setState(() => _error = 'Escribe un nombre y las calorías (0–5.000).');
        return;
      }
      entry = FoodEntry(
        date: widget.day,
        mealIndex: widget.mealIndex,
        name: _name.text.trim(),
        kcal: kcal,
        protein: parseNum(_p.text) ?? 0,
        carbs: parseNum(_c.text) ?? 0,
        fat: parseNum(_f.text) ?? 0,
        source: 'manual',
      );
    } else {
      final qty = parseNum(_qty.text);
      if (_food == null || qty == null || qty <= 0 || qty > 3000) {
        setState(() => _error = 'Elige un alimento y una cantidad válida.');
        return;
      }
      entry = FoodEntry.fromCatalog(_food!, qty,
          date: widget.day, mealIndex: widget.mealIndex);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(foodLogRepositoryProvider).add(entry);
      ref.invalidate(foodLogProvider(widget.day));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _photoSection(ThemeData theme) {
    final analysis = _analysis;
    return [
      SegmentedButton<PhotoMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: PhotoMode.plate, label: Text('Mi plato')),
          ButtonSegment(value: PhotoMode.label, label: Text('Etiqueta')),
        ],
        selected: {_photoMode},
        onSelectionChanged: (s) => setState(() => _photoMode = s.first),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _photoNote,
        decoration: const InputDecoration(
          labelText: 'Aclaración (opcional)',
          hintText: 'Ej: el arroz era integral, la carne era cerdo',
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_canUseCamera)
            FilledButton.icon(
              onPressed: _analyzing ? null : () => _takePhoto(camera: true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar foto'),
            ),
          OutlinedButton.icon(
            onPressed: _analyzing ? null : () => _takePhoto(camera: false),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Elegir foto'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Tu foto se envía a la IA de Claude (Anthropic) solo para estimar las '
        'calorías. MAGRA no la guarda. Es una estimación: revísala antes de '
        'agregar.',
        style: theme.textTheme.bodySmall,
      ),
      if (_photo != null) ...[
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(_photo!, height: 160, fit: BoxFit.cover),
        ),
      ],
      if (_analyzing) ...[
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
        const SizedBox(height: 4),
        const Text('Analizando tu foto…'),
      ],
      if (analysis != null && analysis.items.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Esto vi (confianza ${analysis.confidence}). Corrige lo que haga falta:',
          style: theme.textTheme.titleSmall,
        ),
        for (final item in analysis.items) _PhotoItemRow(
          key: ObjectKey(item),
          item: item,
          onChanged: () => setState(() {}),
        ),
        Text(
          'Total: ${fmt(analysis.items.where((i) => i.include).fold<double>(0, (a, i) => a + i.kcal))} kcal',
          style: theme.textTheme.titleMedium,
        ),
        if (analysis.notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(analysis.notes, style: theme.textTheme.bodyMedium),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = searchCatalog(widget.questionnaire, _query.text);
    final qty = parseNum(_qty.text);
    final preview = _food != null && qty != null ? _food!.nutrientsFor(qty) : null;
    const decimal = TextInputType.numberWithOptions(decimal: true);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar a ${widget.title}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<_AddMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _AddMode.catalog, label: Text('Catálogo')),
                ButtonSegment(value: _AddMode.photo, label: Text('Foto')),
                ButtonSegment(value: _AddMode.manual, label: Text('A mano')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_mode == _AddMode.photo) ..._photoSection(theme),
            if (_mode == _AddMode.catalog && _food == null) ...[
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar alimento',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: results.isEmpty
                    ? const Center(child: Text('No encontré ese alimento. Agrégalo a mano.'))
                    : ListView(
                        children: [
                          for (final f in results)
                            ListTile(
                              dense: true,
                              title: Text(f.name),
                              subtitle: Text(
                                  '${fmt(f.kcal)} kcal por 100 ${f.unit}'),
                              onTap: () => _pick(f),
                            ),
                        ],
                      ),
              ),
            ],
            if (_mode == _AddMode.catalog && _food != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_food!.name, style: theme.textTheme.titleMedium),
                subtitle: _food!.unitGrams == null
                    ? null
                    : Text('1 ${_food!.unitName} ≈ ${fmt(_food!.unitGrams)} g'),
                trailing: TextButton(
                  onPressed: () => setState(() => _food = null),
                  child: const Text('Cambiar'),
                ),
              ),
              TextField(
                controller: _qty,
                keyboardType: decimal,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  suffixText: _food!.unit,
                  helperText: 'Sugerida para esta comida según tu plan',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (preview != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${fmt(preview.kcal)} kcal · P ${fmt(preview.protein)} g · '
                  'C ${fmt(preview.carbs)} g · G ${fmt(preview.fat)} g',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ],
            if (_manual) ...[
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Qué comiste'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _kcal,
                keyboardType: decimal,
                decoration: const InputDecoration(
                    labelText: 'Calorías', suffixText: 'kcal'),
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
              const SizedBox(height: 4),
              Text('Proteína, carbos y grasas son opcionales.',
                  style: theme.textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (_manual || (_mode == _AddMode.catalog && _food != null))
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Agregar'),
                ),
              ),
            if (_mode == _AddMode.photo && (_analysis?.items.isNotEmpty ?? false))
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Agregar ${_analysis!.items.where((i) => i.include).length} alimentos'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un alimento reconocido en la foto: incluir o no, nombre y cantidad.
class _PhotoItemRow extends StatefulWidget {
  const _PhotoItemRow({super.key, required this.item, required this.onChanged});

  final PhotoItem item;
  final VoidCallback onChanged;

  @override
  State<_PhotoItemRow> createState() => _PhotoItemRowState();
}

class _PhotoItemRowState extends State<_PhotoItemRow> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _qty =
      TextEditingController(text: widget.item.quantity.round().toString());

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: item.include,
            onChanged: (v) {
              item.include = v ?? false;
              widget.onChanged();
            },
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => item.name = v.trim().isEmpty ? item.name : v.trim(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(isDense: true, suffixText: item.unit == 'unidad' ? 'u' : item.unit),
              onChanged: (v) {
                final q = parseNum(v);
                if (q != null && q > 0) {
                  item.scaleTo(q);
                  widget.onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text('${fmt(item.kcal)} kcal', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
