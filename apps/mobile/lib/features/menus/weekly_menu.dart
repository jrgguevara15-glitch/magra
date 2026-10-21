import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';
import '../../core/recommendation/nutrition_plan.dart';
import '../../core/recommendation/reference_foods.dart';
import '../questionnaire/questionnaire.dart';

/// Un ingrediente de un plato del menú (cantidad en crudo).
class MenuItem {
  const MenuItem({
    required this.food,
    required this.quantity,
    required this.unit,
    required this.kcal,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.category = 'Otros',
    this.brand = '',
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num? ?? 0).toDouble();
    return MenuItem(
      food: j['food'] as String? ?? 'Alimento',
      quantity: d('quantity'),
      unit: j['unit'] as String? ?? 'g',
      kcal: d('kcal'),
      protein: d('protein_g'),
      carbs: d('carbs_g'),
      fat: d('fat_g'),
      category: j['category'] as String? ?? 'Otros',
      brand: j['brand'] as String? ?? '',
    );
  }

  final String food;
  final double quantity;

  /// 'g', 'ml' o 'unidad'.
  final String unit;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Sección del supermercado.
  final String category;

  /// Marca chilena sugerida ('' si no aplica).
  final String brand;

  String get quantityLabel => unit == 'unidad'
      ? '${fmt(quantity, quantity % 1 == 0 ? 0 : 1)} ${quantity == 1 ? 'unidad' : 'unidades'}'
      : '${fmt(quantity)} $unit';

  Map<String, dynamic> toJson() => {
        'food': food,
        'quantity': quantity,
        'unit': unit,
        'kcal': kcal,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
        'category': category,
        'brand': brand,
      };
}

/// Un plato del menú.
class MenuMeal {
  const MenuMeal({required this.name, this.prep = '', required this.items});

  factory MenuMeal.fromJson(Map<String, dynamic> j) => MenuMeal(
        name: j['name'] as String? ?? 'Comida',
        prep: j['prep'] as String? ?? '',
        items: [
          for (final i in (j['items'] as List? ?? const []))
            MenuItem.fromJson((i as Map).cast<String, dynamic>()),
        ],
      );

  final String name;
  final String prep;
  final List<MenuItem> items;

  double get kcal => items.fold(0, (a, i) => a + i.kcal);
  double get protein => items.fold(0, (a, i) => a + i.protein);

  Map<String, dynamic> toJson() => {
        'name': name,
        'prep': prep,
        'items': [for (final i in items) i.toJson()],
      };
}

/// Meta de una comida que fija el motor (la IA no la cambia).
class MenuSlot {
  const MenuSlot({
    required this.time,
    required this.role,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory MenuSlot.fromPlanned(PlannedMeal m) => MenuSlot(
        time: '${m.time.hour.toString().padLeft(2, '0')}:'
            '${m.time.minute.toString().padLeft(2, '0')}',
        role: switch (m.role) {
          MealRole.preWorkout => 'pre',
          MealRole.postWorkout => 'post',
          MealRole.regular => 'regular',
        },
        kcal: m.kcal,
        protein: m.protein,
        carbs: m.carbs,
        fat: m.fat,
      );

  factory MenuSlot.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num? ?? 0).toDouble();
    return MenuSlot(
      time: j['time'] as String? ?? '12:00',
      role: j['role'] as String? ?? 'regular',
      kcal: d('kcal'),
      protein: d('protein_g'),
      carbs: d('carbs_g'),
      fat: d('fat_g'),
    );
  }

  /// HH:MM
  final String time;

  /// 'regular', 'pre' o 'post' (respecto del entrenamiento).
  final String role;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  Map<String, dynamic> toJson() => {
        'time': time,
        'role': role,
        'kcal': kcal.round(),
        'protein_g': protein.round(),
        'carbs_g': carbs.round(),
        'fat_g': fat.round(),
      };
}

/// Preferencias del cuestionario que necesita la IA para elegir platos.
Map<String, dynamic> menuPrefs(Questionnaire q) => {
      'diet': q.dietPattern.label,
      'allergies': [for (final a in q.allergies) a.label],
      'dislikes': q.dislikedFoods.trim(),
      'budget': q.budget.label,
      'cooking': q.cooking.label,
    };

/// Menú de una semana (lunes a domingo).
class WeeklyMenu {
  const WeeklyMenu({
    this.id,
    required this.weekStart,
    required this.slots,
    required this.days,
    this.checked = const {},
  });

  factory WeeklyMenu.fromRow(Map<String, dynamic> row) => WeeklyMenu(
        id: row['id'] as String?,
        weekStart: DateTime.parse(row['week_start'] as String),
        slots: [
          for (final s in row['slots'] as List)
            MenuSlot.fromJson((s as Map).cast<String, dynamic>()),
        ],
        days: [
          for (final d in row['days'] as List)
            [
              for (final m in d as List)
                MenuMeal.fromJson((m as Map).cast<String, dynamic>()),
            ],
        ],
        checked: {for (final c in row['checked'] as List? ?? const []) c as String},
      );

  final String? id;
  final DateTime weekStart;
  final List<MenuSlot> slots;

  /// 7 días, cada uno con una comida por slot.
  final List<List<MenuMeal>> days;

  /// Claves de la lista de compras ya marcadas.
  final Set<String> checked;

  DateTime dateOf(int day) =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + day);

  /// El plan ya no calza con este menú (otro n.º de comidas o calorías).
  bool outdatedFor(NutritionPlan plan) {
    if (plan.meals.length != slots.length) return true;
    final now = plan.kcal;
    final then = slots.fold<double>(0, (a, s) => a + s.kcal);
    return (now - then).abs() > now * 0.05;
  }

  WeeklyMenu copyWith({List<List<MenuMeal>>? days, Set<String>? checked}) =>
      WeeklyMenu(
        id: id,
        weekStart: weekStart,
        slots: slots,
        days: days ?? this.days,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toRow() => {
        'week_start': isoDate(weekStart),
        'slots': [for (final s in slots) s.toJson()],
        'days': [
          for (final d in days) [for (final m in d) m.toJson()],
        ],
        'checked': checked.toList()..sort(),
      };
}

/// Orden de las secciones en la lista de compras.
const shoppingCategories = [
  'Verduras y frutas',
  'Carnes, pollo y pescados',
  'Lácteos y huevos',
  'Panadería y cereales',
  'Abarrotes',
  'Congelados',
  'Otros',
];

class ShoppingItem {
  const ShoppingItem({
    required this.key,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.brand,
  });

  /// Identifica el artículo para marcarlo (nombre sin tildes + unidad).
  final String key;
  final String food;
  final double quantity;
  final String unit;
  final String category;
  final String brand;

  /// Cantidad para comprar: g → kg, ml → L, unidades enteras.
  String get quantityLabel => switch (unit) {
        'unidad' => () {
            final n = quantity.ceil();
            return '$n ${n == 1 ? 'unidad' : 'unidades'}';
          }(),
        'ml' => quantity >= 1000
            ? '${fmt(quantity / 1000, 1)} L'
            : '${fmt((quantity / 10).ceil() * 10)} ml',
        _ => quantity >= 1000
            ? '${fmt(quantity / 1000, 1)} kg'
            : '${fmt((quantity / 10).ceil() * 10)} g',
      };
}

/// Lista de compras de la semana: suma cada ingrediente de todos los días.
List<ShoppingItem> shoppingList(WeeklyMenu menu) {
  final byKey = <String, ShoppingItem>{};
  for (final day in menu.days) {
    for (final meal in day) {
      for (final i in meal.items) {
        final key = '${plainText(i.food).trim()}|${i.unit}';
        final prev = byKey[key];
        byKey[key] = ShoppingItem(
          key: key,
          food: prev?.food ?? i.food,
          quantity: (prev?.quantity ?? 0) + i.quantity,
          unit: i.unit,
          category: prev?.category ?? i.category,
          brand: (prev?.brand.isNotEmpty ?? false) ? prev!.brand : i.brand,
        );
      }
    }
  }
  int rank(String c) {
    final i = shoppingCategories.indexOf(c);
    return i < 0 ? shoppingCategories.length : i;
  }

  return byKey.values.toList()
    ..sort((a, b) {
      final c = rank(a.category).compareTo(rank(b.category));
      return c != 0 ? c : plainText(a.food).compareTo(plainText(b.food));
    });
}

/// Error con un mensaje listo para mostrar.
class MenuException implements Exception {
  const MenuException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class MenuGenerator {
  /// Los 7 días, cada uno con una comida por slot.
  Future<List<List<MenuMeal>>> week({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
  });

  /// Otra comida para ese día y ese slot, distinta de [avoid].
  Future<MenuMeal> meal({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
    required int day,
    required int meal,
    required List<String> avoid,
  });
}

String menuErrorMessage(int status, Object? details) {
  if (details is Map && details['error'] is String) {
    final text = details['error'] as String;
    return status >= 500 ? '$text (error $status)' : text;
  }
  return switch (status) {
    401 || 403 => 'El servidor rechazó tu sesión (error $status). Vuelve a entrar.',
    404 => 'La función de menús (ai-menu) aún no está instalada en el servidor.',
    429 => 'Llegaste al límite de menús por hoy.',
    _ => 'No se pudo armar el menú (error $status). Intenta de nuevo.',
  };
}

/// Llama a la función `ai-menu` del servidor.
class SupabaseMenuGenerator implements MenuGenerator {
  SupabaseMenuGenerator(this._client);

  final SupabaseClient _client;

  Future<Object?> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('ai-menu', body: body);
      return res.data;
    } on FunctionException catch (e) {
      throw MenuException(menuErrorMessage(e.status, e.details));
    } catch (_) {
      throw const MenuException('No hay conexión con el servidor. Revisa tu internet.');
    }
  }

  @override
  Future<List<List<MenuMeal>>> week({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
  }) async {
    final data = await _invoke({
      'mode': 'week',
      'slots': [for (final s in slots) s.toJson()],
      'prefs': prefs,
    });
    return parseWeek(data);
  }

  @override
  Future<MenuMeal> meal({
    required List<MenuSlot> slots,
    required Map<String, dynamic> prefs,
    required int day,
    required int meal,
    required List<String> avoid,
  }) async {
    final data = await _invoke({
      'mode': 'meal',
      'slots': [for (final s in slots) s.toJson()],
      'prefs': prefs,
      'day': day,
      'meal': meal,
      'avoid': avoid,
    });
    try {
      return MenuMeal.fromJson(((data as Map)['meal'] as Map).cast<String, dynamic>());
    } catch (_) {
      throw MenuException(unexpectedReply(data));
    }
  }
}

/// Mensaje cuando la función responde otra cosa (p. ej. el código de
/// ejemplo de Supabase en vez de ai-menu).
String unexpectedReply(Object? data) {
  final text = data is Map || data is List ? jsonEncode(data) : '$data';
  final short = text.length > 120 ? '${text.substring(0, 120)}…' : text;
  return 'El servidor respondió algo inesperado: $short. Revisa que la '
      'función ai-menu tenga el código de MAGRA.';
}

/// Los 7 días que devuelve `ai-menu`.
List<List<MenuMeal>> parseWeek(Object? data) {
  try {
    final days = (data as Map)['days'] as List;
    if (days.length != 7) throw const FormatException('días');
    return [
      for (final d in days)
        [
          for (final m in d as List)
            MenuMeal.fromJson((m as Map).cast<String, dynamic>()),
        ],
    ];
  } catch (_) {
    throw MenuException(unexpectedReply(data));
  }
}
