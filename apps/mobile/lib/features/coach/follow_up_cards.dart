import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/platform/device.dart';
import '../../core/recommendation/follow_up.dart';
import '../../core/theme.dart';

/// La hora actual, renovada cada minuto mientras MAGRA está abierta (los
/// avisos aparecen solos al pasar la hora). Las pruebas lo fijan.
final followUpTickProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock());
});

/// Qué avisos quiere la persona y si acepta notificaciones del navegador.
class FollowUpSettings {
  const FollowUpSettings({required this.enabled, required this.browser});

  final Set<NudgeKind> enabled;
  final bool browser;
}

class FollowUpSettingsNotifier extends Notifier<FollowUpSettings> {
  static const _kEnabled = 'magra.followup.enabled';
  static const _kBrowser = 'magra.followup.browser';

  LocalPrefs get _prefs => ref.read(localPrefsProvider);

  @override
  FollowUpSettings build() {
    final raw = _prefs.read(_kEnabled);
    return FollowUpSettings(
      enabled: raw == null
          ? {...NudgeKind.values}
          : {for (final k in NudgeKind.values) if (raw.split(',').contains(k.name)) k},
      browser: _prefs.read(_kBrowser) == '1',
    );
  }

  void toggle(NudgeKind kind, bool on) {
    final next = {...state.enabled};
    on ? next.add(kind) : next.remove(kind);
    _prefs.write(_kEnabled, next.map((k) => k.name).join(','));
    state = FollowUpSettings(enabled: next, browser: state.browser);
  }

  void setBrowser(bool on) {
    _prefs.write(_kBrowser, on ? '1' : '0');
    state = FollowUpSettings(enabled: state.enabled, browser: on);
  }
}

final followUpSettingsProvider =
    NotifierProvider<FollowUpSettingsNotifier, FollowUpSettings>(FollowUpSettingsNotifier.new);

/// Ids de avisos (con fecha) ya descartados o ya notificados, guardados en
/// el dispositivo. Solo se conservan los de hoy.
class _IdSet extends Notifier<Set<String>> {
  _IdSet(this.key);

  final String key;

  @override
  Set<String> build() {
    final today = isoDate(ref.read(clockProvider)());
    final raw = ref.read(localPrefsProvider).read(key) ?? '';
    return {for (final id in raw.split('|')) if (id.endsWith(today)) id};
  }

  void add(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
    ref.read(localPrefsProvider).write(key, state.join('|'));
  }
}

final dismissedNudgesProvider = NotifierProvider<_IdSet, Set<String>>(() => _IdSet('magra.followup.dismissed'));
final notifiedNudgesProvider = NotifierProvider<_IdSet, Set<String>>(() => _IdSet('magra.followup.notified'));

/// Avisos del coach arriba de Hoy, con su acción y para descartarlos.
class FollowUpCards extends ConsumerStatefulWidget {
  const FollowUpCards({super.key, required this.nudges, required this.onAction});

  final List<Nudge> nudges;
  final void Function(Nudge nudge) onAction;

  @override
  ConsumerState<FollowUpCards> createState() => _FollowUpCardsState();
}

class _FollowUpCardsState extends ConsumerState<FollowUpCards> {
  bool _all = false;

  void _notify(List<Nudge> visible) {
    final settings = ref.read(followUpSettingsProvider);
    if (!settings.browser) return;
    final alerts = ref.read(systemAlertsProvider);
    if (alerts.permission != 'granted') return;
    final notified = ref.read(notifiedNudgesProvider);
    for (final n in visible) {
      if (notified.contains(n.id)) continue;
      alerts.show(n.title, n.message);
      ref.read(notifiedNudgesProvider.notifier).add(n.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dismissed = ref.watch(dismissedNudgesProvider);
    final pending = [for (final n in widget.nudges) if (!dismissed.contains(n.id)) n];
    final visible = _all ? pending : pending.take(1).toList();
    if (pending.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notify(pending);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in visible)
          Card(
            color: MagraColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.sports_gymnastics, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(n.message, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonal(
                            onPressed: () => widget.onAction(n),
                            child: Text(n.action),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Descartar aviso',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref.read(dismissedNudgesProvider.notifier).add(n.id),
                  ),
                ],
              ),
            ),
          ),
        if (pending.length > 1 && !_all)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _all = true),
              child: Text('${pending.length - 1} ${pending.length == 2 ? 'aviso más' : 'avisos más'}'),
            ),
          ),
      ],
    );
  }
}

Future<void> showFollowUpSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FollowUpSettingsSheet(),
    );

/// Elegir qué avisos dar y activar las notificaciones del navegador.
class FollowUpSettingsSheet extends ConsumerStatefulWidget {
  const FollowUpSettingsSheet({super.key});

  @override
  ConsumerState<FollowUpSettingsSheet> createState() => _FollowUpSettingsSheetState();
}

class _FollowUpSettingsSheetState extends ConsumerState<FollowUpSettingsSheet> {
  String? _note;

  Future<void> _enableBrowser(bool on) async {
    final notifier = ref.read(followUpSettingsProvider.notifier);
    if (!on) {
      notifier.setBrowser(false);
      return;
    }
    final result = await ref.read(systemAlertsProvider).request();
    if (!mounted) return;
    if (result == 'granted') {
      notifier.setBrowser(true);
      setState(() => _note = null);
    } else {
      setState(() => _note = result == 'unsupported'
          ? 'Este navegador no permite notificaciones. En iPhone: agrega MAGRA a la pantalla '
              'de inicio (Compartir → Agregar a inicio) y ábrela desde ahí.'
          : 'El navegador bloqueó las notificaciones. Actívalas en los ajustes del sitio '
              '(candado junto a la dirección) y vuelve a intentar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ref.watch(followUpSettingsProvider);
    final permission = ref.watch(systemAlertsProvider).permission;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Avisos del coach', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'El coach te acompaña durante el día: te recuerda entrenar a tu hora, '
              'anotar tus comidas y cerrar el día con tu proteína y tus pasos. '
              'Nunca avisa cerca de tu hora de dormir.',
              style: theme.textTheme.bodySmall,
            ),
            for (final k in NudgeKind.values)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(k.label),
                subtitle: Text(_describe(k), style: theme.textTheme.bodySmall),
                value: s.enabled.contains(k),
                onChanged: (v) => ref.read(followUpSettingsProvider.notifier).toggle(k, v),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificaciones del navegador'),
              subtitle: Text(
                permission == 'unsupported'
                    ? 'Este dispositivo no las permite en el navegador.'
                    : 'Te llegan aunque estés en otra pestaña, con MAGRA abierta. Con la '
                        'app instalada llegarán aunque esté cerrada.',
                style: theme.textTheme.bodySmall,
              ),
              value: s.browser && permission == 'granted',
              onChanged: _enableBrowser,
            ),
            if (_note != null) Text(_note!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }

  static String _describe(NudgeKind k) => switch (k) {
        NudgeKind.training => 'Si pasó tu hora de entrenar y aún no empiezas.',
        NudgeKind.meal => 'Si pasó la hora de una comida y no la anotaste.',
        NudgeKind.protein => 'Al final del día, si te falta proteína.',
        NudgeKind.steps => 'Al final del día, si vas lejos de tu meta de pasos.',
        NudgeKind.weighIn => 'Los lunes (o si llevas una semana sin pesarte).',
        NudgeKind.comeback => 'Si llevas 2 días o más sin anotar.',
      };
}
