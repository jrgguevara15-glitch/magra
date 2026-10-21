/// Animaciones del maniquí para cada ejercicio y cada paso de calentamiento
/// o vuelta a la calma, por nombre. Ángulos en grados en el marco del
/// cuerpo (ver [Seg] y [Pose]).
library;

import 'mannequin.dart';

// Brazos frecuentes.
const _hang = Seg(0, 6);
const _sitThigh = Seg(90, 6);
const _sitShin = Seg(0, 4);

// Sentadillas.
const _stand = Pose();
const _squatArmsFwd = Pose(
    trunk: 38, thigh: Seg(92, 12), shin: Seg(-32, 6), upperArm: Seg(90, 6), forearm: Seg(90, 4));
const _standArmsFwd = Pose(upperArm: Seg(85, 6), forearm: Seg(88, 4));

const _barbellUp = Pose(armsWithTrunk: true, upperArm: Seg(-25, 62), forearm: Seg(165, 14));
const _barbellDown = Pose(
    trunk: 40, thigh: Seg(95, 12), shin: Seg(-32, 6),
    armsWithTrunk: true, upperArm: Seg(-25, 62), forearm: Seg(165, 14));

const _gobletUp = Pose(armsWithTrunk: true, upperArm: Seg(18, 14), forearm: Seg(150, -32));
const _gobletDown = Pose(
    trunk: 25, thigh: Seg(98, 16), shin: Seg(-30, 8),
    armsWithTrunk: true, upperArm: Seg(18, 14), forearm: Seg(150, -32));

const _boxDown = Pose(
    trunk: 35, thigh: Seg(85, 12), shin: Seg(-20, 6), upperArm: Seg(90, 6), forearm: Seg(90, 4));

// Bisagra de cadera.
const _hingeUp = Pose(thigh: Seg(4, 6), shin: Seg(-2, 4), upperArm: Seg(0, 4), forearm: Seg(0, 4));
const _hingeDown = Pose(trunk: 72, thigh: Seg(16, 6), shin: Seg(-6, 4), upperArm: Seg(0, 4), forearm: Seg(0, 4));

// Puentes (acostado boca arriba).
const _bridgeDown = Pose(pitch: -90, thigh: Seg(45, 6), shin: Seg(-80, 4), upperArm: Seg(0, 20), forearm: Seg(0, 20));
const _bridgeUp = Pose(pitch: -68, thigh: Seg(28, 6), shin: Seg(-68, 4), upperArm: Seg(22, 20), forearm: Seg(22, 20));
const _slBridgeDown = Pose(
    pitch: -90, rThigh: Seg(45, 6), rShin: Seg(-80, 4), lThigh: Seg(70, 4), lShin: Seg(70, 4),
    upperArm: Seg(0, 20), forearm: Seg(0, 20));
const _slBridgeUp = Pose(
    pitch: -68, rThigh: Seg(28, 6), rShin: Seg(-68, 4), lThigh: Seg(50, 4), lShin: Seg(50, 4),
    upperArm: Seg(22, 20), forearm: Seg(22, 20));

// Hip thrust: espalda alta en el banco.
const _thrustDown = Pose(
    pitch: -60, rootY: 20, thigh: Seg(60, 8), shin: Seg(-60, 4), upperArm: Seg(15, 8), forearm: Seg(15, 4));
const _thrustUp = Pose(
    pitch: -90, rootY: 42, thigh: Seg(0, 8), shin: Seg(-90, 4), upperArm: Seg(10, 8), forearm: Seg(10, 4));

// Zancadas (la derecha adelante).
const _lungeDown = Pose(
    rThigh: Seg(88, 4), rShin: Seg(-4, 3), lThigh: Seg(-18, 4), lShin: Seg(-90, 3),
    upperArm: _hang, forearm: _hang);
const _lungeMid = Pose(
    rThigh: Seg(40, 4), rShin: Seg(-10, 3), lThigh: Seg(-8, 4), lShin: Seg(-40, 3),
    upperArm: _hang, forearm: _hang);

// Press acostado en banco.
const _benchLegs = Pose(pitch: -90, rootY: 50, thigh: Seg(0, 18), shin: Seg(-90, 14));
Pose _bench(Seg upper, Seg fore) => Pose(
    pitch: _benchLegs.pitch, rootY: _benchLegs.rootY, thigh: const Seg(0, 18), shin: const Seg(-90, 14),
    upperArm: upper, forearm: fore);

// Flexiones (boca abajo; abajo del mundo = flex igual al pitch).
const _pushUp = Pose(pitch: 72, upperArm: Seg(72, 10), forearm: Seg(72, 8));
const _pushDown = Pose(pitch: 86, upperArm: Seg(20, 42), forearm: Seg(86, 10));
const _inclineUp = Pose(pitch: 48, upperArm: Seg(48, 10), forearm: Seg(48, 8));
const _inclineDown = Pose(pitch: 60, upperArm: Seg(5, 42), forearm: Seg(60, 10));

// Remo sentado en polea.
Pose _seatedRow(double trunk, Seg upper, Seg fore) => Pose(
    rootY: 12, thigh: const Seg(78, 8), shin: const Seg(96, 6), trunk: trunk, upperArm: upper, forearm: fore);

// Sentado en banco.
Pose _seated(Seg upper, Seg fore, {double trunk = 0}) =>
    Pose(rootY: 46, thigh: _sitThigh, shin: _sitShin, trunk: trunk, upperArm: upper, forearm: fore);

// De rodillas (arrodillado erguido).
Pose _kneel(Seg upper, Seg fore) =>
    Pose(thigh: const Seg(0, 6), shin: const Seg(-90, 6), upperArm: upper, forearm: fore);

final Map<String, MoveAnim> _anims = {
  // ----- Piernas -----
  'Sentadilla con barra': const MoveAnim([_barbellUp, _barbellDown], props: [Prop.barbellBack], yaw: 45),
  'Prensa de piernas': const MoveAnim([
    Pose(trunk: -50, rootY: 40, thigh: Seg(128, 10), shin: Seg(128, 8), upperArm: Seg(5, 18), forearm: Seg(60, 10)),
    Pose(trunk: -50, rootY: 40, thigh: Seg(172, 14), shin: Seg(78, 10), upperArm: Seg(5, 18), forearm: Seg(60, 10)),
  ], props: [Prop.bench, Prop.footPlate], yaw: 70, elevation: 22),
  'Sentadilla goblet': const MoveAnim([_gobletUp, _gobletDown], props: [Prop.goblet], yaw: 45),
  'Sentadilla con peso corporal': const MoveAnim([_standArmsFwd, _squatArmsFwd], yaw: 45),
  'Sentadillas sin peso': const MoveAnim([_standArmsFwd, _squatArmsFwd], yaw: 45),
  'Sentadilla a un cajón': const MoveAnim([_standArmsFwd, _boxDown], props: [Prop.box], yaw: 45),
  'Peso muerto rumano con barra': const MoveAnim([_hingeUp, _hingeDown], props: [Prop.barbellHands], yaw: 70),
  'Peso muerto rumano con mancuernas': const MoveAnim([_hingeUp, _hingeDown], props: [Prop.dumbbells], yaw: 70),
  'Puente de glúteo a una pierna':
      const MoveAnim([_slBridgeDown, _slBridgeUp], props: [Prop.floorMat], yaw: 75, eccentricFirst: false, elevation: 32),
  'Puente de glúteo': const MoveAnim([_bridgeDown, _bridgeUp], props: [Prop.floorMat], yaw: 75, eccentricFirst: false, elevation: 32),
  'Hip thrust': const MoveAnim([_thrustDown, _thrustUp], props: [Prop.benchBack, Prop.barbellHands], yaw: 75, eccentricFirst: false, elevation: 30),
  'Zancada con mancuernas':
      const MoveAnim([_stand, _lungeMid, _lungeDown], props: [Prop.dumbbells], yaw: 60, seconds: 3),
  'Zancada hacia atrás con mancuernas':
      const MoveAnim([_stand, _lungeMid, _lungeDown], props: [Prop.dumbbells], yaw: 60, seconds: 3),
  'Zancada hacia atrás': const MoveAnim([_stand, _lungeMid, _lungeDown], yaw: 60, seconds: 3),

  // ----- Empuje -----
  'Press de banca con mancuernas': MoveAnim([
    _bench(const Seg(-12, 78), const Seg(90, 2)),
    _bench(const Seg(90, 10), const Seg(90, 4)),
  ], props: const [Prop.bench, Prop.dumbbells], yaw: 60, eccentricFirst: false, elevation: 32),
  'Press con mancuernas en agarre neutro': MoveAnim([
    _bench(const Seg(-12, 40), const Seg(90, 2)),
    _bench(const Seg(90, 8), const Seg(90, 4)),
  ], props: const [Prop.bench, Prop.dumbbells], yaw: 60, eccentricFirst: false, elevation: 32),
  'Press de piso con mancuernas': const MoveAnim([
    Pose(pitch: -90, thigh: Seg(45, 6), shin: Seg(-80, 4), upperArm: Seg(0, 58), forearm: Seg(90, 2)),
    Pose(pitch: -90, thigh: Seg(45, 6), shin: Seg(-80, 4), upperArm: Seg(90, 10), forearm: Seg(90, 4)),
  ], props: [Prop.floorMat, Prop.dumbbells], yaw: 60, eccentricFirst: false, elevation: 35),
  'Flexiones de brazos': const MoveAnim([_pushUp, _pushDown], yaw: 90),
  'Flexiones inclinadas': const MoveAnim([_inclineUp, _inclineDown], props: [Prop.benchUnderHands], yaw: 90),
  'Press de hombros sentado con mancuernas': MoveAnim([
    _seated(const Seg(0, 82), const Seg(178, 6)),
    _seated(const Seg(170, 16), const Seg(176, 6)),
  ], props: const [Prop.bench, Prop.dumbbells], yaw: 25, eccentricFirst: false),
  'Press de hombros con mancuernas': const MoveAnim([
    Pose(upperArm: Seg(0, 82), forearm: Seg(178, 6)),
    Pose(upperArm: Seg(170, 16), forearm: Seg(176, 6)),
  ], props: [Prop.dumbbells], yaw: 25, eccentricFirst: false),
  'Elevaciones laterales': const MoveAnim([
    Pose(upperArm: Seg(5, 10), forearm: Seg(12, 10)),
    Pose(upperArm: Seg(5, 84), forearm: Seg(12, 84)),
  ], props: [Prop.dumbbells], yaw: 15, eccentricFirst: false),
  'Flexiones pica': const MoveAnim([
    Pose(trunk: 132, thigh: Seg(-38, 6), shin: Seg(-38, 4), upperArm: Seg(22, 12), forearm: Seg(22, 10)),
    Pose(trunk: 150, thigh: Seg(-42, 6), shin: Seg(-42, 4), upperArm: Seg(-25, 45), forearm: Seg(25, 10)),
  ], yaw: 80),

  // ----- Tirón -----
  'Remo en polea baja': MoveAnim([
    _seatedRow(12, const Seg(88, 8), const Seg(90, 4)),
    _seatedRow(-4, const Seg(-35, 12), const Seg(80, 6)),
  ], props: const [Prop.cableForward], yaw: 75, eccentricFirst: false),
  'Remo con mancuerna a una mano': const MoveAnim([
    Pose(trunk: 78, lThigh: Seg(14, 6), rThigh: Seg(-6, 6), lShin: Seg(-4, 4), rShin: Seg(-4, 4),
        lUpperArm: Seg(0, 4), lForearm: Seg(0, 4), rUpperArm: Seg(0, 6), rForearm: Seg(0, 6)),
    Pose(trunk: 78, lThigh: Seg(14, 6), rThigh: Seg(-6, 6), lShin: Seg(-4, 4), rShin: Seg(-4, 4),
        lUpperArm: Seg(0, 4), lForearm: Seg(0, 4), rUpperArm: Seg(-60, 12), rForearm: Seg(0, 6)),
  ], props: [Prop.benchUnderHands, Prop.dumbbellRight], yaw: 70, eccentricFirst: false),
  'Remo invertido': const MoveAnim([
    Pose(pitch: -60, upperArm: Seg(120, 10), forearm: Seg(120, 8)),
    Pose(pitch: -58, upperArm: Seg(30, 40), forearm: Seg(122, 10)),
  ], props: [Prop.bar], yaw: 75, eccentricFirst: false),
  'Jalón al pecho': MoveAnim([
    _seated(const Seg(172, 26), const Seg(176, 14)),
    _seated(const Seg(-8, 42), const Seg(165, 12), trunk: -10),
  ], props: const [Prop.bench, Prop.cableHigh, Prop.bar], yaw: 40, eccentricFirst: false),
  'Jalón con banda elástica': MoveAnim([
    _kneel(const Seg(172, 22), const Seg(176, 12)),
    _kneel(const Seg(-8, 40), const Seg(165, 12)),
  ], props: const [Prop.cableHigh], yaw: 25, eccentricFirst: false),
  'Remo con toalla en una puerta': const MoveAnim([
    Pose(pitch: -30, upperArm: Seg(60, 6), forearm: Seg(60, 4)),
    Pose(pitch: -18, upperArm: Seg(-25, 14), forearm: Seg(72, 8)),
  ], props: [Prop.wall], yaw: 75, eccentricFirst: false),

  // ----- Core -----
  'Plancha': const MoveAnim([
    Pose(pitch: 84, upperArm: Seg(84, 6), forearm: Seg(174, 2)),
    Pose(pitch: 86, upperArm: Seg(86, 6), forearm: Seg(176, 2)),
  ], props: [Prop.floorMat], yaw: 90, seconds: 3.2, kind: DemoKind.hold),
  'Pallof press': const MoveAnim([
    Pose(thigh: Seg(10, 12), shin: Seg(-8, 8), armsWithTrunk: true, upperArm: Seg(15, 6), forearm: Seg(140, -30)),
    Pose(thigh: Seg(10, 12), shin: Seg(-8, 8), upperArm: Seg(88, -4), forearm: Seg(90, -6)),
  ], props: [Prop.cableSide], yaw: 20, eccentricFirst: false),
  'Dead bug': const MoveAnim([
    Pose(pitch: -90, upperArm: Seg(90, 4), forearm: Seg(90, 2), thigh: Seg(90, 4), shin: Seg(0, 4)),
    Pose(pitch: -90, lUpperArm: Seg(170, 6), lForearm: Seg(172, 6), rUpperArm: Seg(90, 4), rForearm: Seg(90, 2),
        lThigh: Seg(90, 4), lShin: Seg(0, 4), rThigh: Seg(12, 4), rShin: Seg(12, 4)),
    Pose(pitch: -90, upperArm: Seg(90, 4), forearm: Seg(90, 2), thigh: Seg(90, 4), shin: Seg(0, 4)),
    Pose(pitch: -90, rUpperArm: Seg(170, 6), rForearm: Seg(172, 6), lUpperArm: Seg(90, 4), lForearm: Seg(90, 2),
        rThigh: Seg(90, 4), rShin: Seg(0, 4), lThigh: Seg(12, 4), lShin: Seg(12, 4)),
  ], props: [Prop.floorMat], yaw: 60, seconds: 5, loop: true, elevation: 38),

  // ----- Calentamiento -----
  for (final n in const [
    'Bicicleta o elíptica suave',
    'Caminata rápida o marcha en el lugar',
    'Bicicleta, remo o trote suave',
    'Trote suave en el lugar',
  ])
    n: const MoveAnim([
      Pose(lThigh: Seg(55, 3), lShin: Seg(-45, 3), rThigh: Seg(-5, 3), rShin: Seg(-10, 3),
          lUpperArm: Seg(-25, 8), lForearm: Seg(60, 6), rUpperArm: Seg(30, 8), rForearm: Seg(100, 6)),
      Pose(rThigh: Seg(55, 3), rShin: Seg(-45, 3), lThigh: Seg(-5, 3), lShin: Seg(-10, 3),
          rUpperArm: Seg(-25, 8), rForearm: Seg(60, 6), lUpperArm: Seg(30, 8), lForearm: Seg(100, 6)),
    ], yaw: 50, seconds: 1),
  'Círculos de brazos': const MoveAnim([
    Pose(upperArm: Seg(18, 84), forearm: Seg(18, 84)),
    Pose(upperArm: Seg(0, 98), forearm: Seg(0, 98)),
    Pose(upperArm: Seg(-18, 84), forearm: Seg(-18, 84)),
    Pose(upperArm: Seg(0, 70), forearm: Seg(0, 70)),
  ], yaw: 30, seconds: 1.6, loop: true),
  'Rotación de tronco': const MoveAnim([
    Pose(twist: -40, thigh: Seg(0, 10), upperArm: Seg(40, 30), forearm: Seg(90, -50)),
    Pose(twist: 40, thigh: Seg(0, 10), upperArm: Seg(40, 30), forearm: Seg(90, -50)),
  ], yaw: 10, seconds: 2.4, kind: DemoKind.mobility),
  'Gato-vaca': const MoveAnim([
    Pose(pitch: 90, trunk: -10, upperArm: Seg(90, 6), forearm: Seg(90, 4), thigh: Seg(90, 6), shin: Seg(0, 6)),
    Pose(pitch: 90, trunk: 8, upperArm: Seg(90, 6), forearm: Seg(90, 4), thigh: Seg(90, 6), shin: Seg(0, 6)),
  ], props: [Prop.floorMat], yaw: 80, seconds: 3.4, kind: DemoKind.mobility, elevation: 22),
  'Círculos de cadera': const MoveAnim([
    Pose(side: -9, thigh: Seg(0, 9), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(trunk: 8, thigh: Seg(0, 9), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(side: 9, thigh: Seg(0, 9), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(trunk: -8, thigh: Seg(0, 9), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
  ], yaw: 25, seconds: 2.4, loop: true),
  'Círculos de tobillos': const MoveAnim([
    Pose(rThigh: Seg(35, 4), rShin: Seg(5, 0), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(rThigh: Seg(35, 4), rShin: Seg(5, 14), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(rThigh: Seg(35, 4), rShin: Seg(18, 4), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
    Pose(rThigh: Seg(35, 4), rShin: Seg(5, -8), upperArm: Seg(-15, 38), forearm: Seg(55, -60)),
  ], yaw: 50, seconds: 1.6, loop: true),
  'El mejor estiramiento del mundo': const MoveAnim([
    Pose(trunk: 62, rThigh: Seg(92, 10), rShin: Seg(-4, 4), lThigh: Seg(-38, 4), lShin: Seg(-52, 4),
        lUpperArm: Seg(0, 4), lForearm: Seg(0, 4), rUpperArm: Seg(0, 10), rForearm: Seg(0, 10)),
    Pose(trunk: 62, twist: 45, rThigh: Seg(92, 10), rShin: Seg(-4, 4), lThigh: Seg(-38, 4), lShin: Seg(-52, 4),
        lUpperArm: Seg(0, 4), lForearm: Seg(0, 4), rUpperArm: Seg(160, 30), rForearm: Seg(165, 30)),
  ], yaw: 40, seconds: 3.2, kind: DemoKind.stretch),
  'Círculos de hombros': const MoveAnim([
    Pose(upperArm: Seg(12, 12), forearm: Seg(12, 10)),
    Pose(upperArm: Seg(0, 20), forearm: Seg(0, 16)),
    Pose(upperArm: Seg(-12, 12), forearm: Seg(-12, 10)),
    Pose(upperArm: Seg(0, 4), forearm: Seg(0, 4)),
  ], yaw: 50, seconds: 1.8, loop: true),
  'Apertura de brazos (sin banda)': const MoveAnim([
    Pose(upperArm: Seg(90, 2), forearm: Seg(90, 0)),
    Pose(upperArm: Seg(90, 84), forearm: Seg(90, 86)),
  ], yaw: 20, seconds: 2, kind: DemoKind.mobility),
  'Separación con banda': const MoveAnim([
    Pose(upperArm: Seg(90, 4), forearm: Seg(90, 2)),
    Pose(upperArm: Seg(90, 80), forearm: Seg(90, 84)),
  ], props: [Prop.band], yaw: 20, seconds: 2, kind: DemoKind.mobility),

  // ----- Vuelta a la calma -----
  'Estiramiento de cuádriceps': const MoveAnim([
    Pose(lThigh: Seg(0, 3), lShin: Seg(0, 3), rThigh: Seg(-18, 4), rShin: Seg(-148, 4),
        rUpperArm: Seg(-32, -6), rForearm: Seg(-38, -8), lUpperArm: Seg(0, 30), lForearm: Seg(10, 32)),
    Pose(trunk: 4, lThigh: Seg(0, 3), lShin: Seg(0, 3), rThigh: Seg(-22, 4), rShin: Seg(-152, 4),
        rUpperArm: Seg(-34, -6), rForearm: Seg(-42, -8), lUpperArm: Seg(0, 34), lForearm: Seg(10, 36)),
  ], yaw: 75, seconds: 4, kind: DemoKind.stretch),
  'Estiramiento de isquiotibiales': const MoveAnim([
    Pose(rThigh: Seg(28, 4), rShin: Seg(28, 4), lThigh: Seg(14, 4), lShin: Seg(-16, 4),
        upperArm: Seg(20, 6), forearm: Seg(30, 4)),
    Pose(trunk: 48, rThigh: Seg(28, 4), rShin: Seg(28, 4), lThigh: Seg(14, 4), lShin: Seg(-16, 4),
        upperArm: Seg(40, 6), forearm: Seg(40, 4)),
  ], yaw: 75, seconds: 4, kind: DemoKind.stretch),
  'Rodilla al pecho': const MoveAnim([
    Pose(pitch: -90, rThigh: Seg(145, 4), rShin: Seg(55, 4), lThigh: Seg(0, 3), lShin: Seg(0, 3),
        upperArm: Seg(110, 12), forearm: Seg(170, -30)),
    Pose(pitch: -90, rThigh: Seg(160, 4), rShin: Seg(65, 4), lThigh: Seg(0, 3), lShin: Seg(0, 3),
        upperArm: Seg(120, 12), forearm: Seg(175, -30)),
  ], props: [Prop.floorMat], yaw: 75, seconds: 4, kind: DemoKind.stretch, elevation: 35),
  'Flexor de cadera de rodillas': const MoveAnim([
    Pose(rThigh: Seg(80, 6), rShin: Seg(0, 4), lThigh: Seg(-15, 4), lShin: Seg(-92, 4),
        upperArm: Seg(-10, 34), forearm: Seg(55, -60)),
    Pose(rThigh: Seg(64, 6), rShin: Seg(-18, 4), lThigh: Seg(-35, 4), lShin: Seg(-100, 4),
        upperArm: Seg(-10, 34), forearm: Seg(55, -60)),
  ], yaw: 80, seconds: 4, kind: DemoKind.stretch),
  'Glúteo y espalda baja': const MoveAnim([
    Pose(pitch: -90, rThigh: Seg(75, -20), rShin: Seg(-10, -10), lThigh: Seg(0, 3), lShin: Seg(0, 3),
        upperArm: Seg(0, 80), forearm: Seg(0, 82)),
    Pose(pitch: -90, rThigh: Seg(80, -55), rShin: Seg(-10, -50), lThigh: Seg(0, 3), lShin: Seg(0, 3),
        upperArm: Seg(0, 80), forearm: Seg(0, 82)),
  ], props: [Prop.floorMat], yaw: 20, seconds: 4, kind: DemoKind.stretch, elevation: 38),
  'Pantorrillas en la pared': const MoveAnim([
    Pose(trunk: 18, rThigh: Seg(22, 4), rShin: Seg(-6, 4), lThigh: Seg(-20, 4), lShin: Seg(-20, 4),
        upperArm: Seg(70, 10), forearm: Seg(85, 6)),
    Pose(trunk: 24, rThigh: Seg(28, 4), rShin: Seg(-4, 4), lThigh: Seg(-26, 4), lShin: Seg(-26, 4),
        upperArm: Seg(68, 10), forearm: Seg(80, 6)),
  ], props: [Prop.wall], yaw: 80, seconds: 4, kind: DemoKind.stretch),
  'Pecho y hombro': const MoveAnim([
    Pose(rUpperArm: Seg(-10, 84), rForearm: Seg(178, 0)),
    Pose(twist: -22, rUpperArm: Seg(-25, 84), rForearm: Seg(178, -6)),
  ], yaw: 30, seconds: 4, kind: DemoKind.stretch),
  'Hombro cruzado': const MoveAnim([
    Pose(rUpperArm: Seg(85, -50), rForearm: Seg(88, -55), lUpperArm: Seg(30, 10), lForearm: Seg(110, -60)),
    Pose(rUpperArm: Seg(88, -70), rForearm: Seg(90, -78), lUpperArm: Seg(35, 6), lForearm: Seg(112, -70)),
  ], yaw: 25, seconds: 4, kind: DemoKind.stretch),
  'Postura del niño': const MoveAnim([
    Pose(trunk: 112, thigh: Seg(72, 10), shin: Seg(-88, 8), upperArm: Seg(100, 12), forearm: Seg(98, 8)),
    Pose(trunk: 120, thigh: Seg(72, 10), shin: Seg(-88, 8), upperArm: Seg(98, 12), forearm: Seg(96, 8)),
  ], props: [Prop.floorMat], yaw: 80, seconds: 4.5, kind: DemoKind.stretch, elevation: 25),
};

/// La animación del ejercicio o paso llamado [name], si existe.
MoveAnim? animFor(String name) => _anims[name];

/// Qué demostración mostrar para un ejercicio: el maniquí animado o, si no
/// tiene animación, la figura anatómica estática.
sealed class ExerciseDemo {
  const ExerciseDemo();
}

class AnimatedDemo extends ExerciseDemo {
  const AnimatedDemo(this.anim);

  final MoveAnim anim;
}

class StaticDemo extends ExerciseDemo {
  const StaticDemo();
}

/// Resolvedor único de demostraciones por nombre de ejercicio o paso.
ExerciseDemo demoFor(String? name) {
  final anim = name == null ? null : _anims[name];
  return anim == null ? const StaticDemo() : AnimatedDemo(anim);
}

/// Nombres con animación (para pruebas).
Iterable<String> get animatedNames => _anims.keys;
