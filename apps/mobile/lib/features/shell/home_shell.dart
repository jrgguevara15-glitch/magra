import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../coach/coach_page.dart';
import '../menus/menus_page.dart';
import '../plan/plan_inputs.dart';
import '../plan/plan_page.dart';
import '../progress/progress_page.dart';
import '../today/today_page.dart';
import '../training/training_page.dart';

/// Una pestaña principal de MAGRA.
class MagraDestination {
  const MagraDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.description,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String description;
}

const magraDestinations = <MagraDestination>[
  MagraDestination(
    label: 'Hoy',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    description: 'Registro del día, foto → calorías, ejercicio y ayuno.',
  ),
  MagraDestination(
    label: 'Plan',
    icon: Icons.restaurant_menu_outlined,
    selectedIcon: Icons.restaurant_menu,
    description: 'Intercambios, porciones y días sin carbohidratos.',
  ),
  MagraDestination(
    label: 'Menús',
    icon: Icons.shopping_basket_outlined,
    selectedIcon: Icons.shopping_basket,
    description: 'Menú semanal con marcas y lista de compras.',
  ),
  MagraDestination(
    label: 'Progreso',
    icon: Icons.monitor_weight_outlined,
    selectedIcon: Icons.monitor_weight,
    description: 'Evaluación corporal, evolución y meta física.',
  ),
  MagraDestination(
    label: 'Entreno',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center,
    description: 'Plan de fuerza + cardio y calorías quemadas.',
  ),
  MagraDestination(
    label: 'Coach',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    description: 'Asesor IA con tus datos.',
  ),
];

/// Ancho desde el que se usa navegación lateral (tablet y escritorio).
const double kWideLayoutBreakpoint = 720;

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int get _index => ref.watch(homeTabProvider);

  void _select(int index) => ref.read(homeTabProvider.notifier).go(index);

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Text(
            'Saldrás de ${ref.read(authRepositoryProvider).email ?? 'tu cuenta'}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final destination = magraDestinations[_index];
    final body = switch (_index) {
      0 => const TodayPage(),
      1 => const PlanPage(),
      2 => const MenusPage(),
      kProgressTab => const ProgressPage(),
      4 => const TrainingPage(),
      5 => const CoachPage(),
      _ => _PlaceholderPage(destination: destination),
    };
    final signOutButton = IconButton(
      tooltip: 'Cerrar sesión',
      icon: const Icon(Icons.logout),
      onPressed: _signOut,
    );
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: _Wordmark(),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: signOutButton,
                  ),
                ),
              ),
              destinations: [
                for (final d in magraDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const _Wordmark(), actions: [signOutButton]),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          for (final d in magraDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Text(
      'MAGRA',
      style: TextStyle(
        color: color,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
    );
  }
}

/// Pantalla provisoria de cada pestaña hasta que se implemente su bloque.
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.destination});

  final MagraDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.selectedIcon,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(destination.label, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                destination.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Próximamente',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
