import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/theme.dart';
import '../profile/user_profile.dart';
import '../today/photo_analysis.dart' show mediaTypeFor;
import 'body_assessment.dart';
import 'measurement.dart';

Future<void> openBodyAssessment(BuildContext context, {required UserProfile profile, required Measurement last}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BodyAssessmentPage(profile: profile, last: last),
    ));

const _views = [
  ('front', 'De frente', 'Obligatoria', Icons.accessibility_new),
  ('side', 'De perfil', 'Recomendada', Icons.switch_account_outlined),
  ('back', 'De espalda', 'Opcional', Icons.person_outline),
];

/// Evaluación corporal con foto: el % de grasa de las fotos se combina con
/// el de las medidas y se dan recomendaciones.
class BodyAssessmentPage extends ConsumerStatefulWidget {
  const BodyAssessmentPage({super.key, required this.profile, required this.last});

  final UserProfile profile;

  /// Última medición (peso y perímetros).
  final Measurement last;

  @override
  ConsumerState<BodyAssessmentPage> createState() => _BodyAssessmentPageState();
}

class _BodyAssessmentPageState extends ConsumerState<BodyAssessmentPage> {
  final _photos = <String, BodyPhoto>{};
  bool? _consent;
  bool _accept = false;
  bool _busy = false;
  String? _error;
  BodyAssessment? _result;

  @override
  void initState() {
    super.initState();
    ref.read(bodyAssessmentServiceProvider).hasConsent().then((v) {
      if (mounted) setState(() => _consent = v);
    }).catchError((Object _) {
      if (mounted) setState(() => _consent = false);
    });
  }

  double? get _tapeFat => widget.last.compositionFor(widget.profile).fatPct;

  Future<void> _pick(String view, {required bool camera}) async {
    final picked = await ref.read(imagePickProvider)(camera: camera);
    if (picked == null) return;
    setState(() {
      _photos[view] = (bytes: picked.bytes, mediaType: mediaTypeFor(picked.name, picked.mimeType), view: view);
      _error = null;
    });
  }

  Future<void> _evaluate() async {
    final service = ref.read(bodyAssessmentServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_consent != true) {
        await service.setConsent(true);
        _consent = true;
      }
      final p = widget.profile;
      final m = widget.last;
      final now = DateTime.now();
      final ai = await service.assess([
        for (final v in _views) if (_photos[v.$1] != null) _photos[v.$1]!,
      ], {
        'sex': p.sex == Sex.male ? 'male' : 'female',
        'age': p.ageOn(now),
        'height_cm': p.heightCm,
        'weight_kg': m.weightKg,
        if (m.neckCm != null) 'neck_cm': m.neckCm,
        if (m.waistCm != null) 'waist_cm': m.waistCm,
        if (m.hipCm != null) 'hip_cm': m.hipCm,
        if (_tapeFat != null) 'tape_fat_pct': (_tapeFat! * 10).round() / 10,
        'goal_fat_pct': p.goalFatPct,
      });
      if (!ai.valid) {
        setState(() => _error = ai.invalidReason.isEmpty ? 'No se pudo evaluar con estas fotos.' : ai.invalidReason);
        return;
      }
      final a = BodyAssessment.fromAi(
        date: DateTime(now.year, now.month, now.day),
        weightKg: m.weightKg,
        ai: ai,
        tapeFatPct: _tapeFat,
      );
      await service.save(a);
      ref.invalidate(bodyAssessmentsProvider);
      if (mounted) setState(() => _result = a);
    } on BodyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la evaluación. Revisa tu conexión '
            '(o que la migración 0015 esté aplicada).');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluación con foto')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _result != null
                ? BodyAssessmentResult(assessment: _result!, sex: widget.profile.sex)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Sube 1 a 3 fotos de cuerpo completo. La IA estima tu % de grasa '
                        'mirando tu cuerpo y lo combina con tus medidas para darte un '
                        'resultado más preciso y recomendaciones.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Para que salga bien: luz pareja de frente, la cámara a la altura '
                        'del pecho a unos 2 m, de pie y relajado, con ropa ajustada '
                        '(calzas o short y top o sin polera) y fondo despejado.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final v in _views)
                        Card(
                          child: ListTile(
                            leading: _photos[v.$1] == null
                                ? Icon(v.$4)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.memory(_photos[v.$1]!.bytes, width: 44, height: 56, fit: BoxFit.cover),
                                  ),
                            title: Text(v.$2),
                            subtitle: Text(_photos[v.$1] == null ? v.$3 : 'Lista'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Tomar foto ${v.$2.toLowerCase()}',
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  onPressed: _busy ? null : () => _pick(v.$1, camera: true),
                                ),
                                IconButton(
                                  tooltip: 'Elegir foto ${v.$2.toLowerCase()}',
                                  icon: const Icon(Icons.photo_library_outlined),
                                  onPressed: _busy ? null : () => _pick(v.$1, camera: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Datos que se envían con las fotos: sexo, edad, estatura, peso '
                        '(${fmt(widget.last.weightKg, 1)} kg) y tus perímetros'
                        '${_tapeFat == null ? '' : ' (${fmt(_tapeFat, 1)} % de grasa según tus medidas)'}.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_consent == false) ...[
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _accept,
                          onChanged: _busy ? null : (v) => setState(() => _accept = v ?? false),
                          title: const Text(
                            'Acepto enviar estas fotos y mis datos a la IA (Anthropic) solo para '
                            'esta evaluación. Las fotos no se guardan: MAGRA guarda solo el '
                            'resultado, y puedo borrarlo cuando quiera.',
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ||
                                _consent == null ||
                                _photos['front'] == null ||
                                (_consent == false && !_accept)
                            ? null
                            : _evaluate,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_busy ? 'Evaluando…' : 'Evaluar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ningún método casero es exacto: la foto se equivoca ±3–5 puntos y '
                        'las medidas ±3–4. Combinarlas reduce el error. Si tienes un % de '
                        'grasa de bioimpedancia o DEXA, anótalo en una medición: tiene prioridad.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// El resultado de una evaluación: % final, cómo se obtuvo y qué hacer.
class BodyAssessmentResult extends StatelessWidget {
  const BodyAssessmentResult({super.key, required this.assessment, required this.sex, this.shrinkWrap = false});

  final BodyAssessment assessment;
  final Sex sex;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assessment;
    final r = a.result;
    Widget section(String title, IconData icon, List<String> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(title, style: theme.textTheme.titleMedium),
                ]),
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 24),
                    child: Text('• $s'),
                  ),
              ],
            ),
          );
    final leanKg = a.weightKg * (1 - a.finalFatPct / 100);
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.all(shrinkWrap ? 0 : 16),
      children: [
        Text('${fmt(a.finalFatPct, 1)} %',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(color: MagraColors.lime, fontWeight: FontWeight.w800)),
        Text('de grasa corporal · ${fmtDate(a.date)}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Masa magra ${fmt(leanKg, 1)} kg · masa grasa ${fmt(a.weightKg - leanKg, 1)} kg',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cómo se calculó', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('Foto: ${fmt(a.photoFatPct, 1)} % (rango ${fmt(a.photoFatLow, 1)}–${fmt(a.photoFatHigh, 1)} %, '
                    'confianza ${a.confidence})'),
                Text(a.tapeFatPct == null
                    ? 'Medidas: sin cuello y cintura registrados (solo la foto).'
                    : 'Medidas: ${fmt(a.tapeFatPct, 1)} % (fórmula de la Marina de EE.UU.)'),
                if (a.tapeFatPct != null)
                  Text('Resultado: promedio de ambas, con más peso para la más precisa.',
                      style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Tu plan usa este % desde el próximo lunes (Katch-McArdle).',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (r.distribution.isNotEmpty || r.muscleTone.isNotEmpty || r.posture.isNotEmpty)
          section('Lo que se observa', Icons.visibility_outlined, [
            if (r.distribution.isNotEmpty) r.distribution,
            if (r.muscleTone.isNotEmpty) r.muscleTone,
            if (r.posture.isNotEmpty) r.posture,
          ]),
        section('Tus fortalezas', Icons.emoji_events_outlined, r.strengths),
        section('Prioridades', Icons.flag_outlined, r.priorities),
        section('Nutrición', Icons.restaurant_outlined, r.nutrition),
        section('Entrenamiento', Icons.fitness_center, r.training),
        if (r.photoTips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Para la próxima: ${r.photoTips}', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Text(
          'Es una estimación orientativa, no un diagnóstico médico.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tarjeta de Progreso: última evaluación con foto, historial y botón.
class BodyAssessmentCard extends ConsumerWidget {
  const BodyAssessmentCard({super.key, required this.profile, required this.last});

  final UserProfile profile;
  final Measurement last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(bodyAssessmentsProvider).value ?? const <BodyAssessment>[];
    final latest = list.isEmpty ? null : list.last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (latest == null)
              Text(
                'Tómate fotos de frente y de perfil: la IA estima tu % de grasa, lo '
                'combina con tus medidas y te dice qué priorizar.',
                style: theme.textTheme.bodyMedium,
              )
            else
              BodyAssessmentResult(assessment: latest, sex: profile.sex, shrinkWrap: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openBodyAssessment(context, profile: profile, last: last),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(latest == null ? 'Hacer evaluación con foto' : 'Nueva evaluación'),
            ),
            if (list.length > 1) ...[
              const SizedBox(height: 12),
              Text('Historial', style: theme.textTheme.titleSmall),
              for (final a in list.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${fmtDate(a.date)} · ${fmt(a.finalFatPct, 1)} %'),
                  subtitle: Text('${fmt(a.weightKg, 1)} kg'),
                  trailing: a.id == null
                      ? null
                      : IconButton(
                          tooltip: 'Borrar evaluación del ${fmtDate(a.date)}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref.read(bodyAssessmentServiceProvider).delete(a.id!);
                            ref.invalidate(bodyAssessmentsProvider);
                          },
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
