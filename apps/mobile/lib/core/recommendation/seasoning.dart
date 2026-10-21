import '../../features/questionnaire/questionnaire.dart';

/// Grasas saludables recomendadas con su porción casera, sin las que
/// excluyen sus alergias.
List<String> healthyFatTips(Questionnaire q) {
  final allergies = q.allergies.toSet();
  return [
    'Aceite de oliva extra virgen o de canola: 1 cdta (5 ml) por plato, '
        'mejor en crudo o en salteado corto.',
    'Palta: 1/4 de unidad (≈ 40 g) en ensaladas, tostadas o como base de salsas.',
    if (!allergies.contains(Allergy.treeNuts))
      'Nueces o almendras: 1 puñado chico (15 g) como colación.',
    if (!allergies.contains(Allergy.peanut))
      'Mantequilla de maní sin azúcar: 1 cdta (8 g).',
    'Semillas de chía, linaza o sésamo: 1 cda (10 g) sobre '
        '${allergies.contains(Allergy.lactose) || q.dietPattern == DietPattern.vegan ? '' : 'yogur, '}'
        'avena o ensaladas.',
    if (!allergies.contains(Allergy.fish) && q.dietPattern != DietPattern.vegetarian &&
        q.dietPattern != DietPattern.vegan)
      'Pescados grasos (salmón, jurel, sardina) 2 veces por semana: omega 3.',
  ];
}

/// Condimentos que dan sabor sin calorías ni exceso de sal, según lo que
/// come la persona.
List<String> seasoningTipsFor(Questionnaire q) {
  final base = switch (q.dietPattern) {
    DietPattern.omnivore => 'carnes, pollo y legumbres',
    DietPattern.pescatarian => 'pescados, huevos y legumbres',
    DietPattern.vegetarian => 'legumbres, huevos y tofu',
    DietPattern.vegan => 'legumbres, tofu y verduras asadas',
  };
  final fresh = switch (q.dietPattern) {
    DietPattern.vegetarian || DietPattern.vegan => 'ensaladas y legumbres',
    _ => 'pescados y ensaladas',
  };
  return [
    'Ajo, comino, orégano y pimentón para $base.',
    'Merkén o ají de color para dar sabor chileno sin grasa extra.',
    'Limón, cilantro y perejil frescos para $fresh.',
    'Cúrcuma, jengibre y pimienta para salteados y cremas de verduras.',
    'Evita margarina, frituras, cubitos de caldo y salsas industriales; usa poca sal.',
  ];
}
