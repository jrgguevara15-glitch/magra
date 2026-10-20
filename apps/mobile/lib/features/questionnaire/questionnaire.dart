import 'package:flutter/material.dart' show TimeOfDay;

/// Una opción del cuestionario: código para la base de datos y texto visible.
abstract interface class Choice {
  String get code;
  String get label;
}

T _parse<T extends Choice>(List<T> values, Object? code, T fallback) {
  for (final v in values) {
    if (v.code == code) return v;
  }
  return fallback;
}

List<T> _parseList<T extends Choice>(List<T> values, Object? codes) => [
      for (final c in (codes as List? ?? const []))
        for (final v in values)
          if (v.code == c) v,
    ];

enum WorkSchedule implements Choice {
  day('day', 'Diurno'),
  night('night', 'Nocturno'),
  shifts('shifts', 'Turnos rotativos'),
  flexible('flexible', 'Flexible o desde casa'),
  none('none', 'No trabajo / estudio');

  const WorkSchedule(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum TrainingTime implements Choice {
  early('early', 'Muy temprano (antes de 7:00)'),
  morning('morning', 'Mañana (7:00–11:00)'),
  midday('midday', 'Mediodía (11:00–14:00)'),
  afternoon('afternoon', 'Tarde (14:00–18:00)'),
  evening('evening', 'Noche (después de 18:00)'),
  varies('varies', 'Varía');

  const TrainingTime(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Experience implements Choice {
  none('none', 'Nunca he entrenado'),
  beginner('beginner', 'Principiante (menos de 6 meses)'),
  intermediate('intermediate', 'Intermedio (6 meses a 2 años)'),
  advanced('advanced', 'Avanzado (más de 2 años)');

  const Experience(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Equipment implements Choice {
  gym('gym', 'Gimnasio'),
  homeWeights('home_weights', 'Casa con mancuernas o bandas'),
  bodyweight('bodyweight', 'Solo peso corporal');

  const Equipment(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Injury implements Choice {
  knee('knee', 'Rodillas'),
  lowerBack('lower_back', 'Espalda baja'),
  shoulder('shoulder', 'Hombros'),
  hip('hip', 'Caderas'),
  ankle('ankle', 'Tobillos'),
  wrist('wrist', 'Muñecas'),
  neck('neck', 'Cuello');

  const Injury(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum HealthCondition implements Choice {
  type1Diabetes('type1_diabetes', 'Diabetes tipo 1', supervised: true),
  type2Diabetes('type2_diabetes', 'Diabetes tipo 2'),
  prediabetes('prediabetes', 'Prediabetes o resistencia a la insulina'),
  hypertension('hypertension', 'Presión alta'),
  hypoglycemia('hypoglycemia', 'Hipoglicemias frecuentes'),
  hypothyroidism('hypothyroidism', 'Hipotiroidismo'),
  heartDisease('heart_disease', 'Enfermedad del corazón', supervised: true),
  kidneyDisease('kidney_disease', 'Enfermedad renal', supervised: true),
  pregnancy('pregnancy', 'Embarazo', supervised: true),
  breastfeeding('breastfeeding', 'Lactancia', supervised: true),
  eatingDisorder('eating_disorder',
      'Trastorno de la conducta alimentaria (actual o pasado)',
      supervised: true);

  const HealthCondition(this.code, this.label, {this.supervised = false});
  @override
  final String code;
  @override
  final String label;

  /// Requiere que un profesional de salud guíe el plan: MAGRA no debe
  /// indicar un déficit por su cuenta.
  final bool supervised;
}

enum DietPattern implements Choice {
  omnivore('omnivore', 'Como de todo'),
  pescatarian('pescatarian', 'Pescetariano (pescado, sin carnes)'),
  vegetarian('vegetarian', 'Vegetariano'),
  vegan('vegan', 'Vegano');

  const DietPattern(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Allergy implements Choice {
  gluten('gluten', 'Gluten / celiaquía'),
  lactose('lactose', 'Lactosa'),
  peanut('peanut', 'Maní'),
  treeNuts('tree_nuts', 'Frutos secos'),
  egg('egg', 'Huevo'),
  fish('fish', 'Pescado'),
  shellfish('shellfish', 'Mariscos'),
  soy('soy', 'Soya');

  const Allergy(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Fasting implements Choice {
  no('no', 'No quiero ayunar'),
  open('open', 'Que MAGRA decida'),
  yes('yes', 'Me gustaría ayunar');

  const Fasting(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Cooking implements Choice {
  daily('daily', 'Cocino todos los días'),
  batch('batch', 'Cocino algunos días y guardo'),
  rarely('rarely', 'Casi no cocino');

  const Cooking(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

enum Budget implements Choice {
  low('low', 'Ajustado'),
  medium('medium', 'Medio'),
  high('high', 'Holgado');

  const Budget(this.code, this.label);
  @override
  final String code;
  @override
  final String label;
}

String _time(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(Object? v) {
  final parts = (v as String? ?? '07:00').split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Respuestas del cuestionario: lo que MAGRA necesita para recomendar.
class Questionnaire {
  const Questionnaire({
    required this.wakeTime,
    required this.sleepTime,
    required this.workSchedule,
    required this.trainingDays,
    required this.sessionMinutes,
    required this.trainingTime,
    required this.experience,
    required this.equipment,
    this.injuries = const [],
    this.healthConditions = const [],
    this.healthNotes = '',
    required this.dietPattern,
    this.allergies = const [],
    this.dislikedFoods = '',
    this.preferredMeals,
    required this.fasting,
    required this.cooking,
    required this.budget,
  });

  /// Respuestas iniciales razonables para empezar el formulario.
  static const initial = Questionnaire(
    wakeTime: TimeOfDay(hour: 7, minute: 0),
    sleepTime: TimeOfDay(hour: 23, minute: 0),
    workSchedule: WorkSchedule.day,
    trainingDays: 3,
    sessionMinutes: 60,
    trainingTime: TrainingTime.afternoon,
    experience: Experience.beginner,
    equipment: Equipment.gym,
    dietPattern: DietPattern.omnivore,
    fasting: Fasting.open,
    cooking: Cooking.daily,
    budget: Budget.medium,
  );

  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;
  final WorkSchedule workSchedule;
  final int trainingDays;
  final int sessionMinutes;
  final TrainingTime trainingTime;
  final Experience experience;
  final Equipment equipment;
  final List<Injury> injuries;
  final List<HealthCondition> healthConditions;
  final String healthNotes;
  final DietPattern dietPattern;
  final List<Allergy> allergies;
  final String dislikedFoods;

  /// Cuántas veces al día prefiere comer; `null` = que MAGRA decida.
  final int? preferredMeals;
  final Fasting fasting;
  final Cooking cooking;
  final Budget budget;

  /// Horas despierto, aunque se acueste después de medianoche.
  double get awakeHours {
    final wake = wakeTime.hour * 60 + wakeTime.minute;
    var sleep = sleepTime.hour * 60 + sleepTime.minute;
    if (sleep <= wake) sleep += 24 * 60;
    return (sleep - wake) / 60;
  }

  /// Alguna condición pide que el plan lo guíe un profesional de salud.
  bool get needsProfessionalSupervision =>
      healthConditions.any((c) => c.supervised);

  Questionnaire copyWith({
    TimeOfDay? wakeTime,
    TimeOfDay? sleepTime,
    WorkSchedule? workSchedule,
    int? trainingDays,
    int? sessionMinutes,
    TrainingTime? trainingTime,
    Experience? experience,
    Equipment? equipment,
    List<Injury>? injuries,
    List<HealthCondition>? healthConditions,
    String? healthNotes,
    DietPattern? dietPattern,
    List<Allergy>? allergies,
    String? dislikedFoods,
    int? Function()? preferredMeals,
    Fasting? fasting,
    Cooking? cooking,
    Budget? budget,
  }) =>
      Questionnaire(
        wakeTime: wakeTime ?? this.wakeTime,
        sleepTime: sleepTime ?? this.sleepTime,
        workSchedule: workSchedule ?? this.workSchedule,
        trainingDays: trainingDays ?? this.trainingDays,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        trainingTime: trainingTime ?? this.trainingTime,
        experience: experience ?? this.experience,
        equipment: equipment ?? this.equipment,
        injuries: injuries ?? this.injuries,
        healthConditions: healthConditions ?? this.healthConditions,
        healthNotes: healthNotes ?? this.healthNotes,
        dietPattern: dietPattern ?? this.dietPattern,
        allergies: allergies ?? this.allergies,
        dislikedFoods: dislikedFoods ?? this.dislikedFoods,
        preferredMeals:
            preferredMeals == null ? this.preferredMeals : preferredMeals(),
        fasting: fasting ?? this.fasting,
        cooking: cooking ?? this.cooking,
        budget: budget ?? this.budget,
      );

  factory Questionnaire.fromRow(Map<String, dynamic> row) => Questionnaire(
        wakeTime: _parseTime(row['wake_time']),
        sleepTime: _parseTime(row['sleep_time']),
        workSchedule:
            _parse(WorkSchedule.values, row['work_schedule'], WorkSchedule.day),
        trainingDays: (row['training_days'] as num).toInt(),
        sessionMinutes: (row['session_minutes'] as num).toInt(),
        trainingTime: _parse(
            TrainingTime.values, row['training_time'], TrainingTime.varies),
        experience:
            _parse(Experience.values, row['experience'], Experience.beginner),
        equipment: _parse(Equipment.values, row['equipment'], Equipment.gym),
        injuries: _parseList(Injury.values, row['injuries']),
        healthConditions:
            _parseList(HealthCondition.values, row['health_conditions']),
        healthNotes: row['health_notes'] as String? ?? '',
        dietPattern: _parse(
            DietPattern.values, row['diet_pattern'], DietPattern.omnivore),
        allergies: _parseList(Allergy.values, row['allergies']),
        dislikedFoods: row['disliked_foods'] as String? ?? '',
        preferredMeals: (row['preferred_meals'] as num?)?.toInt(),
        fasting: _parse(Fasting.values, row['fasting'], Fasting.open),
        cooking: _parse(Cooking.values, row['cooking'], Cooking.daily),
        budget: _parse(Budget.values, row['budget'], Budget.medium),
      );

  Map<String, dynamic> toRow() => {
        'wake_time': _time(wakeTime),
        'sleep_time': _time(sleepTime),
        'work_schedule': workSchedule.code,
        'training_days': trainingDays,
        'session_minutes': sessionMinutes,
        'training_time': trainingTime.code,
        'experience': experience.code,
        'equipment': equipment.code,
        'injuries': [for (final i in injuries) i.code],
        'health_conditions': [for (final c in healthConditions) c.code],
        'health_notes': healthNotes,
        'diet_pattern': dietPattern.code,
        'allergies': [for (final a in allergies) a.code],
        'disliked_foods': dislikedFoods,
        'preferred_meals': preferredMeals,
        'fasting': fasting.code,
        'cooking': cooking.code,
        'budget': budget.code,
      };
}
