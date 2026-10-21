import '../../features/questionnaire/questionnaire.dart';
import 'training_plan.dart';

/// Un ejercicio de calentamiento o estiramiento, por tiempo o por
/// repeticiones. Las fotos son de Free Exercise DB (dominio público).
class Drill {
  const Drill(
    this.name, {
    this.imageId,
    this.seconds,
    this.reps,
    this.perSide = false,
    required this.cue,
  });

  final String name;
  final String? imageId;

  /// Duración (por lado si [perSide]); `null` si va por repeticiones.
  final int? seconds;
  final int? reps;
  final bool perSide;

  /// Cómo hacerlo, en una o dos frases.
  final String cue;

  List<String> get images => imageId == null
      ? const []
      : ['assets/exercises/${imageId}__0.jpg', 'assets/exercises/${imageId}__1.jpg'];

  /// Lo que dura en total (las repeticiones se estiman en 3 s cada una).
  int get totalSeconds => (seconds ?? (reps ?? 0) * 3) * (perSide ? 2 : 1);

  String get dose => seconds != null
      ? '$seconds s${perSide ? ' por lado' : ''}'
      : '$reps repeticiones${perSide ? ' por lado' : ''}';
}

/// Qué entrena la sesión.
enum SessionFocus { full, upper, lower }

SessionFocus focusOf(TrainingDay day) => switch (day.title) {
      'Tren superior' => SessionFocus.upper,
      'Tren inferior' => SessionFocus.lower,
      _ => SessionFocus.full,
    };

int routineMinutes(List<Drill> drills) =>
    (drills.fold<int>(0, (a, d) => a + d.totalSeconds) / 60).ceil();

/// Calentamiento de 5–8 minutos: activación general, movilidad dinámica
/// de lo que se va a entrenar y series de aproximación.
List<Drill> warmUp({
  required SessionFocus focus,
  required Questionnaire questionnaire,
  required bool lowImpact,
}) {
  final q = questionnaire;
  final injured = q.injuries.toSet();
  final gym = q.equipment == Equipment.gym;
  final lower = focus != SessionFocus.upper;
  final upper = focus != SessionFocus.lower;
  final soft = lowImpact ||
      injured.contains(Injury.knee) ||
      injured.contains(Injury.ankle) ||
      injured.contains(Injury.hip);

  return [
    Drill(
      soft
          ? (gym ? 'Bicicleta o elíptica suave' : 'Caminata rápida o marcha en el lugar')
          : (gym ? 'Bicicleta, remo o trote suave' : 'Trote suave en el lugar'),
      seconds: 150,
      cue: 'Ritmo cómodo: que puedas hablar. Sube de a poco la temperatura del cuerpo.',
    ),
    const Drill('Círculos de brazos', imageId: 'Arm_Circles', seconds: 30,
        cue: 'Brazos estirados a los lados, círculos pequeños que se agrandan; cambia de sentido a la mitad.'),
    const Drill('Rotación de tronco', imageId: 'Torso_Rotation', seconds: 30,
        cue: 'Pies fijos, gira el tronco a un lado y al otro de forma controlada.'),
    if (!injured.contains(Injury.wrist))
      const Drill('Gato-vaca', imageId: 'Cat_Stretch', reps: 8,
          cue: 'En cuatro apoyos, redondea la espalda y luego arquéala suave, siguiendo la respiración.'),
    if (lower) ...[
      const Drill('Círculos de cadera', imageId: 'Standing_Hip_Circles', seconds: 30,
          cue: 'Manos en la cintura, dibuja círculos amplios con la cadera; cambia de sentido.'),
      const Drill('Círculos de tobillos', imageId: 'Ankle_Circles', seconds: 15, perSide: true,
          cue: 'Apoyado en una pierna (o sentado), gira el tobillo en ambos sentidos.'),
      if (!injured.contains(Injury.knee) && !injured.contains(Injury.hip))
        const Drill('El mejor estiramiento del mundo', imageId: 'Worlds_Greatest_Stretch',
            reps: 4, perSide: true,
            cue: 'Zancada larga, mano al suelo por dentro del pie y gira el pecho con el otro brazo al techo.'),
      if (injured.contains(Injury.knee))
        const Drill('Puente de glúteo', imageId: 'Butt_Lift_Bridge', reps: 12,
            cue: 'Activa glúteos sin cargar la rodilla: sube la cadera y aprieta arriba.')
      else ...[
        const Drill('Sentadillas sin peso', imageId: 'Bodyweight_Squat', reps: 10,
            cue: 'Lento y profundo hasta donde estés cómodo, talones apoyados.'),
        const Drill('Puente de glúteo', imageId: 'Butt_Lift_Bridge', reps: 10,
            cue: 'Sube la cadera y aprieta los glúteos 1 segundo arriba.'),
      ],
    ],
    if (upper) ...[
      if (!injured.contains(Injury.shoulder) && !injured.contains(Injury.neck))
        const Drill('Círculos de hombros', imageId: 'Shoulder_Circles', seconds: 30,
            cue: 'Sube los hombros a las orejas y gíralos hacia atrás, amplio y lento.'),
      Drill(
        q.equipment == Equipment.bodyweight ? 'Apertura de brazos (sin banda)' : 'Separación con banda',
        imageId: 'Band_Pull_Apart',
        reps: 15,
        cue: q.equipment == Equipment.bodyweight
            ? 'Brazos al frente, ábrelos juntando los omóplatos atrás (la foto usa banda).'
            : 'Banda al frente a la altura del pecho, sepárala juntando los omóplatos.',
      ),
      if (!injured.contains(Injury.shoulder) && !injured.contains(Injury.wrist))
        const Drill('Flexiones inclinadas', imageId: 'Incline_Push-Up', reps: 8,
            cue: 'Manos en un banco o pared, cuerpo recto, baja y sube controlado.'),
    ],
    const Drill('Series de aproximación', seconds: 60,
        cue: 'En tu primer ejercicio haz 1–2 series livianas (≈50 % y 70 % del peso) de 6–8 '
            'repeticiones antes de las series de trabajo.'),
  ];
}

/// Vuelta a la calma de 5–7 minutos: estiramientos estáticos de lo que se
/// entrenó (30 s, sin rebotes) y respiración.
List<Drill> coolDown({
  required SessionFocus focus,
  required Questionnaire questionnaire,
}) {
  final injured = questionnaire.injuries.toSet();
  final lower = focus != SessionFocus.upper;
  final upper = focus != SessionFocus.lower;
  return [
    if (lower) ...[
      if (!injured.contains(Injury.knee))
        const Drill('Estiramiento de cuádriceps', imageId: 'Quad_Stretch', seconds: 30, perSide: true,
            cue: 'De pie, lleva el talón al glúteo tomándolo con la mano; rodillas juntas, apóyate si hace falta.'),
      const Drill('Estiramiento de isquiotibiales', imageId: 'Hamstring_Stretch', seconds: 30, perSide: true,
          cue: 'Pierna estirada al frente, inclínate desde la cadera con la espalda recta hasta sentir tensión.'),
      if (injured.contains(Injury.knee))
        const Drill('Rodilla al pecho', imageId: 'One_Knee_To_Chest', seconds: 30, perSide: true,
            cue: 'Acostado, abraza una rodilla hacia el pecho y relaja la espalda baja.')
      else
        const Drill('Flexor de cadera de rodillas', imageId: 'Kneeling_Hip_Flexor', seconds: 30, perSide: true,
            cue: 'Una rodilla en el suelo (sobre un cojín), lleva la cadera adelante y aprieta el glúteo de atrás.'),
      const Drill('Glúteo y espalda baja', imageId: 'Knee_Across_The_Body', seconds: 30, perSide: true,
          cue: 'Acostado, cruza la rodilla al lado contrario manteniendo los hombros apoyados.'),
      if (focus == SessionFocus.lower)
        const Drill('Pantorrillas en la pared', imageId: 'Calf_Stretch_Hands_Against_Wall', seconds: 30,
            perSide: true, cue: 'Manos en la pared, pierna de atrás estirada y talón apoyado.'),
    ],
    if (upper) ...[
      if (!injured.contains(Injury.shoulder))
        Drill('Pecho y hombro', imageId: 'Chest_And_Front_Of_Shoulder_Stretch', seconds: 30,
            perSide: focus == SessionFocus.upper,
            cue: 'Brazo apoyado en un marco de puerta, gira el cuerpo suave al lado contrario.'),
      const Drill('Hombro cruzado', imageId: 'Shoulder_Stretch', seconds: 30, perSide: true,
          cue: 'Lleva un brazo cruzado al pecho y presiónalo suave con el otro.'),
      if (!injured.contains(Injury.knee))
        const Drill('Postura del niño', imageId: 'Childs_Pose', seconds: 45,
            cue: 'De rodillas, siéntate en los talones y estira los brazos al frente; respira hacia la espalda.'),
    ],
    const Drill('Respiración para bajar pulsaciones', seconds: 60,
        cue: 'Inhala 4 segundos por la nariz y exhala 6 por la boca. Bebe agua.'),
  ];
}
