import '../../features/questionnaire/questionnaire.dart';
import '../format.dart';

/// Grupo del intercambio que cubre un alimento de referencia.
enum MacroGroup { protein, carb, fat }

/// Qué contiene un alimento, para filtrar por dieta y alergias.
enum FoodTag { meat, fish, shellfish, egg, dairy, gluten, peanut, treeNuts, soy }

/// Alimento de referencia para sugerir porciones. Valores por 100 g (o
/// 100 ml) listos para comer, salvo donde el nombre dice "crudo".
class ReferenceFood {
  const ReferenceFood(this.name, this.group, this.gramsPer100,
      {this.tags = const {}, this.unit = 'g', this.unitGrams});

  final String name;
  final MacroGroup group;

  /// Gramos del macronutriente del grupo por cada 100 g.
  final double gramsPer100;
  final Set<FoodTag> tags;

  /// Unidad casera opcional (p. ej. 'huevo') y cuántos gramos pesa.
  final String unit;
  final double? unitGrams;

  /// Máximo de unidades caseras que tiene sentido sugerir en una comida.
  static const maxUnits = 4;

  /// Cuánto de este alimento aporta [grams] del macronutriente, en algo
  /// que se pueda medir en casa ("115 g pechuga de pollo cocida",
  /// "2 huevos"). `null` si la porción no es razonable (más de
  /// [maxUnits] unidades).
  String? portionFor(double grams) {
    final qty = grams / gramsPer100 * 100;
    if (unitGrams != null) {
      final units = (qty / unitGrams! * 2).round() / 2;
      final n = units < 0.5 ? 0.5 : units;
      if (n > maxUnits) return null;
      return '${fmt(n, n % 1 == 0 ? 0 : 1)} $unit${n > 1 ? 's' : ''}';
    }
    final rounded = (qty / 5).round() * 5;
    return '${rounded < 5 ? 5 : rounded} $unit $name';
  }
}

const referenceFoods = <ReferenceFood>[
  // Proteína
  ReferenceFood('pechuga de pollo cocida', MacroGroup.protein, 31,
      tags: {FoodTag.meat}),
  ReferenceFood('posta o lomo de vacuno cocido', MacroGroup.protein, 28,
      tags: {FoodTag.meat}),
  ReferenceFood('atún al agua escurrido', MacroGroup.protein, 26,
      tags: {FoodTag.fish}),
  ReferenceFood('merluza o reineta cocida', MacroGroup.protein, 20,
      tags: {FoodTag.fish}),
  ReferenceFood('camarones cocidos', MacroGroup.protein, 24,
      tags: {FoodTag.shellfish}),
  ReferenceFood('huevo', MacroGroup.protein, 12.6,
      tags: {FoodTag.egg}, unit: 'huevo', unitGrams: 50),
  ReferenceFood('claras de huevo', MacroGroup.protein, 11,
      tags: {FoodTag.egg}),
  ReferenceFood('yogur griego natural sin azúcar', MacroGroup.protein, 9,
      tags: {FoodTag.dairy}),
  ReferenceFood('quesillo', MacroGroup.protein, 13, tags: {FoodTag.dairy}),
  ReferenceFood('tofu firme', MacroGroup.protein, 15, tags: {FoodTag.soy}),
  ReferenceFood('tempeh', MacroGroup.protein, 19, tags: {FoodTag.soy}),
  ReferenceFood('seitán', MacroGroup.protein, 25, tags: {FoodTag.gluten}),
  // Carbohidratos
  ReferenceFood('arroz cocido', MacroGroup.carb, 28),
  ReferenceFood('papa cocida', MacroGroup.carb, 20),
  ReferenceFood('legumbres cocidas (lentejas, porotos, garbanzos)',
      MacroGroup.carb, 20),
  ReferenceFood('quinoa cocida', MacroGroup.carb, 21),
  ReferenceFood('arepa o tortilla de maíz', MacroGroup.carb, 45),
  ReferenceFood('avena cruda', MacroGroup.carb, 66, tags: {FoodTag.gluten}),
  ReferenceFood('pan integral', MacroGroup.carb, 41, tags: {FoodTag.gluten}),
  ReferenceFood('pasta cocida', MacroGroup.carb, 25, tags: {FoodTag.gluten}),
  ReferenceFood('plátano', MacroGroup.carb, 23,
      unit: 'plátano', unitGrams: 120),
  ReferenceFood('manzana', MacroGroup.carb, 14,
      unit: 'manzana', unitGrams: 180),
  // Grasas
  ReferenceFood('palta', MacroGroup.fat, 15),
  ReferenceFood('aceite de oliva', MacroGroup.fat, 92, unit: 'ml'),
  ReferenceFood('almendras', MacroGroup.fat, 50, tags: {FoodTag.treeNuts}),
  ReferenceFood('maní sin sal', MacroGroup.fat, 49, tags: {FoodTag.peanut}),
  ReferenceFood('semillas de chía', MacroGroup.fat, 31),
  ReferenceFood('queso fresco o gauda', MacroGroup.fat, 27,
      tags: {FoodTag.dairy}),
];

Set<FoodTag> _excludedTags(Questionnaire q) {
  final out = <FoodTag>{};
  switch (q.dietPattern) {
    case DietPattern.omnivore:
      break;
    case DietPattern.pescatarian:
      out.add(FoodTag.meat);
    case DietPattern.vegetarian:
      out.addAll({FoodTag.meat, FoodTag.fish, FoodTag.shellfish});
    case DietPattern.vegan:
      out.addAll({
        FoodTag.meat,
        FoodTag.fish,
        FoodTag.shellfish,
        FoodTag.egg,
        FoodTag.dairy,
      });
  }
  for (final a in q.allergies) {
    out.add(switch (a) {
      Allergy.gluten => FoodTag.gluten,
      Allergy.lactose => FoodTag.dairy,
      Allergy.peanut => FoodTag.peanut,
      Allergy.treeNuts => FoodTag.treeNuts,
      Allergy.egg => FoodTag.egg,
      Allergy.fish => FoodTag.fish,
      Allergy.shellfish => FoodTag.shellfish,
      Allergy.soy => FoodTag.soy,
    });
  }
  return out;
}

String _plain(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

/// Alimentos permitidos para el usuario en un grupo: sin lo que su dieta o
/// alergias excluyen, ni lo que dijo que no le gusta.
List<ReferenceFood> allowedFoods(Questionnaire q, MacroGroup group) {
  final excluded = _excludedTags(q);
  final dislikes = _plain(q.dislikedFoods)
      .split(RegExp(r'[,;\n]| y '))
      .map((w) => w.trim())
      .where((w) => w.length >= 3)
      .toList();
  return [
    for (final f in referenceFoods)
      if (f.group == group &&
          f.tags.intersection(excluded).isEmpty &&
          !dislikes.any((d) => _plain(f.name).contains(d)))
        f,
  ];
}
