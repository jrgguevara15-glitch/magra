import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formulas/formulas.dart' show Sex;
import '../../core/theme.dart';
import 'body_map.dart';

/// Si los maniquíes se animan (las pruebas lo apagan).
final figureAnimationProvider = Provider<bool>((ref) => true);

/// Dirección de un segmento en el marco del cuerpo: [flex] lo lleva de
/// abajo hacia adelante (0 = colgando, 90 = al frente, 180 = arriba,
/// negativo = atrás) y [abd] lo abre hacia el costado.
class Seg {
  const Seg(this.flex, [this.abd = 0]);

  final double flex;
  final double abd;

  static Seg lerp(Seg a, Seg b, double t) =>
      Seg(a.flex + (b.flex - a.flex) * t, a.abd + (b.abd - a.abd) * t);
}

/// Una pose del maniquí con ángulos absolutos (en grados) en el marco del
/// cuerpo. [pitch] inclina todo el cuerpo (−90 = acostado boca arriba,
/// 90 = boca abajo); [trunk] inclina el torso hacia adelante desde la
/// pelvis; [twist] lo gira y [side] lo dobla hacia un lado.
class Pose {
  const Pose({
    this.pitch = 0,
    this.trunk = 0,
    this.twist = 0,
    this.side = 0,
    Seg? upperArm,
    Seg? forearm,
    Seg? thigh,
    Seg? shin,
    Seg? lUpperArm,
    Seg? lForearm,
    Seg? lThigh,
    Seg? lShin,
    Seg? rUpperArm,
    Seg? rForearm,
    Seg? rThigh,
    Seg? rShin,
    this.rootY,
    this.armsWithTrunk = false,
  })  : lUpperArm = lUpperArm ?? upperArm ?? const Seg(0, 8),
        rUpperArm = rUpperArm ?? upperArm ?? const Seg(0, 8),
        lForearm = lForearm ?? forearm ?? upperArm ?? const Seg(5, 6),
        rForearm = rForearm ?? forearm ?? upperArm ?? const Seg(5, 6),
        lThigh = lThigh ?? thigh ?? const Seg(0, 3),
        rThigh = rThigh ?? thigh ?? const Seg(0, 3),
        lShin = lShin ?? shin ?? thigh ?? const Seg(0, 3),
        rShin = rShin ?? shin ?? thigh ?? const Seg(0, 3);

  final double pitch;
  final double trunk;
  final double twist;
  final double side;
  final Seg lUpperArm, rUpperArm, lForearm, rForearm;
  final Seg lThigh, rThigh, lShin, rShin;

  /// Altura fija de la pelvis (p. ej. sentado o en banco). Si es `null`,
  /// el punto más bajo del cuerpo toca el suelo.
  final double? rootY;

  /// Los brazos se miden desde el torso (se inclinan con él).
  final bool armsWithTrunk;

  static Pose lerp(Pose a, Pose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return Pose(
      pitch: l(a.pitch, b.pitch),
      trunk: l(a.trunk, b.trunk),
      twist: l(a.twist, b.twist),
      side: l(a.side, b.side),
      lUpperArm: Seg.lerp(a.lUpperArm, b.lUpperArm, t),
      rUpperArm: Seg.lerp(a.rUpperArm, b.rUpperArm, t),
      lForearm: Seg.lerp(a.lForearm, b.lForearm, t),
      rForearm: Seg.lerp(a.rForearm, b.rForearm, t),
      lThigh: Seg.lerp(a.lThigh, b.lThigh, t),
      rThigh: Seg.lerp(a.rThigh, b.rThigh, t),
      lShin: Seg.lerp(a.lShin, b.lShin, t),
      rShin: Seg.lerp(a.rShin, b.rShin, t),
      rootY: a.rootY == null || b.rootY == null ? null : l(a.rootY!, b.rootY!),
      armsWithTrunk: b.armsWithTrunk,
    );
  }
}

/// Implementos que se dibujan con el maniquí.
enum Prop {
  none,
  barbellBack,
  barbellHands,
  dumbbells,
  dumbbellRight,
  goblet,
  bench,
  benchUnderHands,
  benchBack,
  box,
  floorMat,
  cableForward,
  cableHigh,
  cableSide,
  band,
  wall,
  bar,
  footPlate,
}

/// Animación de un ejercicio: poses clave que se recorren ida y vuelta.
class MoveAnim {
  const MoveAnim(this.keys, {this.props = const [], this.yaw = 35, this.seconds = 2.6, this.loop = false});

  final List<Pose> keys;
  final List<Prop> props;

  /// Ángulo de cámara inicial (0 = de frente, 90 = de lado).
  final double yaw;
  final double seconds;

  /// Recorre las poses en círculo (en vez de ida y vuelta).
  final bool loop;

  /// La pose en el instante [phase] (0–1) del ciclo.
  Pose at(double phase) {
    if (keys.length == 1) return keys.first;
    final n = keys.length;
    double pos;
    if (loop) {
      pos = phase * n;
    } else {
      // Ida y vuelta: 0 → n−1 → 0.
      final p = phase < 0.5 ? phase * 2 : 2 - phase * 2;
      pos = p * (n - 1);
    }
    final i = pos.floor() % n;
    final j = loop ? (i + 1) % n : min(i + 1, n - 1);
    final t = pos - pos.floor();
    final eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
    return Pose.lerp(keys[i], keys[j], eased.toDouble());
  }
}

// ---------------------------------------------------------------------------
// Geometría 3D
// ---------------------------------------------------------------------------

class V3 {
  const V3(this.x, this.y, this.z);

  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double get length => sqrt(x * x + y * y + z * z);
  V3 get unit => length == 0 ? this : this * (1 / length);
}

double _rad(double d) => d * pi / 180;

V3 _dir(Seg s, double sideSign) {
  final f = _rad(s.flex), a = _rad(s.abd);
  return V3(sideSign * sin(a), -cos(f) * cos(a), sin(f) * cos(a));
}

/// Medidas del maniquí (cm aproximados).
class _Build {
  _Build(this.female);

  final bool female;
  double get k => female ? 0.94 : 1.0;
  double get shoulderHalf => (female ? 16.0 : 19.5) * k;
  double get hipHalf => (female ? 10.5 : 9.0) * k;
  double get lowerTorso => 18 * k;
  double get upperTorso => 34 * k;
  double get neck => 9 * k;
  double get head => 11 * k;
  double get upperArm => 30 * k;
  double get forearm => 27 * k;
  double get thigh => 44 * k;
  double get shin => 43 * k;
  double get rUpperTorso => (female ? 12.5 : 14.5) * k;
  double get rLowerTorso => (female ? 12.5 : 12.5) * k;
  double get rPelvis => (female ? 11.5 : 10) * k;
  double get rShoulder => (female ? 6.5 : 8) * k;
  double get rUpperArm => (female ? 4.6 : 5.6) * k;
  double get rForearm => (female ? 3.9 : 4.6) * k;
  double get rThigh => (female ? 8.4 : 8) * k;
  double get rShin => (female ? 5.2 : 5.6) * k;
}

/// Articulaciones en el mundo (y hacia arriba, z hacia la cámara).
class Skeleton {
  Skeleton(this.points, this.lateral);

  final Map<String, V3> points;

  /// Eje izquierda-derecha del cuerpo en el mundo (para barras).
  final V3 lateral;

  V3 operator [](String k) => points[k]!;
}

/// Calcula las articulaciones de [pose] (cinemática directa) y las apoya
/// en el suelo.
Skeleton solve(Pose pose, bool female) {
  final b = _Build(female);
  final pts = <String, V3>{};
  // Torso: inclinación adelante, lateral y giro.
  final t = _rad(pose.trunk), sd = _rad(pose.side);
  final torsoDir = V3(sin(sd), cos(t) * cos(sd), sin(t) * cos(sd)).unit;
  pts['pelvis'] = const V3(0, 0, 0);
  pts['waist'] = torsoDir * b.lowerTorso;
  pts['neck'] = torsoDir * (b.lowerTorso + b.upperTorso);
  pts['head'] = pts['neck']! + torsoDir * (b.neck + b.head);
  final tw = _rad(pose.twist);
  final shoulderAxis = V3(cos(tw), 0, -sin(tw));
  pts['lShoulder'] = pts['neck']! - shoulderAxis * b.shoulderHalf - torsoDir * 4;
  pts['rShoulder'] = pts['neck']! + shoulderAxis * b.shoulderHalf - torsoDir * 4;
  pts['lHip'] = const V3(-1, 0, 0) * b.hipHalf;
  pts['rHip'] = const V3(1, 0, 0) * b.hipHalf;
  for (final (side, sign) in [('l', -1.0), ('r', 1.0)]) {
    final ua = side == 'l' ? pose.lUpperArm : pose.rUpperArm;
    final fa = side == 'l' ? pose.lForearm : pose.rForearm;
    final th = side == 'l' ? pose.lThigh : pose.rThigh;
    final sh = side == 'l' ? pose.lShin : pose.rShin;
    final s = pts['${side}Shoulder']!;
    V3 arm(V3 v) => pose.armsWithTrunk ? V3(v.x, v.y * cos(t) - v.z * sin(t), v.y * sin(t) + v.z * cos(t)) : v;
    final e = s + arm(_dir(ua, sign)) * b.upperArm;
    final h = e + arm(_dir(fa, sign)) * b.forearm;
    final hip = pts['${side}Hip']!;
    final k = hip + _dir(th, sign) * b.thigh;
    final a = k + _dir(sh, sign) * b.shin;
    pts['${side}Elbow'] = e;
    pts['${side}Hand'] = h;
    pts['${side}Knee'] = k;
    pts['${side}Ankle'] = a;
    // Pie: hacia adelante, perpendicular a la canilla.
    final shinDir = (a - k).unit;
    final fwd = V3(0, 0, 1);
    final toe = (fwd - shinDir * (fwd.x * shinDir.x + fwd.y * shinDir.y + fwd.z * shinDir.z)).unit;
    pts['${side}Toe'] = a + toe * 13 * b.k;
  }
  // Inclinación de todo el cuerpo (eje x).
  final p = _rad(pose.pitch);
  V3 rot(V3 v) => V3(v.x, v.y * cos(p) - v.z * sin(p), v.y * sin(p) + v.z * cos(p));
  final out = {for (final e in pts.entries) e.key: rot(e.value)};
  // Apoyo: la pelvis a una altura fija o lo más bajo en el suelo.
  double dy;
  if (pose.rootY != null) {
    dy = pose.rootY! - out['pelvis']!.y;
  } else {
    var minY = double.infinity;
    for (final e in out.entries) {
      final r = e.key == 'head' ? b.head : (e.key.endsWith('Toe') || e.key.endsWith('Hand') ? 3 : 5);
      minY = min(minY, e.value.y - r);
    }
    dy = -minY;
  }
  // Centro: entre los pies en el suelo.
  final cx = (out['lAnkle']!.x + out['rAnkle']!.x) / 2;
  final cz = (out['lAnkle']!.z + out['rAnkle']!.z + out['pelvis']!.z * 2) / 4;
  final shift = V3(-cx, dy, -cz);
  final shifted = {for (final e in out.entries) e.key: e.value + shift};
  final lateral = (shifted['rShoulder']! - shifted['lShoulder']!).unit;
  return Skeleton(shifted, lateral);
}

/// Encuadre de una animación: centro en el suelo, radio horizontal y
/// altura máxima de todo el recorrido, para que la cámara no salte.
class Framing {
  const Framing(this.cx, this.cz, this.radius, this.top);

  final double cx, cz, radius, top;

  factory Framing.of(Iterable<Skeleton> skeletons) {
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity, top = 0.0;
    final all = [for (final s in skeletons) ...s.points.values];
    for (final p in all) {
      minX = min(minX, p.x);
      maxX = max(maxX, p.x);
      minZ = min(minZ, p.z);
      maxZ = max(maxZ, p.z);
      top = max(top, p.y);
    }
    final cx = (minX + maxX) / 2, cz = (minZ + maxZ) / 2;
    var radius = 0.0;
    for (final p in all) {
      radius = max(radius, sqrt((p.x - cx) * (p.x - cx) + (p.z - cz) * (p.z - cz)));
    }
    return Framing(cx, cz, radius + 14, top + 14);
  }

  /// Encuadre de [anim] muestreando el ciclo completo.
  factory Framing.ofAnim(MoveAnim anim, bool female) =>
      Framing.of([for (var i = 0; i <= 12; i++) solve(anim.at(i / 12), female)]);
}

// ---------------------------------------------------------------------------
// Dibujo
// ---------------------------------------------------------------------------

class _Prim {
  _Prim.capsule(this.a, this.b, this.r, this.color) : sphere = false;
  _Prim.sphere(this.a, this.r, this.color)
      : b = a,
        sphere = true;

  final V3 a;
  final V3 b;
  final double r;
  final Color color;
  final bool sphere;
}

const _base = Color(0xFF55648A);
const _baseFemale = Color(0xFF6A5F92);
const _steel = Color(0xFFB8C2DA);
const _plate = Color(0xFF2A3148);

class MannequinPainter extends CustomPainter {
  MannequinPainter({
    required this.pose,
    required this.female,
    required this.yaw,
    required this.primary,
    required this.secondary,
    this.props = const [],
    this.framing,
  });

  final Pose pose;
  final bool female;

  /// Grados de giro de la cámara alrededor del cuerpo.
  final double yaw;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;
  final List<Prop> props;

  /// Encuadre fijo; si falta, se encuadra la pose sola.
  final Framing? framing;

  Color _tone(Set<Muscle> zone) {
    if (zone.any(primary.contains)) return primaryColor;
    if (zone.any(secondary.contains)) return secondaryColor;
    return female ? _baseFemale : _base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sk = solve(pose, female);
    final b = _Build(female);
    final prims = <_Prim>[];
    final upper = _tone({Muscle.chest, Muscle.lats, Muscle.midBack, Muscle.traps});
    final lower = _tone({Muscle.abs, Muscle.obliques, Muscle.lowerBack});
    final glutes = _tone({Muscle.glutes});
    final thighs = _tone({Muscle.quads, Muscle.hamstrings, Muscle.adductors});
    final shins = _tone({Muscle.calves});
    final upperArms = _tone({Muscle.biceps, Muscle.triceps});
    final forearms = _tone({Muscle.forearms});
    final shoulders = _tone({Muscle.shoulders});
    final neutral = female ? _baseFemale : _base;

    prims.add(_Prim.capsule(sk['pelvis'], sk['waist'], b.rLowerTorso, lower));
    prims.add(_Prim.capsule(sk['waist'], sk['neck'] - (sk['neck'] - sk['waist']).unit * 5, b.rUpperTorso, upper));
    prims.add(_Prim.sphere(sk['pelvis'], b.rPelvis, glutes));
    prims.add(_Prim.capsule(sk['neck'], sk['neck'] + (sk['head'] - sk['neck']).unit * b.neck, 4.5 * b.k, neutral));
    prims.add(_Prim.sphere(sk['head'], b.head, neutral));
    if (female) {
      final fwd = _forward(sk);
      final chest = sk['neck'] + (sk['waist'] - sk['neck']) * 0.38;
      prims.add(_Prim.sphere(chest + fwd * 8 - sk.lateral * 6, 7, upper));
      prims.add(_Prim.sphere(chest + fwd * 8 + sk.lateral * 6, 7, upper));
    }
    for (final s in ['l', 'r']) {
      prims.add(_Prim.sphere(sk['${s}Shoulder'], b.rShoulder, shoulders));
      prims.add(_Prim.capsule(sk['${s}Shoulder'], sk['${s}Elbow'], b.rUpperArm, upperArms));
      prims.add(_Prim.capsule(sk['${s}Elbow'], sk['${s}Hand'], b.rForearm, forearms));
      prims.add(_Prim.sphere(sk['${s}Hand'], 4 * b.k, neutral));
      prims.add(_Prim.sphere(sk['${s}Hip'], b.rThigh, glutes));
      prims.add(_Prim.capsule(sk['${s}Hip'], sk['${s}Knee'], b.rThigh, thighs));
      prims.add(_Prim.capsule(sk['${s}Knee'], sk['${s}Ankle'], b.rShin, shins));
      prims.add(_Prim.capsule(sk['${s}Ankle'], sk['${s}Toe'], 3.6 * b.k, neutral));
    }
    _addHeldProps(sk, prims);

    // Cámara.
    final fr = framing ?? Framing.of([sk]);
    final y = _rad(yaw);
    V3 view(V3 v) {
      final x = v.x - fr.cx, z = v.z - fr.cz;
      return V3(x * cos(y) + z * sin(y), v.y, -x * sin(y) + z * cos(y));
    }

    const d = 520.0;
    final scale = min(size.height * 0.88 / max(fr.top, 120), size.width * 0.8 / (2 * fr.radius));
    final cx = size.width / 2, cy = size.height * 0.93;
    Offset proj(V3 v) {
      final w = view(v);
      final f = d / (d - w.z);
      return Offset(cx + w.x * f * scale, cy - w.y * f * scale);
    }

    double depth(_Prim p) => (view(p.a).z + view(p.b).z) / 2;
    double rad(_Prim p) => p.r * d / (d - (view(p.a).z + view(p.b).z) / 2) * scale;

    // Suelo y sombra.
    canvas.drawOval(
      Rect.fromCenter(center: proj(V3(fr.cx, 0, fr.cz)), width: 150 * scale, height: 26 * scale),
      Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    _drawFixedProps(canvas, sk, proj, scale);

    prims.sort((a, b) => depth(a).compareTo(depth(b)));
    for (final p in prims) {
      final r = rad(p);
      final a = proj(p.a);
      if (p.sphere) {
        canvas.drawCircle(a, r, Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [Color.lerp(p.color, Colors.white, 0.35)!, p.color, Color.lerp(p.color, Colors.black, 0.35)!],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: a, radius: r)));
      } else {
        final bb = proj(p.b);
        final base = Paint()
          ..color = Color.lerp(p.color, Colors.black, 0.18)!
          ..strokeWidth = r * 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(a, bb, base);
        final mid = Paint()
          ..color = p.color
          ..strokeWidth = r * 1.4
          ..strokeCap = StrokeCap.round;
        final off = Offset(-r * 0.18, -r * 0.18);
        canvas.drawLine(a + off, bb + off, mid);
        final hi = Paint()
          ..color = Color.lerp(p.color, Colors.white, 0.35)!.withValues(alpha: 0.8)
          ..strokeWidth = r * 0.45
          ..strokeCap = StrokeCap.round;
        final off2 = Offset(-r * 0.42, -r * 0.42);
        canvas.drawLine(a + off2, bb + off2, hi);
      }
    }
    _drawLines(canvas, sk, proj, scale);
  }

  V3 _forward(Skeleton sk) {
    final up = (sk['neck'] - sk['pelvis']).unit;
    final l = sk.lateral;
    // adelante = lateral × arriba
    return V3(l.y * up.z - l.z * up.y, l.z * up.x - l.x * up.z, l.x * up.y - l.y * up.x).unit;
  }

  void _addHeldProps(Skeleton sk, List<_Prim> prims) {
    final lat = sk.lateral;
    for (final p in props) {
      switch (p) {
        case Prop.barbellBack:
        case Prop.barbellHands:
          final c = p == Prop.barbellBack
              ? sk['neck'] - _forward(sk) * 9 - (sk['neck'] - sk['pelvis']).unit * 3
              : (sk['lHand'] + sk['rHand']) * 0.5;
          prims.add(_Prim.capsule(c - lat * 78, c + lat * 78, 1.6, _steel));
          for (final s in [-1.0, 1.0]) {
            prims.add(_Prim.capsule(c + lat * (s * 60), c + lat * (s * 68), 11, _plate));
          }
        case Prop.dumbbells:
        case Prop.dumbbellRight:
        case Prop.goblet:
          final hands = p == Prop.dumbbellRight
              ? ['rHand']
              : p == Prop.goblet
                  ? <String>[]
                  : ['lHand', 'rHand'];
          for (final h in hands) {
            final c = sk[h];
            prims.add(_Prim.capsule(c - lat * 10, c + lat * 10, 2, _steel));
            prims.add(_Prim.capsule(c - lat * 12, c - lat * 8, 6.5, _plate));
            prims.add(_Prim.capsule(c + lat * 8, c + lat * 12, 6.5, _plate));
          }
          if (p == Prop.goblet) {
            final c = (sk['lHand'] + sk['rHand']) * 0.5;
            final up = (sk['neck'] - sk['pelvis']).unit;
            prims.add(_Prim.capsule(c - up * 8, c + up * 8, 2.2, _steel));
            prims.add(_Prim.capsule(c - up * 11, c - up * 7, 7, _plate));
            prims.add(_Prim.capsule(c + up * 7, c + up * 11, 7, _plate));
          }
        case Prop.bar:
          final c = (sk['lHand'] + sk['rHand']) * 0.5;
          prims.add(_Prim.capsule(c - lat * 60, c + lat * 60, 1.8, _steel));
        default:
          break;
      }
    }
  }

  void _drawFixedProps(Canvas canvas, Skeleton sk, Offset Function(V3) proj, double scale) {
    final fill = Paint()..color = const Color(0xFF2B3550);
    final edge = Paint()
      ..color = const Color(0xFF4A5778)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    void box(V3 center, double w, double l, double h, V3 along) {
      final a = along.unit;
      final side = V3(-a.z, 0, a.x).unit;
      final top = [
        center + a * (l / 2) + side * (w / 2),
        center + a * (l / 2) - side * (w / 2),
        center - a * (l / 2) - side * (w / 2),
        center - a * (l / 2) + side * (w / 2),
      ];
      final bottom = [for (final t in top) V3(t.x, 0, t.z)];
      for (var i = 0; i < 4; i++) {
        final face = Path()
          ..moveTo(proj(top[i]).dx, proj(top[i]).dy)
          ..lineTo(proj(top[(i + 1) % 4]).dx, proj(top[(i + 1) % 4]).dy)
          ..lineTo(proj(bottom[(i + 1) % 4]).dx, proj(bottom[(i + 1) % 4]).dy)
          ..lineTo(proj(bottom[i]).dx, proj(bottom[i]).dy)
          ..close();
        canvas.drawPath(face, fill);
        canvas.drawPath(face, edge);
      }
      final t = Path()..addPolygon([for (final p in top) proj(p)], true);
      canvas.drawPath(t, Paint()..color = const Color(0xFF3A4766));
      canvas.drawPath(t, edge);
      final _ = h;
    }

    final bodyAxis = sk['neck'] - sk['pelvis'];
    final flat = V3(bodyAxis.x, 0, bodyAxis.z);
    final along = flat.length < 1 ? const V3(0, 0, 1) : flat;
    for (final p in props) {
      switch (p) {
        case Prop.bench:
          final c = (sk['pelvis'] + sk['neck']) * 0.5;
          final topY = min(sk['pelvis'].y, sk['neck'].y) - 11;
          box(V3(c.x, topY, c.z), 28, 110, topY, along);
        case Prop.benchUnderHands:
          // Bajo la mano más baja (en el remo a una mano, la de apoyo).
          final l = sk['lHand'], r = sk['rHand'];
          final c = (l.y - r.y).abs() < 4 ? (l + r) * 0.5 : (l.y < r.y ? l : r);
          box(V3(c.x, c.y - 3, c.z), (l.y - r.y).abs() < 4 ? 90 : 40, 30, c.y, const V3(0, 0, 1));
        case Prop.benchBack:
          final c = sk['neck'] + (sk['waist'] - sk['neck']) * 0.3;
          box(V3(c.x, c.y - 12, c.z), 34, 110, c.y, const V3(1, 0, 0));
        case Prop.box:
          final c = sk['pelvis'] - _forward(sk) * 8;
          box(V3(c.x, max(20.0, sk['pelvis'].y - 10), c.z - 6), 34, 34, 40, const V3(0, 0, 1));
        case Prop.footPlate:
          final c = (sk['lAnkle'] + sk['rAnkle']) * 0.5;
          final n = (sk['lKnee'] + sk['rKnee']) * 0.5 - c;
          final u = n.unit;
          final s = sk.lateral;
          final v = V3(s.y * u.z - s.z * u.y, s.z * u.x - s.x * u.z, s.x * u.y - s.y * u.x).unit;
          final quad = [c + s * 25 + v * 22, c - s * 25 + v * 22, c - s * 25 - v * 22, c + s * 25 - v * 22];
          final path = Path()..addPolygon([for (final q in quad) proj(q - u * 3)], true);
          canvas.drawPath(path, Paint()..color = const Color(0xFF3A4766));
          canvas.drawPath(path, edge);
        case Prop.wall:
          final f = sk['lHand'].z > sk['pelvis'].z ? max(sk['lHand'].z, sk['rHand'].z) + 3 : 40.0;
          final quad = [V3(-60, 0, f), V3(60, 0, f), V3(60, 200, f), V3(-60, 200, f)];
          canvas.drawPath(Path()..addPolygon([for (final q in quad) proj(q)], true),
              Paint()..color = const Color(0x552B3550));
        case Prop.floorMat:
          final c = sk['pelvis'];
          final quad = [
            V3(c.x - 35, 0.2, c.z - 95), V3(c.x + 35, 0.2, c.z - 95),
            V3(c.x + 35, 0.2, c.z + 95), V3(c.x - 35, 0.2, c.z + 95),
          ];
          canvas.drawPath(Path()..addPolygon([for (final q in quad) proj(q)], true),
              Paint()..color = const Color(0x6622D3EE));
        default:
          break;
      }
    }
  }

  void _drawLines(Canvas canvas, Skeleton sk, Offset Function(V3) proj, double scale) {
    final cable = Paint()
      ..color = MagraColors.cyan.withValues(alpha: 0.9)
      ..strokeWidth = 1.6;
    final hands = (sk['lHand'] + sk['rHand']) * 0.5;
    for (final p in props) {
      switch (p) {
        case Prop.cableForward:
          canvas.drawLine(proj(hands), proj(V3(hands.x, sk['pelvis'].y, 120)), cable);
        case Prop.cableHigh:
          canvas.drawLine(proj(hands), proj(V3(hands.x, 230, hands.z)), cable);
        case Prop.cableSide:
          canvas.drawLine(proj(hands), proj(V3(-110, hands.y, hands.z)), cable);
        case Prop.band:
          canvas.drawLine(proj(sk['lHand']), proj(sk['rHand']),
              Paint()..color = MagraColors.lime..strokeWidth = 3..strokeCap = StrokeCap.round);
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(MannequinPainter old) => true;
}

/// Maniquí 3D sin rostro que hace el ejercicio en bucle y gira con el dedo.
class MannequinView extends ConsumerStatefulWidget {
  const MannequinView({
    super.key,
    required this.anim,
    required this.sex,
    required this.primary,
    this.secondary = const {},
    this.height = 300,
    this.controls = true,
    this.animate = true,
  });

  final MoveAnim anim;
  final Sex sex;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;
  final double height;
  final bool controls;

  /// `false` para miniaturas: muestra la pose final quieta.
  final bool animate;

  @override
  ConsumerState<MannequinView> createState() => _MannequinViewState();
}

class _MannequinViewState extends ConsumerState<MannequinView> with SingleTickerProviderStateMixin {
  late double _yaw = widget.anim.yaw;
  late Framing _framing = Framing.ofAnim(widget.anim, widget.sex == Sex.female);
  double _phase = 0.5;
  bool _playing = true;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  bool get _canAnimate {
    final enabled = ref.read(figureAnimationProvider);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return widget.animate && enabled && !reduce;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(MannequinView old) {
    super.didUpdateWidget(old);
    if (old.anim != widget.anim || old.sex != widget.sex) {
      _framing = Framing.ofAnim(widget.anim, widget.sex == Sex.female);
    }
    if (old.anim != widget.anim) {
      _yaw = widget.anim.yaw;
      _phase = _canAnimate ? 0 : 0.5;
    }
  }

  void _syncTicker() {
    final run = _canAnimate && _playing;
    if (run && _ticker == null) {
      _phase = 0;
      _last = Duration.zero;
      _ticker = createTicker((elapsed) {
        final dt = (elapsed - _last).inMicroseconds / 1e6;
        _last = elapsed;
        setState(() => _phase = (_phase + dt / widget.anim.seconds) % 1);
      })..start();
    } else if (!run && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _setYaw(double y) => setState(() => _yaw = y);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final painter = MannequinPainter(
      pose: widget.anim.at(_phase),
      female: widget.sex == Sex.female,
      yaw: _yaw,
      primary: widget.primary,
      secondary: widget.secondary,
      props: widget.anim.props,
      framing: _framing,
    );
    final figure = GestureDetector(
      onHorizontalDragUpdate: (d) => _setYaw(_yaw - d.delta.dx * 0.9),
      child: Semantics(
        label: 'Maniquí ${widget.sex == Sex.female ? 'de mujer' : 'de hombre'} haciendo el ejercicio. '
            'Desliza para girarlo.',
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(painter: painter),
        ),
      ),
    );
    if (!widget.controls) return figure;
    return Column(
      children: [
        figure,
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, y) in [('Frente', 0.0), ('Lado', 90.0), ('Espalda', 180.0)])
              ChoiceChip(
                showCheckmark: false,
                label: Text(label),
                selected: ((_yaw % 360 + 360) % 360 - y).abs() < 1,
                onSelected: (_) => _setYaw(y),
              ),
            if (_canAnimate || !_playing)
              IconButton(
                tooltip: _playing ? 'Pausar' : 'Reproducir',
                onPressed: () {
                  setState(() => _playing = !_playing);
                  _syncTicker();
                },
                icon: Icon(_playing ? Icons.pause_circle_outline : Icons.play_circle_outline),
              ),
          ],
        ),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _Dot(color: primaryColor, label: 'Trabaja más'),
            _Dot(color: secondaryColor, label: 'Ayuda'),
          ],
        ),
        Text('Desliza el maniquí para girarlo en 360°.',
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
