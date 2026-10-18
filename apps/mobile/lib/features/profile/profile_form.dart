import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import 'user_profile.dart';

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Formulario de perfil. Sirve para completarlo la primera vez y para
/// editarlo. Llama a [onSaved] después de guardar.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.initial, this.onSaved});

  final UserProfile? initial;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _height = TextEditingController(
      text: widget.initial == null ? '' : fmt(widget.initial!.heightCm));
  late final _goalFat = TextEditingController(
      text: fmt(widget.initial?.goalFatPct ?? 17, 1));
  late final _protein = TextEditingController(
      text: fmt(widget.initial?.split.proteinPct ?? 30));
  late final _carb =
      TextEditingController(text: fmt(widget.initial?.split.carbPct ?? 45));
  late final _lipid =
      TextEditingController(text: fmt(widget.initial?.split.lipidPct ?? 25));
  late Sex _sex = widget.initial?.sex ?? Sex.male;
  late DateTime? _birth = widget.initial?.birthDate;
  late double _activity =
      widget.initial?.activityFactor ?? ActivityFactor.sedentary;
  late double _pace = widget.initial?.paceKgPerWeek ?? 0.5;
  late final Set<int> _lowCarb = {...(widget.initial?.lowCarbDays ?? const [2, 4])};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _height, _goalFat, _protein, _carb, _lipid]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 35, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 14),
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) {
      setState(() => _error = 'Elige tu fecha de nacimiento.');
      return;
    }
    final split = MacroSplit(
      proteinPct: parseNum(_protein.text)!,
      carbPct: parseNum(_carb.text)!,
      lipidPct: parseNum(_lipid.text)!,
    );
    if (!split.isValid) {
      setState(() => _error = 'Proteína + carbohidratos + lípidos deben sumar 100 %.');
      return;
    }
    final profile = UserProfile(
      name: _name.text.trim(),
      sex: _sex,
      birthDate: _birth!,
      heightCm: parseNum(_height.text)!,
      activityFactor: _activity,
      paceKgPerWeek: _pace,
      goalFatPct: parseNum(_goalFat.text)!,
      split: split,
      lowCarbDays: _lowCarb.toList()..sort(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).save(profile);
      ref.invalidate(profileProvider);
      widget.onSaved?.call();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _range(String? v, double min, double max, String what) {
    final n = parseNum(v ?? '');
    if (n == null || n < min || n > max) {
      return '$what entre ${fmt(min)} y ${fmt(max)}.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          gap,
          SegmentedButton<Sex>(
            segments: const [
              ButtonSegment(value: Sex.male, label: Text('Hombre')),
              ButtonSegment(value: Sex.female, label: Text('Mujer')),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          gap,
          OutlinedButton.icon(
            onPressed: _pickBirth,
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birth == null
                ? 'Fecha de nacimiento'
                : 'Nacimiento: ${fmtDate(_birth!)}'),
          ),
          gap,
          TextFormField(
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Estatura', suffixText: 'cm'),
            validator: (v) => _range(v, 120, 230, 'Estatura'),
          ),
          gap,
          DropdownButtonFormField<double>(
            isExpanded: true,
            initialValue: _activity,
            decoration: const InputDecoration(
                labelText: 'Actividad fuera del entrenamiento'),
            items: const [
              DropdownMenuItem(
                  value: ActivityFactor.sedentary,
                  child: Text('Sedentario (oficina) ×1,2')),
              DropdownMenuItem(
                  value: ActivityFactor.light,
                  child: Text('Ligero (de pie a ratos) ×1,375')),
              DropdownMenuItem(
                  value: ActivityFactor.active,
                  child: Text('Activo (trabajo físico) ×1,55')),
            ],
            onChanged: (v) => setState(() => _activity = v!),
          ),
          gap,
          DropdownButtonFormField<double>(
            isExpanded: true,
            initialValue: _pace,
            decoration: const InputDecoration(labelText: 'Ritmo de pérdida'),
            items: const [
              DropdownMenuItem(
                  value: 0.25, child: Text('0,25 kg/semana (−250 kcal)')),
              DropdownMenuItem(
                  value: 0.5, child: Text('0,5 kg/semana (−500 kcal)')),
              DropdownMenuItem(
                  value: 0.75, child: Text('0,75 kg/semana (−750 kcal)')),
            ],
            onChanged: (v) => setState(() => _pace = v!),
          ),
          gap,
          TextFormField(
            controller: _goalFat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Meta de grasa corporal', suffixText: '%'),
            validator: (v) => _range(v, 5, 45, 'Meta'),
          ),
          gap,
          Row(
            children: [
              for (final (c, label) in [
                (_protein, 'Proteína'),
                (_carb, 'Carbos'),
                (_lipid, 'Lípidos'),
              ]) ...[
                Expanded(
                  child: TextFormField(
                    controller: c,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: label, suffixText: '%'),
                    validator: (v) => _range(v, 5, 70, label),
                  ),
                ),
                if (c != _lipid) const SizedBox(width: 8),
              ],
            ],
          ),
          gap,
          Text('Días sin carbohidratos',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_weekdays[d - 1]),
                  selected: _lowCarb.contains(d),
                  onSelected: (on) => setState(
                      () => on ? _lowCarb.add(d) : _lowCarb.remove(d)),
                ),
            ],
          ),
          if (_error != null) ...[
            gap,
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Guardar perfil'),
            ),
          ),
        ],
      ),
    );
  }
}
