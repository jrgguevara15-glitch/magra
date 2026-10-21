import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/recommendation/exercise_alternatives.dart';
import '../../core/recommendation/progression.dart';
import '../../core/recommendation/training_plan.dart';
import '../../core/widgets/hero_card.dart';
import '../plan/plan_inputs.dart';
import '../progress/measurement.dart';
import '../today/activity_log.dart';
import '../today/food_catalog.dart';
import 'coach.dart';

/// Pestaña Coach: chat con la IA que conoce los datos de la persona.
class CoachPage extends StatelessWidget {
  const CoachPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanGate(
      what: 'tu coach',
      builder: (context, inputs) => CoachView(inputs: inputs),
    );
  }
}

class CoachView extends ConsumerStatefulWidget {
  const CoachView({super.key, required this.inputs});

  final PlanInputs inputs;

  @override
  ConsumerState<CoachView> createState() => _CoachViewState();
}

class _CoachViewState extends ConsumerState<CoachView> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _accepted = false;
  bool _waiting = false;
  String? _error;

  /// Modo de la última pregunta sin respuesta (para reintentar).
  String? _retryMode;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _context() async {
    final inputs = widget.inputs;
    final today = DateUtils.dateOnly(inputs.today);
    Future<T> safe<T>(Future<T> f, T fallback) async {
      try {
        return await f;
      } catch (_) {
        return fallback;
      }
    }

    final measurements = await safe(ref.read(measurementsProvider.future), const <Measurement>[]);
    final food = await safe(ref.read(foodLogProvider(today).future), const <FoodEntry>[]);
    final exercise = await safe(ref.read(exerciseLogProvider(today).future), const <ExerciseEntry>[]);
    final intake = await safe(ref.read(recentIntakeProvider.future), const <DateTime, double>{});
    final workouts = await safe(ref.read(workoutsProvider.future), const <WorkoutSession>[]);
    final swaps = await safe(ref.read(exerciseSwapsProvider.future), const <String, String>{});
    final training = applySwaps(
      recommendTraining(
        questionnaire: inputs.questionnaire,
        composition: inputs.composition,
        age: inputs.age,
      ),
      swaps,
    );
    return coachContext(
      inputs: inputs,
      plan: inputs.nutrition,
      measurements: measurements,
      todayFood: food,
      todayExercise: exercise,
      recentIntake: intake,
      workouts: workouts,
      nextWorkout: nextSession(training, workouts).title,
    );
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String mode, {String? text}) async {
    final repo = ref.read(coachRepositoryProvider);
    setState(() {
      _waiting = true;
      _error = null;
      _retryMode = null;
    });
    try {
      if (text != null) {
        await repo.add(CoachMessage(role: 'user', content: text, kind: mode));
        ref.invalidate(coachMessagesProvider);
        _text.clear();
      }
      final history = await ref.read(coachMessagesProvider.future);
      _toBottom();
      final reply = await ref.read(coachClientProvider).ask(
            mode: mode,
            history: [for (final m in history) if (m.kind == 'chat' || m.role == 'assistant') m],
            context: await _context(),
          );
      await repo.add(CoachMessage(role: 'assistant', content: reply, kind: mode));
      ref.invalidate(coachMessagesProvider);
      _toBottom();
    } on CoachException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _retryMode = mode;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty || _waiting) return;
    if (text.length > 2000) {
      setState(() => _error = 'Máximo 2.000 caracteres por mensaje.');
      return;
    }
    _send('chat', text: text);
  }

  Future<void> _setConsent(bool accepted) async {
    try {
      await ref.read(coachRepositoryProvider).setConsent(accepted);
      ref.invalidate(coachConsentProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
      }
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Borrar conversación'),
        content: const Text('Se borran todos los mensajes con el coach.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(coachRepositoryProvider).clear();
      ref.invalidate(coachMessagesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo borrar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(coachConsentProvider);
    return consent.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: OutlinedButton(
          onPressed: () => ref.invalidate(coachConsentProvider),
          child: const Text('No se pudo cargar el coach. Reintentar'),
        ),
      ),
      data: (ok) => ok ? _chat(context) : _consent(context),
    );
  }

  Widget _consent(BuildContext context) {
    final theme = Theme.of(context);
    return PlanScroll(children: [
      Text('Tu coach MAGRA', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Pregúntale lo que quieras sobre tu alimentación, tu entreno o tu '
          'progreso. Responde con tus datos reales, como un nutricionista '
          'deportivo y entrenador personal, y cada semana te hace una revisión.'),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qué se comparte', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text('Para responderte, MAGRA envía a la IA de Claude '
                  '(Anthropic) un resumen sin tu nombre ni correo: sexo, edad, '
                  'estatura, medidas, tu plan, lo registrado hoy y en la última '
                  'semana, tus entrenos y tus respuestas del cuestionario '
                  '(incluidas condiciones de salud), junto con tus mensajes.'),
              const SizedBox(height: 6),
              const Text('La conversación queda guardada en tu cuenta y puedes '
                  'borrarla o dejar de compartir cuando quieras. Tus fotos de '
                  'progreso nunca se envían.'),
              const SizedBox(height: 6),
              Text('El coach orienta; no reemplaza a un médico ni a un '
                  'nutricionista.', style: theme.textTheme.bodySmall),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: const Text('Acepto compartir estos datos con la IA para usar el coach'),
              ),
              FilledButton(
                onPressed: _accepted ? () => _setConsent(true) : null,
                child: const Text('Activar coach'),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _chat(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(coachMessagesProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final due = reviewDue(messages, now);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Coach', style: theme.textTheme.headlineSmall)),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones del coach',
                    onSelected: (v) => v == 'clear' ? _clear() : _setConsent(false),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'clear', child: Text('Borrar conversación')),
                      PopupMenuItem(value: 'revoke', child: Text('Dejar de compartir mis datos')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HeroCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_note_outlined,
                      color: due ? theme.colorScheme.primary : null),
                  title: Text(due ? 'Tu revisión semanal está lista' : 'Revisión semanal'),
                  subtitle: const Text('Resumen, logros, qué mejorar y foco de la semana.'),
                  trailing: TextButton(
                    onPressed: _waiting ? null : () => _send('review'),
                    child: const Text('Hacer'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Prueba con alguna de estas preguntas:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in coachSuggestions)
                              ActionChip(
                                label: Text(s),
                                onPressed: _waiting ? null : () => _send('chat', text: s),
                              ),
                          ],
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _Bubble(message: messages[i]),
                    ),
            ),
            if (_waiting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('El coach está pensando…'),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                    if (_retryMode != null)
                      TextButton(
                        onPressed: _waiting ? null : () => _send(_retryMode!),
                        child: const Text('Reintentar'),
                      ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Escríbele a tu coach…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Enviar',
                      onPressed: _waiting ? null : _submit,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && message.kind == 'review')
                Text('Revisión semanal', style: theme.textTheme.labelLarge),
              SelectableText(message.content),
            ],
          ),
        ),
      ),
    );
  }
}
