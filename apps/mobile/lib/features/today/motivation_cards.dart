import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/recommendation/motivation.dart';
import '../../core/theme.dart';

/// Punto de color del semáforo de un alimento.
class FoodLightDot extends StatelessWidget {
  const FoodLightDot({super.key, required this.light});

  final FoodLight? light;

  @override
  Widget build(BuildContext context) {
    final l = light;
    if (l == null) return const SizedBox(width: 10);
    final color = switch (l) {
      FoodLight.green => MagraColors.good,
      FoodLight.yellow => MagraColors.warning,
      FoodLight.red => MagraColors.bad,
    };
    return Tooltip(
      message: l.label,
      child: Semantics(
        label: l.label,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Rachas: días registrando, días con la proteína y semanas entrenando.
class StreaksCard extends StatelessWidget {
  const StreaksCard({
    super.key,
    required this.logDays,
    required this.proteinDays,
    required this.trainingWeeks,
  });

  final int logDays;
  final int proteinDays;
  final int trainingWeeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(IconData icon, int n, String one, String many) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: n > 0 ? theme.colorScheme.primary : theme.colorScheme.outline),
            const SizedBox(width: 6),
            Flexible(child: Text('$n ${n == 1 ? one : many}')),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            item(Icons.local_fire_department_outlined, logDays,
                'día registrando', 'días registrando'),
            item(Icons.egg_alt_outlined, proteinDays,
                'día con tu proteína', 'días con tu proteína'),
            item(Icons.fitness_center, trainingWeeks,
                'semana entrenando', 'semanas entrenando'),
          ],
        ),
      ),
    );
  }
}

/// Banco de calorías de la semana: lo guardado y usarlo hoy.
class BankCard extends ConsumerWidget {
  const BankCard({
    super.key,
    required this.today,
    required this.available,
    required this.usedToday,
  });

  final DateTime today;
  final int available;
  final int usedToday;

  Future<void> _set(BuildContext context, WidgetRef ref, int kcal) async {
    try {
      await ref.read(calorieBankRepositoryProvider).use(today, kcal);
      ref.invalidate(bankUsesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo guardar. Revisa tu conexión.')));
      }
    }
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final max = available < bankUseMax ? available : bankUseMax;
    var value = max.toDouble();
    final kcal = await showDialog<int>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Usar el banco hoy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('+${value.round()} kcal a tu meta de hoy',
                  style: Theme.of(d).textTheme.titleMedium),
              if (max > 50)
                Slider(
                  value: value,
                  min: 50,
                  max: max.toDouble(),
                  divisions: ((max - 50) / 10).round().clamp(1, 100),
                  label: '${value.round()}',
                  onChanged: (v) => set(() => value = (v / 10).round() * 10.0),
                ),
              const Text('Úsalo para una ocasión especial; sigues dentro de tu '
                  'déficit de la semana.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(d, value.round()),
              child: const Text('Usar'),
            ),
          ],
        ),
      ),
    );
    if (kcal != null && context.mounted) await _set(context, ref, kcal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          children: [
            Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Banco de la semana: ${fmt(available)} kcal',
                      style: theme.textTheme.titleSmall),
                  Text(
                    usedToday > 0
                        ? 'Hoy usas $usedToday kcal del banco.'
                        : 'Lo que comes bajo tu meta (hasta $bankPerDayMax por día, '
                            'sin bajar del mínimo seguro) se guarda hasta el domingo.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (usedToday > 0)
              TextButton(onPressed: () => _set(context, ref, 0), child: const Text('Dejar de usar'))
            else if (available >= 50)
              TextButton(onPressed: () => _choose(context, ref), child: const Text('Usar hoy')),
          ],
        ),
      ),
    );
  }
}
