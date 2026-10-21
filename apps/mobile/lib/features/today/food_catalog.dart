import '../../core/format.dart';
import '../../core/recommendation/reference_foods.dart';
import '../questionnaire/questionnaire.dart';

part 'food_catalog_extra.dart';

/// Grupo al que pertenece un alimento del catálogo.
enum FoodGroup {
  protein('Proteínas'),
  carb('Carbohidratos'),
  fat('Grasas'),
  vegetable('Verduras'),
  other('Lácteos y otros'),
  drink('Bebidas y café'),
  alcohol('Alcohol'),
  snack('Snacks'),
  sweet('Dulces y golosinas'),
  fastFood('Comida rápida'),
  condiment('Salsas y condimentos');

  const FoodGroup(this.label);
  final String label;

  /// Se registran por porción casera (lata, copa, unidad), no por gramos
  /// calculados según el plan.
  bool get byServing => index >= FoodGroup.drink.index;
}

/// Alimento del catálogo con sus nutrientes por 100 g o 100 ml, listo para
/// comer (salvo donde el nombre dice "crudo").
class CatalogFood {
  const CatalogFood(
    this.name,
    this.group,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat, {
    this.tags = const {},
    this.unit = 'g',
    this.unitName,
    this.unitGrams,
    this.mine = false,
    this.lastQuantity,
  });

  /// Un alimento que el usuario ya anotó: se vuelve a agregar con la misma
  /// porción (o en gramos si se registró en gramos).
  factory CatalogFood.fromEntry(FoodEntry e) {
    final q = e.quantity;
    if (q != null && q > 0 && (e.unit == 'g' || e.unit == 'ml')) {
      final k = 100 / q;
      return CatalogFood(e.name, FoodGroup.other, e.kcal * k, e.protein * k, e.carbs * k, e.fat * k,
          unit: e.unit, mine: true, lastQuantity: q);
    }
    // Porciones: se guardan "por 1 porción" (unitGrams = 1).
    final n = q == null || q <= 0 ? 1.0 : q;
    final u = q == null ? 'porción' : e.unit;
    return CatalogFood(e.name, FoodGroup.other, e.kcal / n * 100, e.protein / n * 100,
        e.carbs / n * 100, e.fat / n * 100,
        unit: u, unitName: u, unitGrams: 1, mine: true, lastQuantity: n);
  }

  final String name;
  final FoodGroup group;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final Set<FoodTag> tags;

  /// 'g' o 'ml'.
  final String unit;

  /// Unidad casera opcional ('huevo', 'plátano') y cuánto pesa.
  final String? unitName;
  final double? unitGrams;

  /// Viene de lo que el usuario ya anotó ("Tus alimentos").
  final bool mine;

  /// Cantidad de la última vez (en [unit]).
  final double? lastQuantity;

  /// Se mide en porciones propias (no en gramos ni ml).
  bool get servingOnly => unitGrams == 1 && unitName == unit;

  /// Nutrientes de [grams] g (o ml).
  ({double kcal, double protein, double carbs, double fat}) nutrientsFor(
          double grams) =>
      (
        kcal: kcal * grams / 100,
        protein: protein * grams / 100,
        carbs: carbs * grams / 100,
        fat: fat * grams / 100,
      );
}

const foodCatalog = <CatalogFood>[
  // Proteínas
  CatalogFood('Pechuga de pollo cocida', FoodGroup.protein, 165, 31, 0, 3.6,
      tags: {FoodTag.meat}),
  CatalogFood('Posta o lomo de vacuno cocido', FoodGroup.protein, 180, 28, 0, 7,
      tags: {FoodTag.meat}),
  CatalogFood('Lomo de cerdo magro cocido', FoodGroup.protein, 165, 27, 0, 6,
      tags: {FoodTag.meat}),
  CatalogFood('Atún al agua escurrido', FoodGroup.protein, 116, 26, 0, 1,
      tags: {FoodTag.fish}),
  CatalogFood('Merluza o reineta cocida', FoodGroup.protein, 95, 20, 0, 1.5,
      tags: {FoodTag.fish}),
  CatalogFood('Salmón cocido', FoodGroup.protein, 206, 22, 0, 12,
      tags: {FoodTag.fish}),
  CatalogFood('Camarones cocidos', FoodGroup.protein, 99, 24, 0.2, 0.3,
      tags: {FoodTag.shellfish}),
  CatalogFood('Huevo', FoodGroup.protein, 143, 12.6, 0.7, 9.5,
      tags: {FoodTag.egg}, unitName: 'huevo', unitGrams: 50),
  CatalogFood('Claras de huevo', FoodGroup.protein, 52, 11, 0.7, 0.2,
      tags: {FoodTag.egg}),
  CatalogFood('Yogur griego natural sin azúcar', FoodGroup.protein, 59, 9, 3.6, 0.4,
      tags: {FoodTag.dairy}),
  CatalogFood('Quesillo', FoodGroup.protein, 130, 13, 3, 7,
      tags: {FoodTag.dairy}),
  CatalogFood('Tofu firme', FoodGroup.protein, 144, 15, 3, 8.7,
      tags: {FoodTag.soy}),
  CatalogFood('Tempeh', FoodGroup.protein, 192, 19, 9, 11,
      tags: {FoodTag.soy}),
  CatalogFood('Seitán', FoodGroup.protein, 120, 25, 4, 1.9,
      tags: {FoodTag.gluten}),
  CatalogFood('Proteína whey en polvo', FoodGroup.protein, 380, 76, 8, 5,
      tags: {FoodTag.dairy}),
  // Carbohidratos
  CatalogFood('Arroz cocido', FoodGroup.carb, 130, 2.7, 28, 0.3),
  CatalogFood('Papa cocida', FoodGroup.carb, 87, 1.9, 20, 0.1),
  CatalogFood('Legumbres cocidas (lentejas, porotos, garbanzos)', FoodGroup.carb,
      120, 8.5, 20, 0.5),
  CatalogFood('Quinoa cocida', FoodGroup.carb, 120, 4.4, 21, 1.9),
  CatalogFood('Arepa o tortilla de maíz', FoodGroup.carb, 218, 4.5, 45, 1.5),
  CatalogFood('Avena cruda', FoodGroup.carb, 389, 17, 66, 7,
      tags: {FoodTag.gluten}),
  CatalogFood('Pan integral', FoodGroup.carb, 247, 13, 41, 3.4,
      tags: {FoodTag.gluten}),
  CatalogFood('Pan marraqueta', FoodGroup.carb, 267, 9, 56, 1,
      tags: {FoodTag.gluten}),
  CatalogFood('Pasta cocida', FoodGroup.carb, 131, 5, 25, 1.1,
      tags: {FoodTag.gluten}),
  CatalogFood('Plátano', FoodGroup.carb, 89, 1.1, 23, 0.3,
      unitName: 'plátano', unitGrams: 120),
  CatalogFood('Manzana', FoodGroup.carb, 52, 0.3, 14, 0.2,
      unitName: 'manzana', unitGrams: 180),
  // Grasas
  CatalogFood('Palta', FoodGroup.fat, 160, 2, 9, 15),
  CatalogFood('Aceite de oliva', FoodGroup.fat, 828, 0, 0, 92, unit: 'ml'),
  CatalogFood('Almendras', FoodGroup.fat, 579, 21, 22, 50,
      tags: {FoodTag.treeNuts}),
  CatalogFood('Maní sin sal', FoodGroup.fat, 567, 26, 16, 49,
      tags: {FoodTag.peanut}),
  CatalogFood('Semillas de chía', FoodGroup.fat, 486, 17, 42, 31),
  CatalogFood('Queso gauda', FoodGroup.fat, 356, 25, 2, 27,
      tags: {FoodTag.dairy}),
  // Vegetales
  CatalogFood('Lechuga', FoodGroup.vegetable, 15, 1.4, 2.9, 0.2),
  CatalogFood('Tomate', FoodGroup.vegetable, 18, 0.9, 3.9, 0.2),
  CatalogFood('Brócoli', FoodGroup.vegetable, 34, 2.8, 7, 0.4),
  CatalogFood('Zanahoria', FoodGroup.vegetable, 41, 0.9, 10, 0.2),
  CatalogFood('Pepino', FoodGroup.vegetable, 15, 0.7, 3.6, 0.1),
  CatalogFood('Zapallo italiano', FoodGroup.vegetable, 17, 1.2, 3.1, 0.3),
  // Otros
  CatalogFood('Leche descremada', FoodGroup.other, 35, 3.4, 5, 0.1,
      tags: {FoodTag.dairy}, unit: 'ml'),
  CatalogFood('Leche entera', FoodGroup.other, 61, 3.2, 4.8, 3.3,
      tags: {FoodTag.dairy}, unit: 'ml'),
  ..._extraFoods,
];

/// Alimentos que el usuario puede elegir, que coinciden con [query].
List<CatalogFood> searchCatalog(Questionnaire q, String query) {
  final excluded = excludedFoodTags(q);
  final words = plainText(query).split(' ').where((w) => w.isNotEmpty).toList();
  return [
    for (final f in foodCatalog)
      if (f.tags.intersection(excluded).isEmpty &&
          words.every((w) => plainText(f.name).contains(w)))
        f,
  ];
}

/// Cantidad sugerida de [food] para cubrir lo que le toca a una comida.
/// Proteínas → proteína de la comida; carbohidratos → carbohidratos; grasas
/// → grasa; vegetales y otros → una porción habitual.
double suggestedGrams(
  CatalogFood food, {
  required double mealProtein,
  required double mealCarbs,
  required double mealFat,
}) {
  if (food.group.byServing) return food.unitGrams ?? 100;
  final grams = switch (food.group) {
    FoodGroup.protein => mealProtein / food.protein * 100,
    FoodGroup.carb => mealCarbs / food.carbs * 100,
    FoodGroup.fat => mealFat / food.fat * 100,
    FoodGroup.vegetable => 100.0,
    _ => 200.0,
  };
  if (food.unitGrams != null) {
    final units = ((grams / food.unitGrams! * 2).round() / 2)
        .clamp(0.5, ReferenceFood.maxUnits.toDouble());
    return units * food.unitGrams!;
  }
  final rounded = (grams / 5).round() * 5.0;
  return rounded < 5 ? 5 : rounded;
}

/// Un alimento registrado en un día.
class FoodEntry {
  const FoodEntry({
    this.id,
    required this.date,
    required this.mealIndex,
    required this.name,
    this.quantity,
    this.unit = 'g',
    required this.kcal,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.source = 'catalog',
  });

  factory FoodEntry.fromCatalog(
    CatalogFood food,
    double grams, {
    required DateTime date,
    required int mealIndex,
  }) {
    final n = food.nutrientsFor(grams);
    return FoodEntry(
      date: date,
      mealIndex: mealIndex,
      name: food.name,
      quantity: grams,
      unit: food.unit,
      kcal: n.kcal,
      protein: n.protein,
      carbs: n.carbs,
      fat: n.fat,
    );
  }

  final String? id;
  final DateTime date;
  final int mealIndex;
  final String name;
  final double? quantity;
  final String unit;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final String source;

  FoodEntry copyWith({
    String? name,
    double? quantity,
    String? unit,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) =>
      FoodEntry(
        id: id,
        date: date,
        mealIndex: mealIndex,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        kcal: kcal ?? this.kcal,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        source: source,
      );

  String get quantityLabel =>
      quantity == null ? '' : '${fmt(quantity, quantity! % 1 == 0 ? 0 : 1)} $unit';

  factory FoodEntry.fromRow(Map<String, dynamic> row) {
    double d(String k) => (row[k] as num? ?? 0).toDouble();
    return FoodEntry(
      id: row['id'] as String?,
      date: DateTime.parse(row['eaten_on'] as String),
      mealIndex: (row['meal_index'] as num).toInt(),
      name: row['name'] as String,
      quantity: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit'] as String? ?? 'g',
      kcal: d('kcal'),
      protein: d('protein_g'),
      carbs: d('carbs_g'),
      fat: d('fat_g'),
      source: row['source'] as String? ?? 'catalog',
    );
  }

  double _r1(double v) => (v * 10).round() / 10;

  Map<String, dynamic> toRow() => {
        'eaten_on': isoDate(date),
        'meal_index': mealIndex,
        'name': name,
        'quantity': quantity == null ? null : _r1(quantity!),
        'unit': unit,
        'kcal': _r1(kcal),
        'protein_g': _r1(protein),
        'carbs_g': _r1(carbs),
        'fat_g': _r1(fat),
        'source': source,
      };
}
