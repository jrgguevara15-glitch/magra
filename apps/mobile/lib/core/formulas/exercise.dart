/// Actividad física con su MET (Compendio de Actividad Física).
class Activity {
  const Activity(this.id, this.name, this.met);

  final String id;
  final String name;
  final double met;
}

const activities = <Activity>[
  Activity('pesas_mod', 'Pesas / fuerza moderada', 3.5),
  Activity('pesas_vig', 'Pesas intensas / circuito', 6.0),
  Activity('caminar_5', 'Caminar 5 km/h', 3.5),
  Activity('caminar_6', 'Caminar rápido 6,4 km/h', 5.0),
  Activity('cinta_incl', 'Caminata en cinta inclinada', 6.0),
  Activity('bici_mod', 'Bicicleta estática moderada', 6.8),
  Activity('bici_vig', 'Bicicleta estática intensa', 8.8),
  Activity('eliptica', 'Elíptica moderada', 5.0),
  Activity('remo', 'Remo ergómetro moderado', 7.0),
  Activity('trote', 'Trotar 8 km/h', 8.3),
  Activity('correr', 'Correr 10 km/h', 9.8),
  Activity('futbol_rec', 'Fútbol recreativo / pichanga', 7.0),
  Activity('futbol_comp', 'Fútbol partido competitivo', 10.0),
  Activity('padel', 'Pádel / tenis dobles', 6.0),
  Activity('natacion', 'Natación moderada', 5.8),
  Activity('hiit', 'HIIT / funcional', 8.0),
  Activity('baile', 'Baile / zumba', 5.5),
  Activity('yoga', 'Yoga / movilidad', 2.5),
];

Activity? activityById(String id) {
  for (final a in activities) {
    if (a.id == id) return a;
  }
  return null;
}

/// Calorías brutas: MET × peso × horas.
double grossBurnKcal(Activity activity, double minutes, double weightKg) =>
    activity.met * weightKg * minutes / 60;

/// Calorías netas: (MET − 1) × peso × horas. El reposo ya está en la TMB.
double netBurnKcal(Activity activity, double minutes, double weightKg) {
  final net = (activity.met - 1) * weightKg * minutes / 60;
  return net < 0 ? 0 : net;
}

/// Parte del ejercicio que se puede volver a comer.
const double exerciseEatBackShare = 0.5;

double exerciseBonusKcal(double netBurnedKcal) =>
    netBurnedKcal * exerciseEatBackShare;

/// Frecuencia cardíaca máxima estimada (Tanaka).
double maxHeartRate(int age) => 208 - 0.7 * age;

/// Zona 2 de cardio: 60–70 % de la FC máxima, en pulsaciones por minuto.
(int, int) zone2HeartRate(int age) {
  final max = maxHeartRate(age);
  return ((max * 0.6).round(), (max * 0.7).round());
}
