import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/recommendation/exercise_guides.dart';
import '../../core/theme.dart';

/// Abre la ficha de un ejercicio.
Future<void> openExerciseGuide(BuildContext context, String exercise, {String? prescription}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseGuidePage(exercise: exercise, prescription: prescription),
    ));

/// Ficha del ejercicio: fotos animadas, equipo, músculos, pasos y errores.
class ExerciseGuidePage extends StatelessWidget {
  const ExerciseGuidePage({super.key, required this.exercise, this.prescription});

  final String exercise;
  final String? prescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moves = guideFor(exercise);
    return Scaffold(
      appBar: AppBar(title: Text(exercise, maxLines: 2)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (prescription != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(prescription!, style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
                  ),
                if (moves.isEmpty)
                  const Text('Aún no hay ficha para este ejercicio.'),
                for (final m in moves) _MoveSection(move: m, showName: moves.length > 1),
                if (moves.any((m) => m.imageId != null))
                  Text(imageCredit, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveSection extends StatelessWidget {
  const _MoveSection({required this.move, required this.showName});

  final GuideMove move;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName) ...[
            Text(move.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
          ],
          if (move.images.isNotEmpty) MoveFrames(images: move.images),
          if (move.note != null) ...[
            const SizedBox(height: 6),
            Text(move.note!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.fitness_center, size: 16, color: MagraColors.lime),
                label: Text(move.equipment),
              ),
              for (final m in move.muscles)
                Chip(label: Text(m), backgroundColor: MagraColors.surfaceHigh),
            ],
          ),
          const SizedBox(height: 16),
          Text('Cómo hacerlo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (var i = 0; i < move.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: MagraColors.lime,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: MagraColors.background,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(move.steps[i])),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Errores comunes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final e in move.mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.close_rounded, size: 18, color: MagraColors.bad),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Alterna las fotos de inicio y fin del movimiento como una animación.
class MoveFrames extends StatefulWidget {
  const MoveFrames({super.key, required this.images, this.height = 220});

  final List<String> images;
  final double height;

  @override
  State<MoveFrames> createState() => _MoveFramesState();
}

class _MoveFramesState extends State<MoveFrames> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % widget.images.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.white,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Image.asset(
            widget.images[_frame],
            key: ValueKey(_frame),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, e, st) =>
                const Center(child: Icon(Icons.image_not_supported_outlined)),
          ),
        ),
      ),
    );
  }
}

/// Miniatura cuadrada de un ejercicio (primera foto) o un ícono.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 48});

  final String exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final images = [for (final m in guideFor(exercise)) ...m.images];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: images.isEmpty ? MagraColors.surfaceHigh : Colors.white,
        child: images.isEmpty
            ? const Icon(Icons.fitness_center, color: MagraColors.lime, size: 22)
            : Image.asset(images.first, fit: BoxFit.cover,
                errorBuilder: (context, e, st) => const Icon(Icons.fitness_center)),
      ),
    );
  }
}
