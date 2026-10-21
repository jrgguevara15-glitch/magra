import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../profile/user_profile.dart';
import '../today/photo_analysis.dart';
import 'measurement.dart';
import 'progress_photos.dart';

/// Días entre una tanda de fotos y la siguiente.
const photoIntervalDays = 30;

/// Fotos de progreso: recordatorio mensual, la última tanda y el comparador.
class ProgressPhotosCard extends ConsumerWidget {
  const ProgressPhotosCard({
    super.key,
    required this.profile,
    required this.measurements,
  });

  final UserProfile profile;
  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    final days = daysSinceLastPhoto(photos, today);
    final dates = photoDates(photos);
    final due = days == null || days >= photoIntervalDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fotos de progreso', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              days == null
                  ? 'Toma tus primeras fotos: frente, perfil y espalda. En unas '
                      'semanas verás cambios que la balanza no muestra.'
                  : due
                      ? 'Ya pasaron $days días desde tus últimas fotos: toca '
                          'tomar las del mes.'
                      : 'Próximas fotos en ${photoIntervalDays - days} días.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: due ? theme.colorScheme.primary : null),
            ),
            if (dates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Últimas: ${fmtDate(dates.first)}', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final pose in PhotoPose.values) ...[
                    Expanded(
                      child: _Slot(
                        photo: photoFor(photos, dates.first, pose),
                        label: pose.label,
                      ),
                    ),
                    if (pose != PhotoPose.back) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => AddPhotosSheet(today: today),
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Agregar fotos'),
                ),
                if (dates.length >= 2)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ComparePhotosPage(
                        profile: profile,
                        measurements: measurements,
                      ),
                    )),
                    icon: const Icon(Icons.compare_outlined),
                    label: const Text('Comparar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Privadas: solo tú las ves. No se envían a la IA y puedes '
              'borrarlas cuando quieras.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniatura de una pose (o un espacio vacío si falta).
class _Slot extends StatelessWidget {
  const _Slot({required this.photo, required this.label});

  final ProgressPhoto? photo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = photo;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: p == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_outline, color: theme.colorScheme.outline),
                )
              : InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => _PhotoDialog(photo: p),
                  ),
                  child: PhotoView(photo: p),
                ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// La imagen de una foto, bajada del almacenamiento privado.
class PhotoView extends ConsumerWidget {
  const PhotoView({super.key, required this.photo});

  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(photoBytesProvider(photo));
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: bytes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Icon(Icons.broken_image_outlined)),
        data: (b) => Image.memory(b, fit: BoxFit.cover, width: double.infinity,
            height: double.infinity, gaplessPlayback: true),
      ),
    );
  }
}

class _PhotoDialog extends ConsumerWidget {
  const _PhotoDialog({required this.photo});

  final ProgressPhoto photo;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(progressPhotoRepositoryProvider).delete(photo);
      ref.invalidate(progressPhotosProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Foto borrada.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo borrar.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text('${photo.pose.label} · ${fmtDate(photo.date)}'),
      content: SizedBox(
        width: 360,
        child: AspectRatio(aspectRatio: 3 / 4, child: PhotoView(photo: photo)),
      ),
      actions: [
        TextButton(
          onPressed: () => _delete(context, ref),
          child: const Text('Borrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Subir la tanda del día: una foto por pose.
class AddPhotosSheet extends ConsumerStatefulWidget {
  const AddPhotosSheet({super.key, required this.today});

  final DateTime today;

  @override
  ConsumerState<AddPhotosSheet> createState() => _AddPhotosSheetState();
}

class _AddPhotosSheetState extends ConsumerState<AddPhotosSheet> {
  late DateTime _date = widget.today;
  PhotoPose _pose = PhotoPose.front;
  bool _busy = false;
  String? _error;

  bool get _canUseCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: widget.today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _add({required bool camera}) async {
    final picked = await ref.read(imagePickProvider)(camera: camera);
    if (picked == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(progressPhotoRepositoryProvider).upload(
            date: _date,
            pose: _pose,
            bytes: picked.bytes,
            mediaType: mediaTypeFor(picked.name, picked.mimeType),
          );
      ref.invalidate(progressPhotosProvider);
      if (mounted) {
        setState(() {
          final i = PhotoPose.values.indexOf(_pose);
          if (i < PhotoPose.values.length - 1) _pose = PhotoPose.values[i + 1];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo subir la foto. Revisa tu conexión '
            '(máximo 5 MB, JPG o PNG).');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fotos de progreso', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Misma luz, misma hora (idealmente en ayunas), ropa ajustada y el '
              'celular a la altura del pecho, a unos 2 metros.',
              style: theme.textTheme.bodySmall,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text('Fecha: ${fmtDate(_date)}'),
              trailing: TextButton(onPressed: _busy ? null : _pickDate, child: const Text('Cambiar')),
            ),
            SegmentedButton<PhotoPose>(
              showSelectedIcon: false,
              segments: [
                for (final p in PhotoPose.values)
                  ButtonSegment(
                    value: p,
                    label: Text(p.label),
                    icon: photoFor(photos, _date, p) != null
                        ? const Icon(Icons.check, size: 16)
                        : null,
                  ),
              ],
              selected: {_pose},
              onSelectionChanged: (s) => setState(() => _pose = s.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canUseCamera)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _add(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text('Tomar foto · ${_pose.label}'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _add(camera: false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_canUseCamera ? 'Elegir foto' : 'Subir foto · ${_pose.label}'),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Text(
              'Subidas el ${fmtDate(_date)}: '
              '${[for (final p in PhotoPose.values) if (photoFor(photos, _date, p) != null) p.label].join(', ').ifEmpty('ninguna')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Medición más cercana a una fecha (prefiere la de ese día o anterior).
Measurement? measurementNear(List<Measurement> list, DateTime date) {
  Measurement? best;
  var bestDays = 1 << 30;
  for (final m in list) {
    final diff = date.difference(m.date).inHours ~/ 24;
    // Las posteriores pesan doble: la foto refleja lo de antes.
    final score = diff >= 0 ? diff : -diff * 2;
    if (score < bestDays) {
      bestDays = score;
      best = m;
    }
  }
  return best;
}

/// Dos fechas lado a lado con sus medidas.
class ComparePhotosPage extends ConsumerStatefulWidget {
  const ComparePhotosPage({
    super.key,
    required this.profile,
    required this.measurements,
  });

  final UserProfile profile;
  final List<Measurement> measurements;

  @override
  ConsumerState<ComparePhotosPage> createState() => _ComparePhotosPageState();
}

class _ComparePhotosPageState extends ConsumerState<ComparePhotosPage> {
  DateTime? _before;
  DateTime? _after;
  PhotoPose _pose = PhotoPose.front;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    final dates = photoDates(photos);
    if (dates.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar')),
        body: const Center(child: Text('Necesitas fotos de al menos dos fechas.')),
      );
    }
    final before = _before != null && dates.contains(_before) ? _before! : dates.last;
    final after = _after != null && dates.contains(_after) ? _after! : dates.first;
    final mBefore = measurementNear(widget.measurements, before);
    final mAfter = measurementNear(widget.measurements, after);

    Widget side(String label, DateTime date, ValueChanged<DateTime> onChanged, Measurement? m) {
      final photo = photoFor(photos, date, _pose);
      final fat = m?.compositionFor(widget.profile).fatPct;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          DropdownButton<DateTime>(
            isExpanded: true,
            value: date,
            items: [
              for (final d in dates) DropdownMenuItem(value: d, child: Text(fmtDate(d))),
            ],
            onChanged: (d) => d == null ? null : onChanged(d),
          ),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: photo == null
                ? Center(child: Text('Sin foto de ${_pose.label.toLowerCase()}'))
                : PhotoView(photo: photo),
          ),
          const SizedBox(height: 6),
          if (m != null)
            Text(
              [
                '${fmt(m.weightKg, 1)} kg',
                if (m.waistCm != null) 'cintura ${fmt(m.waistCm, 1)} cm',
                if (fat != null) '${fmt(fat, 1)} % grasa',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
        ],
      );
    }

    String? diff() {
      if (mBefore == null || mAfter == null || mBefore == mAfter) return null;
      final dw = mAfter.weightKg - mBefore.weightKg;
      final parts = ['${dw <= 0 ? '−' : '+'}${fmt(dw.abs(), 1)} kg'];
      if (mBefore.waistCm != null && mAfter.waistCm != null) {
        final dc = mAfter.waistCm! - mBefore.waistCm!;
        parts.add('${dc <= 0 ? '−' : '+'}${fmt(dc.abs(), 1)} cm de cintura');
      }
      return 'Cambio: ${parts.join(' · ')}';
    }

    final change = diff();
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar fotos')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<PhotoPose>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in PhotoPose.values) ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_pose},
                  onSelectionChanged: (s) => setState(() => _pose = s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: side('Antes', before, (d) => setState(() => _before = d), mBefore)),
                    const SizedBox(width: 12),
                    Expanded(child: side('Después', after, (d) => setState(() => _after = d), mAfter)),
                  ],
                ),
                if (change != null) ...[
                  const SizedBox(height: 12),
                  Text(change, style: theme.textTheme.titleMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
