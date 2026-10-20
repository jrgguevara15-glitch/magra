import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import 'questionnaire.dart';

/// Cuestionario en 4 pasos: rutina, entrenamiento, salud y alimentación.
class QuestionnairePage extends ConsumerStatefulWidget {
  const QuestionnairePage({super.key, this.initial});

  final Questionnaire? initial;

  @override
  ConsumerState<QuestionnairePage> createState() => _QuestionnairePageState();
}

const _stepTitles = [
  'Tu rutina',
  'Tu entrenamiento',
  'Tu salud',
  'Tu alimentación',
];

class _QuestionnairePageState extends ConsumerState<QuestionnairePage> {
  late Questionnaire _q = widget.initial ?? Questionnaire.initial;
  late final _healthNotes = TextEditingController(text: _q.healthNotes);
  late final _disliked = TextEditingController(text: _q.dislikedFoods);
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _healthNotes.dispose();
    _disliked.dispose();
    super.dispose();
  }

  void _set(Questionnaire q) => setState(() => _q = q);

  Future<void> _pickTime(bool wake) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: wake ? _q.wakeTime : _q.sleepTime,
      helpText: wake ? '¿A qué hora te levantas?' : '¿A qué hora te acuestas?',
    );
    if (picked == null) return;
    _set(wake ? _q.copyWith(wakeTime: picked) : _q.copyWith(sleepTime: picked));
  }

  Future<void> _save() async {
    final q = _q.copyWith(
      healthNotes: _healthNotes.text.trim(),
      dislikedFoods: _disliked.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(questionnaireRepositoryProvider).save(q);
      ref.invalidate(questionnaireProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _stepContent() {
    switch (_step) {
      case 0:
        return [
          const _Question('¿A qué hora te levantas y te acuestas?',
              'Con esto MAGRA reparte tus comidas en el día.'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(true),
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('Me levanto ${_q.wakeTime.format(context)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(false),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text('Me acuesto ${_q.sleepTime.format(context)}'),
                ),
              ),
            ],
          ),
          const _Question('¿Cómo es tu horario de trabajo o estudio?', null),
          _Single<WorkSchedule>(
            values: WorkSchedule.values,
            selected: _q.workSchedule,
            onChanged: (v) => _set(_q.copyWith(workSchedule: v)),
          ),
        ];
      case 1:
        return [
          _Question('¿Cuántos días a la semana puedes entrenar?',
              '${_q.trainingDays} ${_q.trainingDays == 1 ? 'día' : 'días'}'),
          Slider(
            value: _q.trainingDays.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            label: '${_q.trainingDays}',
            onChanged: (v) => _set(_q.copyWith(trainingDays: v.round())),
          ),
          const _Question('¿Cuánto tiempo tienes por sesión?', null),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in const [30, 45, 60, 75, 90, 120])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _q.sessionMinutes == m,
                  onSelected: (_) => _set(_q.copyWith(sessionMinutes: m)),
                ),
            ],
          ),
          const _Question('¿A qué hora sueles entrenar?', null),
          _Single<TrainingTime>(
            values: TrainingTime.values,
            selected: _q.trainingTime,
            onChanged: (v) => _set(_q.copyWith(trainingTime: v)),
          ),
          const _Question('¿Cuánta experiencia tienes con pesas?', null),
          _Single<Experience>(
            values: Experience.values,
            selected: _q.experience,
            onChanged: (v) => _set(_q.copyWith(experience: v)),
          ),
          const _Question('¿Dónde entrenas?', null),
          _Single<Equipment>(
            values: Equipment.values,
            selected: _q.equipment,
            onChanged: (v) => _set(_q.copyWith(equipment: v)),
          ),
          const _Question('¿Tienes dolor o lesión en alguna zona?',
              'Marca todas las que correspondan. Si ninguna, déjalo vacío.'),
          _Multi<Injury>(
            values: Injury.values,
            selected: _q.injuries,
            onChanged: (v) => _set(_q.copyWith(injuries: v)),
          ),
        ];
      case 2:
        return [
          const _Question('¿Tienes alguna de estas condiciones?',
              'Marca todas las que correspondan. Si ninguna, déjalo vacío.'),
          _Multi<HealthCondition>(
            values: HealthCondition.values,
            selected: _q.healthConditions,
            onChanged: (v) => _set(_q.copyWith(healthConditions: v)),
          ),
          if (_q.needsProfessionalSupervision) ...[
            const SizedBox(height: 12),
            const _Notice(
              'Con esta condición tu plan debe guiarlo un médico o '
              'nutricionista. MAGRA te ayudará a registrar y ordenar tu '
              'información, pero no te indicará un déficit por su cuenta.',
            ),
          ],
          const _Question('¿Algo más que debamos saber?',
              'Medicamentos, cirugías, indicaciones de tu médico…'),
          TextField(
            controller: _healthNotes,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ];
      default:
        return [
          const _Question('¿Cómo comes?', null),
          _Single<DietPattern>(
            values: DietPattern.values,
            selected: _q.dietPattern,
            onChanged: (v) => _set(_q.copyWith(dietPattern: v)),
          ),
          const _Question('¿Alergias o intolerancias?',
              'Si ninguna, déjalo vacío.'),
          _Multi<Allergy>(
            values: Allergy.values,
            selected: _q.allergies,
            onChanged: (v) => _set(_q.copyWith(allergies: v)),
          ),
          const _Question('¿Qué alimentos no te gustan?', null),
          TextField(
            controller: _disliked,
            maxLength: 500,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ej: pescado, brócoli, palta',
            ),
          ),
          const _Question('¿Cuántas veces al día te acomoda comer?',
              'Si no sabes, MAGRA lo decide según tus datos.'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Que MAGRA decida'),
                selected: _q.preferredMeals == null,
                onSelected: (_) => _set(_q.copyWith(preferredMeals: () => null)),
              ),
              for (var n = 2; n <= 6; n++)
                ChoiceChip(
                  label: Text('$n'),
                  selected: _q.preferredMeals == n,
                  onSelected: (_) => _set(_q.copyWith(preferredMeals: () => n)),
                ),
            ],
          ),
          const _Question('¿Ayuno intermitente?', null),
          _Single<Fasting>(
            values: Fasting.values,
            selected: _q.fasting,
            onChanged: (v) => _set(_q.copyWith(fasting: v)),
          ),
          const _Question('¿Cuánto cocinas?', null),
          _Single<Cooking>(
            values: Cooking.values,
            selected: _q.cooking,
            onChanged: (v) => _set(_q.copyWith(cooking: v)),
          ),
          const _Question('¿Presupuesto para la comida?', null),
          _Single<Budget>(
            values: Budget.values,
            selected: _q.budget,
            onChanged: (v) => _set(_q.copyWith(budget: v)),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _stepTitles.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Paso ${_step + 1} de ${_stepTitles.length} · ${_stepTitles[_step]}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _stepTitles.length),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: ValueKey(_step),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ..._stepContent(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_step > 0) ...[
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _step--),
                  child: const Text('Atrás'),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : last
                          ? _save
                          : () => setState(() => _step++),
                  child: Text(
                    last ? 'Guardar respuestas' : 'Siguiente',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question(this.title, this.hint);

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Single<T extends Choice> extends StatelessWidget {
  const _Single({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(v.label),
            selected: v == selected,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}

class _Multi<T extends Choice> extends StatelessWidget {
  const _Multi({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final List<T> selected;
  final ValueChanged<List<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(v.label),
            selected: selected.contains(v),
            onSelected: (on) => onChanged(on
                ? [...selected, v]
                : [for (final s in selected) if (s != v) s]),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined,
              color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
