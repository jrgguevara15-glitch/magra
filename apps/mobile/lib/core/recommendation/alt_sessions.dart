/// Sesiones para variar el entrenamiento un día (HYROX, CrossFit, yoga,
/// pilates, HIIT, circuito funcional, cardio largo, boxeo, movilidad),
/// adaptadas al equipo del usuario y filtradas por sus lesiones, su nivel y
/// su salud.
library;

import '../../features/questionnaire/questionnaire.dart';

enum Intensity {
  low('Baja'),
  medium('Media'),
  high('Alta');

  const Intensity(this.label);
  final String label;
}

/// Un bloque de la sesión: "Calentamiento", "AMRAP 15 min"…
class AltBlock {
  const AltBlock(this.title, this.items, {this.note});

  final String title;
  final List<String> items;
  final String? note;
}

class AltSession {
  const AltSession({
    required this.id,
    required this.name,
    required this.style,
    required this.why,
    required this.minutes,
    required this.met,
    required this.intensity,
    required this.blocks,
    this.cautions = const [],
  });

  final String id;
  final String name;

  /// "Híbrido", "Funcional", "Mente-cuerpo"…
  final String style;

  /// Para qué sirve, en una frase.
  final String why;
  final int minutes;

  /// Equivalente metabólico promedio de la sesión (Compendio de Actividad
  /// Física), para estimar las calorías.
  final double met;
  final Intensity intensity;
  final List<AltBlock> blocks;
  final List<String> cautions;
}

/// Catálogo de ids, en el orden en que se muestran.
const altSessionIds = [
  'hyrox',
  'crossfit',
  'hiit',
  'funcional',
  'boxeo',
  'cardio_z2',
  'yoga',
  'pilates',
  'movilidad',
];

/// Las sesiones que el usuario puede hacer, adaptadas a su equipo.
/// [lowImpact]: sin saltos ni carrera (IMC alto, rodillas, tobillos).
List<AltSession> altSessionsFor(Questionnaire q, {bool lowImpact = false}) {
  final injuries = q.injuries.toSet();
  bool hurt(Iterable<Injury> any) => any.any(injuries.contains);
  final careful = q.needsProfessionalSupervision;
  final novice = q.experience == Experience.none;
  final impact = !lowImpact && !hurt([Injury.knee, Injury.ankle]);
  final eq = q.equipment;
  final out = <AltSession>[];

  // Con una condición que requiere supervisión, solo baja intensidad.
  if (!careful && !novice && impact && !hurt([Injury.lowerBack])) out.add(_hyrox(eq));
  if (!careful && !hurt([Injury.lowerBack, Injury.shoulder])) out.add(_crossfit(eq, novice: novice, impact: impact));
  if (!careful) out.add(_hiit(impact: impact));
  if (!careful) out.add(_funcional(eq));
  if (!careful && !hurt([Injury.shoulder, Injury.wrist])) out.add(_boxeo(impact: impact));
  out.add(_cardioZ2(eq, impact: impact));
  out.add(_yoga(wrists: hurt([Injury.wrist])));
  if (!hurt([Injury.neck])) out.add(_pilates());
  out.add(_movilidad());
  return out;
}

AltSession? altSessionById(Questionnaire q, String id, {bool lowImpact = false}) =>
    altSessionsFor(q, lowImpact: lowImpact).where((s) => s.id == id).firstOrNull;

AltSession _hyrox(Equipment eq) {
  final gym = eq == Equipment.gym;
  return AltSession(
    id: 'hyrox',
    name: 'HYROX (simulación)',
    style: 'Híbrido: carrera + estaciones',
    why: 'Entrena resistencia y fuerza a la vez, como la competencia HYROX, en versión reducida.',
    minutes: 60,
    met: 8.0,
    intensity: Intensity.high,
    blocks: [
      const AltBlock('Calentamiento · 10 min', [
        '5 min de trote suave o bicicleta',
        'Movilidad de cadera y hombros, 10 sentadillas y 10 zancadas sin peso',
      ]),
      AltBlock(
        '4 rondas · ritmo sostenible',
        gym
            ? [
                '1 km de carrera (ritmo en que puedes decir frases cortas)',
                'Ronda 1: 500 m de SkiErg + 25 m de empuje de trineo',
                'Ronda 2: 25 m de arrastre de trineo + 10 burpees con salto largo',
                'Ronda 3: 500 m de remo + 100 m de farmers carry (2 × 16–24 kg)',
                'Ronda 4: 20 zancadas con saco o mancuernas + 30 wall balls',
              ]
            : [
                '800 m de trote o 4 min de trote en el lugar',
                'Ronda 1: 40 jumping jacks + 15 sentadillas',
                'Ronda 2: 10 burpees + 20 mountain climbers',
                'Ronda 3: 20 zancadas alternas${eq == Equipment.homeWeights ? ' con mancuernas' : ''} + 40 s de plancha',
                'Ronda 4: ${eq == Equipment.homeWeights ? '100 m de farmers carry con mancuernas + 20 thrusters' : '30 sentadillas con brazos arriba + 10 flexiones'}',
              ],
        note: 'Anota tu tiempo total: la próxima vez intenta bajarlo.',
      ),
      const AltBlock('Vuelta a la calma · 5 min', ['Caminata suave y estiramiento de piernas']),
    ],
    cautions: const ['Si nunca has corrido 1 km seguido, camina rápido en su lugar.'],
  );
}

AltSession _crossfit(Equipment eq, {required bool novice, required bool impact}) {
  final items = switch (eq) {
    Equipment.gym => [
        '10 kettlebell swings (12–24 kg)',
        '10 step-ups al cajón por pierna',
        '10 push press con mancuernas',
        '200 m de remo',
      ],
    Equipment.homeWeights => [
        '10 swings con mancuerna',
        '10 thrusters con mancuernas',
        '8 remos renegados por lado',
        impact ? '20 mountain climbers' : '20 marchas de rodilla alta',
      ],
    Equipment.bodyweight => [
        '15 sentadillas al aire',
        '10 flexiones (inclinadas si cuesta)',
        '20 mountain climbers',
        impact ? '10 burpees' : '10 sentadillas a la silla',
      ],
  };
  return AltSession(
    id: 'crossfit',
    name: 'CrossFit (WOD)',
    style: 'Funcional de alta intensidad',
    why: 'Movimientos completos a buen ritmo: quema mucho y mejora tu condición general.',
    minutes: novice ? 35 : 45,
    met: novice ? 6.0 : 7.5,
    intensity: novice ? Intensity.medium : Intensity.high,
    blocks: [
      const AltBlock('Calentamiento · 10 min', ['3 rondas: 10 sentadillas, 10 good mornings, 10 flexiones de hombro con banda o palo']),
      if (eq == Equipment.gym && !novice)
        const AltBlock('Fuerza · 10 min', ['5 × 3 sentadilla frontal, subiendo de a poco (deja 2 repeticiones en reserva)']),
      AltBlock(
        novice ? 'AMRAP 12 min (lo que alcances, sin apuro)' : 'AMRAP 15 min (máximas rondas)',
        items,
        note: 'Anota cuántas rondas completaste para superarte la próxima vez.',
      ),
      const AltBlock('Core · 5 min', ['3 × 30 s de plancha y 10 dead bugs']),
    ],
    cautions: const ['Técnica antes que velocidad: si la forma se rompe, baja el ritmo.'],
  );
}

AltSession _hiit({required bool impact}) => AltSession(
      id: 'hiit',
      name: 'HIIT',
      style: 'Intervalos',
      why: 'Sesión corta e intensa: mucho trabajo en poco tiempo.',
      minutes: 25,
      met: impact ? 8.0 : 6.0,
      intensity: impact ? Intensity.high : Intensity.medium,
      blocks: [
        const AltBlock('Calentamiento · 5 min', ['Marcha, círculos de brazos y cadera, 10 sentadillas']),
        AltBlock(
          '4 rondas · 40 s de trabajo / 20 s de pausa',
          impact
              ? ['Burpees', 'Sentadillas con salto', 'Mountain climbers', 'Jumping jacks', 'Saltos laterales (skater)']
              : ['Sentadillas', 'Marcha con rodilla alta', 'Plancha con toque de hombro', 'Step jacks (sin salto)', 'Zancada hacia atrás'],
          note: '1 min de pausa entre rondas.',
        ),
        const AltBlock('Vuelta a la calma · 5 min', ['Caminata y respiración profunda']),
      ],
    );

AltSession _funcional(Equipment eq) {
  final items = switch (eq) {
    Equipment.gym => [
        '12 sentadillas goblet',
        '12 remos con mancuerna por lado',
        '10 press de hombros con mancuernas',
        '10 zancadas por pierna',
        '40 m de farmers carry',
        '30 s de plancha',
      ],
    Equipment.homeWeights => [
        '12 sentadillas goblet',
        '12 remos con mancuerna por lado',
        '10 press de hombros',
        '10 peso muerto rumano con mancuernas',
        '40 m de farmers carry (o 40 s quieto)',
        '30 s de plancha',
      ],
    Equipment.bodyweight => [
        '15 sentadillas',
        '10 remos con toalla en una puerta',
        '10 flexiones (inclinadas si cuesta)',
        '10 zancadas hacia atrás por pierna',
        '15 puentes de glúteo',
        '30 s de plancha',
      ],
  };
  return AltSession(
    id: 'funcional',
    name: 'Circuito funcional',
    style: 'Fuerza en circuito',
    why: 'Todo el cuerpo con poco descanso: fuerza y gasto calórico en la misma sesión.',
    minutes: 45,
    met: 6.0,
    intensity: Intensity.medium,
    blocks: [
      const AltBlock('Calentamiento · 8 min', ['Movilidad general y 1 ronda suave del circuito']),
      AltBlock('3–4 rondas · 30 s de pausa entre ejercicios', items, note: '2 min de pausa entre rondas.'),
    ],
  );
}

AltSession _boxeo({required bool impact}) => AltSession(
      id: 'boxeo',
      name: 'Boxeo fitness',
      style: 'Cardio de combate (sin contacto)',
      why: 'Cardio entretenido que trabaja hombros, core y coordinación.',
      minutes: 40,
      met: 7.0,
      intensity: Intensity.medium,
      blocks: [
        const AltBlock('Calentamiento · 5 min', [
          'Rotación de hombros y tronco',
          'Desplazamientos suaves en guardia',
        ]),
        AltBlock(
          '6 asaltos de 3 min · 1 min de pausa',
          [
            'Asaltos 1–2: jab y directo (1-2), moviéndote en guardia',
            'Asaltos 3–4: 1-2 + gancho + esquiva',
            'Asaltos 5–6: combinaciones libres a máxima velocidad los últimos 30 s',
            if (impact) 'En cada pausa: 20 saltos de cuerda suaves (opcional)',
          ],
        ),
        const AltBlock('Core · 5 min', ['3 × 30 s de plancha', '20 giros rusos sin peso']),
      ],
      cautions: const ['Golpea al aire sin estirar del todo el codo.'],
    );

AltSession _cardioZ2(Equipment eq, {required bool impact}) => AltSession(
      id: 'cardio_z2',
      name: 'Cardio largo en zona 2',
      style: 'Resistencia aeróbica',
      why: 'Quema grasa a ritmo cómodo y mejora tu base aeróbica sin cansarte para mañana.',
      minutes: 50,
      met: impact ? 6.0 : 5.0,
      intensity: Intensity.low,
      blocks: [
        AltBlock('45–60 min continuos', [
          if (eq == Equipment.gym) 'Bicicleta, elíptica o caminata en cinta inclinada (8–12 %)',
          if (eq != Equipment.gym) impact ? 'Trote suave o caminata rápida al aire libre' : 'Caminata rápida o bicicleta',
          'Ritmo en que puedes hablar en frases cortas (zona 2)',
        ]),
      ],
    );

AltSession _yoga({required bool wrists}) => AltSession(
      id: 'yoga',
      name: 'Yoga vinyasa suave',
      style: 'Mente-cuerpo',
      why: 'Fuerza, equilibrio y movilidad con respiración: ideal para recuperarte y bajar el estrés.',
      minutes: 40,
      met: 3.0,
      intensity: Intensity.low,
      blocks: [
        const AltBlock('Respiración · 3 min', ['Sentado, inhala 4 s y exhala 6 s']),
        AltBlock('Saludo al sol · 10 min', [
          '5 saludos al sol A, lentos',
          wrists ? 'Perro boca abajo y plancha apoyando antebrazos' : 'Perro boca abajo y plancha alta, con codos suaves',
        ]),
        const AltBlock('Posturas de pie · 12 min (30–45 s cada lado)', [
          'Guerrero I y Guerrero II',
          'Triángulo',
          'Silla',
          'Árbol (equilibrio)',
        ]),
        const AltBlock('Suelo · 10 min', ['Puente', 'Figura 4 o paloma', 'Torsión acostado', 'Postura del niño']),
        const AltBlock('Relajación final · 5 min', ['Acostado, respiración lenta']),
      ],
    );

AltSession _pilates() => const AltSession(
      id: 'pilates',
      name: 'Pilates en colchoneta',
      style: 'Core y postura',
      why: 'Fortalece el centro del cuerpo y mejora la postura sin impacto.',
      minutes: 40,
      met: 3.0,
      intensity: Intensity.low,
      blocks: [
        AltBlock('Calentamiento · 5 min', ['Respiración costal, rodar la columna sentado']),
        AltBlock('Bloque principal · 30 min (8–10 repeticiones lentas)', [
          'The hundred (piernas dobladas si cuesta)',
          'Curl de abdomen controlado',
          'Estiramiento de una pierna',
          'Puente con elevación de pelvis',
          'Patadas laterales acostado',
          'Natación (swimming) boca abajo',
          'Plancha 20–30 s',
        ]),
        AltBlock('Cierre · 5 min', ['Postura del niño y estiramiento de espalda']),
      ],
      cautions: ['Mantén la zona lumbar apoyada en los ejercicios de abdomen.'],
    );

AltSession _movilidad() => const AltSession(
      id: 'movilidad',
      name: 'Movilidad y recuperación',
      style: 'Recuperación activa',
      why: 'Un día suave que suma movimiento y te deja listo para el próximo entreno.',
      minutes: 30,
      met: 2.5,
      intensity: Intensity.low,
      blocks: [
        AltBlock('20 min de movilidad', [
          'Gato-vaca × 10',
          'El mejor estiramiento del mundo × 5 por lado',
          'Círculos de cadera y de hombros',
          'Flexor de cadera de rodillas 45 s por lado',
          'Rotación de tronco × 10',
        ]),
        AltBlock('10 min de caminata suave', ['Al aire libre si puedes']),
      ],
    );
