/// Fichas de los ejercicios: cómo se hacen, con qué equipo, qué músculos
/// trabajan y errores comunes. Las imágenes vienen de Free Exercise DB
/// (dominio público, Unlicense): dos fotos por movimiento (inicio y fin),
/// en `assets/exercises/<id>__0.jpg` y `__1.jpg`.
library;

/// Un movimiento con sus fotos.
class GuideMove {
  const GuideMove({
    required this.name,
    this.imageId,
    required this.equipment,
    required this.muscles,
    required this.steps,
    required this.mistakes,
    this.note,
  });

  final String name;

  /// Id en Free Exercise DB; `null` si no hay foto.
  final String? imageId;
  final String equipment;
  final List<String> muscles;
  final List<String> steps;
  final List<String> mistakes;

  /// Aclaración (p. ej. "la foto muestra mancuernas").
  final String? note;

  List<String> get images => imageId == null
      ? const []
      : ['assets/exercises/${imageId}__0.jpg', 'assets/exercises/${imageId}__1.jpg'];
}

const imageCredit = 'Imágenes: Free Exercise DB (dominio público).';

const _squatBarbell = GuideMove(
  name: 'Sentadilla con barra',
  imageId: 'Barbell_Squat',
  equipment: 'Barra olímpica, rack de sentadillas y discos',
  muscles: ['Cuádriceps', 'Glúteos', 'Aductores', 'Core'],
  steps: [
    'Barra sobre la parte alta de la espalda (no en el cuello), manos firmes y codos abajo.',
    'Pies al ancho de hombros, puntas un poco hacia afuera.',
    'Baja empujando la cadera atrás y doblando rodillas, pecho arriba, hasta que el muslo quede paralelo o lo que permita tu movilidad.',
    'Sube empujando el suelo con todo el pie, exhalando al final.',
  ],
  mistakes: [
    'Rodillas que se van hacia adentro.',
    'Levantar los talones o redondear la espalda baja.',
    'Bajar sin control o rebotar abajo.',
  ],
);

const _legPress = GuideMove(
  name: 'Prensa de piernas',
  imageId: 'Leg_Press',
  equipment: 'Máquina de prensa de piernas',
  muscles: ['Cuádriceps', 'Glúteos', 'Isquiotibiales'],
  steps: [
    'Espalda y cadera apoyadas en el respaldo, pies al ancho de caderas al centro de la plataforma.',
    'Quita los seguros y baja la plataforma doblando las rodillas hacia el pecho.',
    'Baja hasta donde la cadera no se despegue del asiento.',
    'Empuja con todo el pie sin bloquear las rodillas arriba.',
  ],
  mistakes: [
    'Despegar la cadera del asiento al bajar mucho.',
    'Bloquear las rodillas de golpe arriba.',
    'Empujar solo con la punta de los pies.',
  ],
);

const _goblet = GuideMove(
  name: 'Sentadilla goblet',
  imageId: 'Goblet_Squat',
  equipment: 'Una mancuerna o kettlebell',
  muscles: ['Cuádriceps', 'Glúteos', 'Core'],
  steps: [
    'Toma la mancuerna vertical contra el pecho, codos abajo.',
    'Pies un poco más abiertos que los hombros.',
    'Baja entre las piernas con el pecho alto, codos por dentro de las rodillas.',
    'Sube empujando el suelo y aprieta glúteos arriba.',
  ],
  mistakes: [
    'Alejar el peso del pecho.',
    'Encorvar la espalda al bajar.',
    'Rodillas hacia adentro.',
  ],
);

const _bwSquat = GuideMove(
  name: 'Sentadilla con peso corporal',
  imageId: 'Bodyweight_Squat',
  equipment: 'Sin equipo',
  muscles: ['Cuádriceps', 'Glúteos'],
  steps: [
    'Pies al ancho de hombros, brazos al frente para equilibrarte.',
    'Baja llevando la cadera atrás y abajo, como para sentarte.',
    'Mantén talones apoyados y pecho arriba.',
    'Sube a velocidad controlada.',
  ],
  mistakes: [
    'Rodillas hacia adentro.',
    'Levantar los talones.',
  ],
);

const _boxSquat = GuideMove(
  name: 'Sentadilla a un cajón',
  imageId: 'Dumbbell_Squat_To_A_Bench',
  equipment: 'Banco o cajón firme (mancuernas opcionales)',
  muscles: ['Cuádriceps', 'Glúteos'],
  steps: [
    'Párate delante del banco, pies al ancho de hombros.',
    'Baja controlado hasta tocar el banco con los glúteos, sin dejarte caer.',
    'Sube de inmediato empujando el suelo.',
    'Usa un cajón alto si tienes molestias de rodilla: el rango sin dolor manda.',
  ],
  mistakes: [
    'Sentarse y relajarse sobre el banco.',
    'Inclinar demasiado el torso.',
  ],
);

const _rdlBarbell = GuideMove(
  name: 'Peso muerto rumano con barra',
  imageId: 'Romanian_Deadlift',
  equipment: 'Barra y discos',
  muscles: ['Isquiotibiales', 'Glúteos', 'Espalda baja'],
  steps: [
    'De pie con la barra a la altura de los muslos, rodillas apenas dobladas.',
    'Lleva la cadera atrás deslizando la barra pegada a las piernas.',
    'Baja hasta sentir estiramiento atrás del muslo, espalda recta.',
    'Sube apretando glúteos hasta quedar erguido.',
  ],
  mistakes: [
    'Redondear la espalda.',
    'Alejar la barra de las piernas.',
    'Doblar mucho las rodillas (se vuelve sentadilla).',
  ],
);

const _rdlDumbbell = GuideMove(
  name: 'Peso muerto rumano con mancuernas',
  imageId: 'Stiff-Legged_Dumbbell_Deadlift',
  equipment: 'Dos mancuernas',
  muscles: ['Isquiotibiales', 'Glúteos', 'Espalda baja'],
  steps: [
    'Mancuernas frente a los muslos, rodillas suaves.',
    'Lleva la cadera atrás, mancuernas cerca de las piernas.',
    'Baja hasta media canilla o donde mantengas la espalda recta.',
    'Sube empujando la cadera adelante.',
  ],
  mistakes: [
    'Mirar arriba y arquear el cuello.',
    'Perder la curva natural de la espalda.',
  ],
);

const _slBridge = GuideMove(
  name: 'Puente de glúteo a una pierna',
  imageId: 'Single_Leg_Glute_Bridge',
  equipment: 'Sin equipo (colchoneta)',
  muscles: ['Glúteos', 'Isquiotibiales'],
  steps: [
    'Acostado boca arriba, una rodilla doblada y la otra pierna estirada.',
    'Empuja con el talón apoyado y sube la cadera.',
    'Arriba, hombros-cadera-rodilla en línea; aprieta el glúteo 1 segundo.',
    'Baja controlado y repite; cambia de pierna.',
  ],
  mistakes: [
    'Arquear la espalda baja en vez de usar el glúteo.',
    'Dejar caer la cadera hacia un lado.',
  ],
);

const _bridge = GuideMove(
  name: 'Puente de glúteo',
  imageId: 'Butt_Lift_Bridge',
  equipment: 'Sin equipo (colchoneta)',
  muscles: ['Glúteos', 'Isquiotibiales'],
  steps: [
    'Boca arriba, rodillas dobladas, pies apoyados al ancho de caderas.',
    'Empuja con los talones y sube la cadera.',
    'Aprieta los glúteos arriba 1–2 segundos.',
    'Baja sin apoyar del todo y repite.',
  ],
  mistakes: [
    'Empujar con la espalda baja.',
    'Separar las rodillas hacia afuera.',
  ],
);

const _hipThrust = GuideMove(
  name: 'Hip thrust',
  imageId: 'Barbell_Hip_Thrust',
  equipment: 'Banco y barra con protector (o una mancuerna)',
  muscles: ['Glúteos', 'Isquiotibiales'],
  steps: [
    'Espalda alta apoyada en el banco, barra sobre la cadera.',
    'Pies apoyados, rodillas a 90° arriba.',
    'Sube la cadera hasta quedar en línea con hombros y rodillas, mentón al pecho.',
    'Baja controlado.',
  ],
  mistakes: [
    'Arquear la espalda al subir.',
    'Pies demasiado lejos o cerca (rodillas lejos de 90°).',
  ],
);

const _lungeDumbbell = GuideMove(
  name: 'Zancada con mancuernas',
  imageId: 'Dumbbell_Lunges',
  equipment: 'Dos mancuernas',
  muscles: ['Cuádriceps', 'Glúteos'],
  steps: [
    'De pie, una mancuerna en cada mano.',
    'Da un paso largo al frente y baja la rodilla de atrás cerca del suelo.',
    'Rodilla de adelante sobre el pie, torso erguido.',
    'Empuja con el pie de adelante para volver y cambia de pierna.',
  ],
  mistakes: [
    'Paso muy corto (la rodilla se va muy adelante).',
    'Inclinar el torso o perder el equilibrio.',
  ],
);

const _rearLungeDumbbell = GuideMove(
  name: 'Zancada hacia atrás con mancuernas',
  imageId: 'Dumbbell_Rear_Lunge',
  equipment: 'Dos mancuernas',
  muscles: ['Glúteos', 'Cuádriceps'],
  steps: [
    'De pie con mancuernas a los lados.',
    'Da un paso atrás y baja la rodilla de atrás hacia el suelo.',
    'El peso queda en el pie de adelante.',
    'Vuelve empujando con el pie de adelante.',
  ],
  mistakes: [
    'Apoyarse en la pierna de atrás.',
    'Rodilla de adelante hacia adentro.',
  ],
);

const _rearLungeBodyweight = GuideMove(
  name: 'Zancada hacia atrás',
  imageId: 'Dumbbell_Rear_Lunge',
  equipment: 'Sin equipo',
  note: 'La foto muestra mancuernas; hazla sin peso.',
  muscles: ['Glúteos', 'Cuádriceps'],
  steps: [
    'De pie, manos en la cintura.',
    'Paso atrás y baja la rodilla de atrás hacia el suelo.',
    'Torso erguido, peso en el pie de adelante.',
    'Vuelve empujando con el pie de adelante.',
  ],
  mistakes: [
    'Paso demasiado corto.',
    'Perder el equilibrio: apóyate en una pared si hace falta.',
  ],
);

const _dbBench = GuideMove(
  name: 'Press de banca con mancuernas',
  imageId: 'Dumbbell_Bench_Press',
  equipment: 'Banco plano y dos mancuernas',
  muscles: ['Pectorales', 'Tríceps', 'Hombros'],
  steps: [
    'Acostado en el banco, pies firmes, omóplatos juntos y abajo.',
    'Mancuernas sobre el pecho, brazos extendidos.',
    'Baja controlado a los lados del pecho, codos a ~45° del cuerpo.',
    'Empuja hacia arriba sin chocar las mancuernas.',
  ],
  mistakes: [
    'Codos abiertos a 90° (cuida el hombro).',
    'Despegar la cadera del banco.',
    'Rebotar abajo.',
  ],
);

const _dbBenchNeutral = GuideMove(
  name: 'Press con mancuernas en agarre neutro',
  imageId: 'Dumbbell_Bench_Press_with_Neutral_Grip',
  equipment: 'Banco plano y dos mancuernas',
  muscles: ['Pectorales', 'Tríceps'],
  steps: [
    'Acostado, palmas mirándose entre sí.',
    'Baja controlado con los codos cerca del cuerpo.',
    'Usa un rango corto si el hombro molesta: sin dolor.',
    'Empuja hacia arriba.',
  ],
  mistakes: [
    'Bajar más allá del rango sin dolor.',
    'Arquear exageradamente la espalda.',
  ],
);

const _dbFloor = GuideMove(
  name: 'Press de piso con mancuernas',
  imageId: 'Dumbbell_Floor_Press',
  equipment: 'Dos mancuernas y el suelo',
  muscles: ['Pectorales', 'Tríceps'],
  steps: [
    'Acostado en el suelo, rodillas dobladas, mancuernas sobre el pecho.',
    'Baja hasta que los codos toquen suave el suelo.',
    'Pausa breve y empuja hacia arriba.',
  ],
  mistakes: [
    'Golpear los codos contra el suelo.',
    'Codos muy abiertos.',
  ],
);

const _pushup = GuideMove(
  name: 'Flexiones de brazos',
  imageId: 'Pushups',
  equipment: 'Sin equipo',
  muscles: ['Pectorales', 'Tríceps', 'Hombros', 'Core'],
  steps: [
    'Manos un poco más abiertas que los hombros, cuerpo recto de cabeza a talones.',
    'Baja el pecho cerca del suelo con codos a ~45°.',
    'Empuja el suelo hasta extender los brazos.',
  ],
  mistakes: [
    'Cadera caída o muy arriba.',
    'Bajar solo la cabeza.',
  ],
);

const _inclinePushup = GuideMove(
  name: 'Flexiones inclinadas',
  imageId: 'Incline_Push-Up',
  equipment: 'Banco, mesa o muro firme',
  muscles: ['Pectorales', 'Tríceps'],
  steps: [
    'Manos en el borde de un banco o mesa firme.',
    'Cuerpo recto, baja el pecho al borde.',
    'Empuja hasta extender. Mientras más alta la superficie, más fácil.',
  ],
  mistakes: [
    'Superficie que se mueve.',
    'Cadera caída.',
  ],
);

const _cableRow = GuideMove(
  name: 'Remo en polea baja',
  imageId: 'Seated_Cable_Rows',
  equipment: 'Polea baja con agarre en V',
  muscles: ['Dorsales', 'Romboides', 'Bíceps'],
  steps: [
    'Sentado, pies en la plataforma, rodillas suaves y espalda recta.',
    'Tira del agarre hacia el abdomen juntando los omóplatos.',
    'Pausa breve y estira los brazos controlado.',
  ],
  mistakes: [
    'Balancear el torso para tirar.',
    'Subir los hombros a las orejas.',
  ],
);

const _dbRow = GuideMove(
  name: 'Remo con mancuerna a una mano',
  imageId: 'One-Arm_Dumbbell_Row',
  equipment: 'Banco y una mancuerna',
  muscles: ['Dorsales', 'Romboides', 'Bíceps'],
  steps: [
    'Rodilla y mano del mismo lado apoyadas en el banco, espalda plana.',
    'Mancuerna colgando con el brazo estirado.',
    'Tira llevando el codo hacia la cadera.',
    'Baja controlado y cambia de lado.',
  ],
  mistakes: [
    'Girar el torso para subir el peso.',
    'Tirar con el bíceps en vez de la espalda.',
  ],
);

const _invertedRow = GuideMove(
  name: 'Remo invertido',
  imageId: 'Inverted_Row',
  equipment: 'Barra baja o una mesa muy firme',
  muscles: ['Dorsales', 'Romboides', 'Bíceps', 'Core'],
  steps: [
    'Acostado bajo la barra o el borde de la mesa, tómate con las manos.',
    'Cuerpo recto, talones apoyados.',
    'Tira del pecho hacia la barra juntando los omóplatos.',
    'Baja controlado. Doblar las rodillas lo hace más fácil.',
  ],
  mistakes: [
    'Usar una mesa que no soporta tu peso.',
    'Cadera caída.',
  ],
);

const _seatedDbPress = GuideMove(
  name: 'Press de hombros sentado con mancuernas',
  imageId: 'Seated_Dumbbell_Press',
  equipment: 'Banco con respaldo y dos mancuernas',
  muscles: ['Hombros', 'Tríceps'],
  steps: [
    'Sentado con la espalda apoyada, mancuernas a la altura de los hombros.',
    'Empuja hacia arriba sin bloquear los codos.',
    'Baja controlado hasta las orejas.',
  ],
  mistakes: [
    'Arquear la espalda baja.',
    'Bajar demasiado rápido.',
  ],
);

const _dbPress = GuideMove(
  name: 'Press de hombros con mancuernas',
  imageId: 'Dumbbell_Shoulder_Press',
  equipment: 'Dos mancuernas',
  muscles: ['Hombros', 'Tríceps', 'Core'],
  steps: [
    'De pie o sentado, mancuernas a la altura de los hombros.',
    'Abdomen firme, empuja hacia arriba.',
    'Baja controlado.',
  ],
  mistakes: [
    'Echar el torso atrás.',
    'Usar impulso de piernas.',
  ],
);

const _lateralRaise = GuideMove(
  name: 'Elevaciones laterales',
  imageId: 'Side_Lateral_Raise',
  equipment: 'Mancuernas livianas',
  muscles: ['Hombros (deltoides lateral)'],
  steps: [
    'De pie, mancuernas a los lados, codos levemente doblados.',
    'Sube los brazos hacia los lados hasta la altura de los hombros.',
    'Baja lento. Con molestias, usa poco peso y rango sin dolor.',
  ],
  mistakes: [
    'Usar impulso o demasiado peso.',
    'Subir más arriba de los hombros.',
  ],
);

const _pike = GuideMove(
  name: 'Flexiones pica',
  equipment: 'Sin equipo',
  muscles: ['Hombros', 'Tríceps'],
  steps: [
    'Desde flexión, sube la cadera formando una V invertida.',
    'Dobla los codos y baja la cabeza hacia el suelo entre las manos.',
    'Empuja para volver arriba.',
  ],
  mistakes: [
    'Abrir los codos hacia los lados.',
    'Bajar la cadera (se vuelve flexión normal).',
  ],
);

const _latPulldown = GuideMove(
  name: 'Jalón al pecho',
  imageId: 'Wide-Grip_Lat_Pulldown',
  equipment: 'Máquina de jalón (polea alta) con barra',
  muscles: ['Dorsales', 'Bíceps', 'Romboides'],
  steps: [
    'Sentado con los muslos bajo el soporte, toma la barra más ancho que los hombros.',
    'Pecho arriba, tira la barra hacia la parte alta del pecho.',
    'Junta los omóplatos abajo y sube controlado.',
  ],
  mistakes: [
    'Tirar detrás de la nuca.',
    'Echarse muy atrás para bajar la barra.',
  ],
);

const _bandPulldown = GuideMove(
  name: 'Jalón con banda elástica',
  equipment: 'Banda elástica anclada arriba (puerta o barra)',
  muscles: ['Dorsales', 'Bíceps'],
  steps: [
    'Ancla la banda arriba y tómala con ambas manos.',
    'De rodillas o sentado, tira hacia el pecho bajando los codos.',
    'Vuelve controlado.',
  ],
  mistakes: [
    'Anclaje inseguro.',
    'Tirar con los hombros encogidos.',
  ],
);

const _towelRow = GuideMove(
  name: 'Remo con toalla en una puerta',
  equipment: 'Toalla resistente y una puerta cerrada con llave',
  muscles: ['Dorsales', 'Romboides', 'Bíceps'],
  steps: [
    'Pasa la toalla por la manilla de una puerta cerrada y bien trabada.',
    'Toma los extremos e inclínate atrás con los brazos estirados.',
    'Tira del cuerpo hacia la puerta juntando los omóplatos.',
    'Mientras más inclinado, más difícil.',
  ],
  mistakes: [
    'Puerta que se abre: ciérrala con llave.',
    'Cadera caída.',
  ],
);

const _plank = GuideMove(
  name: 'Plancha',
  imageId: 'Plank',
  equipment: 'Sin equipo (colchoneta)',
  muscles: ['Core', 'Hombros'],
  steps: [
    'Antebrazos en el suelo, codos bajo los hombros.',
    'Cuerpo recto de cabeza a talones, glúteos y abdomen apretados.',
    'Respira normal y mantén 20–45 segundos.',
  ],
  mistakes: [
    'Cadera caída o muy arriba.',
    'Aguantar la respiración.',
  ],
);

const _pallof = GuideMove(
  name: 'Pallof press',
  imageId: 'Pallof_Press',
  equipment: 'Polea a la altura del pecho (o banda elástica)',
  muscles: ['Core (oblicuos)'],
  steps: [
    'De lado a la polea, agarre frente al pecho.',
    'Empuja los brazos al frente sin dejar que el torso gire.',
    'Mantén 2 segundos y vuelve. Haz ambos lados.',
  ],
  mistakes: [
    'Girar el torso hacia la polea.',
    'Estar demasiado cerca (sin tensión).',
  ],
);

const _deadBug = GuideMove(
  name: 'Dead bug',
  imageId: 'Dead_Bug',
  equipment: 'Sin equipo (colchoneta)',
  muscles: ['Core'],
  steps: [
    'Boca arriba, brazos al techo y rodillas a 90° sobre la cadera.',
    'Espalda baja pegada al suelo.',
    'Estira un brazo y la pierna contraria sin despegar la espalda.',
    'Vuelve y alterna lento.',
  ],
  mistakes: [
    'Arquear la espalda baja.',
    'Hacerlo rápido.',
  ],
);

/// Fichas por nombre del ejercicio como lo propone el motor de
/// entrenamiento (training_plan.dart).
const exerciseGuides = <String, List<GuideMove>>{
  'Sentadilla con barra o prensa de piernas': [_squatBarbell, _legPress],
  'Sentadilla goblet con mancuerna': [_goblet],
  'Sentadilla con peso corporal': [_bwSquat],
  'Peso muerto rumano con barra': [_rdlBarbell],
  'Peso muerto rumano con mancuernas': [_rdlDumbbell],
  'Puente de glúteo a una pierna': [_slBridge],
  'Zancada con mancuernas': [_lungeDumbbell],
  'Zancada hacia atrás con mancuernas': [_rearLungeDumbbell],
  'Zancada hacia atrás': [_rearLungeBodyweight],
  'Press de banca con mancuernas': [_dbBench],
  'Press de piso con mancuernas': [_dbFloor],
  'Flexiones de brazos (inclinadas si cuesta)': [_pushup, _inclinePushup],
  'Remo en polea baja': [_cableRow],
  'Remo con mancuerna a una mano': [_dbRow],
  'Remo invertido bajo una mesa firme': [_invertedRow],
  'Press de hombros sentado con mancuernas': [_seatedDbPress],
  'Press de hombros con mancuernas': [_dbPress],
  'Flexiones pica (pike push-ups)': [_pike],
  'Jalón al pecho': [_latPulldown],
  'Jalón con banda elástica': [_bandPulldown],
  'Remo con toalla en una puerta': [_towelRow],
  'Plancha + Pallof press en polea': [_plank, _pallof],
  'Plancha + dead bug': [_plank, _deadBug],
  'Sentadilla a un cajón alto (rango sin dolor)': [_boxSquat],
  'Puente de glúteo': [_bridge],
  'Hip thrust o puente de glúteo': [_hipThrust, _bridge],
  'Prensa de piernas o sentadilla goblet a cajón': [_legPress, _boxSquat],
  'Elevaciones laterales livianas (sin dolor)': [_lateralRaise],
  'Elevaciones laterales livianas': [_lateralRaise],
  'Press de pecho con agarre neutro, rango corto': [_dbBenchNeutral],
  'Press con mancuernas en agarre neutro': [_dbBenchNeutral],
  'Dead bug + plancha sobre antebrazos': [_deadBug, _plank],
};

/// La ficha de un ejercicio (vacía si no existe).
List<GuideMove> guideFor(String exercise) => exerciseGuides[exercise] ?? const [];
