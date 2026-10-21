import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'body_map.dart';
import 'mannequin.dart';

/// Acento de la figura femenina (cyan) y de la masculina (coral).
const avatarAccentFemale = Color(0xFF2EC9E0);
const avatarAccentMale = Color(0xFFFF7A59);

const _shirt = Color(0xFF474D59);
const _pants = Color(0xFF3A3F4A);
const _skin = Color(0xFFC79A7E);
const _hair = Color(0xFF2E2420);
const _shoe = Color(0xFF4A505C);
const _sole = Color(0xFFE6E8EC);
const _steel = Color(0xFFB9C1CF);
const _plate = Color(0xFF22262E);
const _pad = Color(0xFF262A33);
const _frame = Color(0xFF4A505C);

/// Una malla de triángulos con normal y color por vértice.
class _Mesh {
  final pos = <V3>[];
  final nrm = <V3>[];
  final col = <Color>[];
  final idx = <int>[];

  int add(V3 p, V3 n, Color c) {
    pos.add(p);
    nrm.add(n);
    col.add(c);
    return pos.length - 1;
  }

  void tri(int a, int b, int c) => idx.addAll([a, b, c]);
}

/// Un anillo de la superficie: centro, ejes y radios de la elipse.
class _Ring {
  _Ring(this.c, this.u, this.v, this.a, this.b);

  final V3 c, u, v;
  final double a, b;

  V3 at(double th) => c + u * (a * cos(th)) + v * (b * sin(th));
  V3 normal(double th) => (u * (cos(th) / a) + v * (sin(th) / b)).unit;
}

V3 _cross(V3 a, V3 b) => V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
double _dot(V3 a, V3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

/// Ejes perpendiculares a [axis], con `u` lo más cerca posible de [hint].
(V3, V3) _basis(V3 axis, V3 hint) {
  var u = hint - axis * _dot(hint, axis);
  if (u.length < 1e-3) {
    final alt = axis.y.abs() < 0.9 ? const V3(0, 1, 0) : const V3(1, 0, 0);
    u = alt - axis * _dot(alt, axis);
  }
  u = u.unit;
  return (u, _cross(axis, u).unit);
}

/// Componente de [v] perpendicular a [axis]; si casi no hay, [fallback].
V3 _perp(V3 v, V3 axis, V3 fallback) {
  final p = v - axis * _dot(v, axis);
  return p.length < 0.25 ? fallback.unit : p.unit;
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Color de un vértice según la parte (t a lo largo, normal) del cuerpo.
typedef _Shade = Color Function(double t, V3 n);

/// Inserta [k] anillos intermedios entre cada par (superficie más fina).
List<_Ring> _dense(List<_Ring> rings, int k) {
  final out = <_Ring>[];
  for (var i = 0; i + 1 < rings.length; i++) {
    final a = rings[i], b = rings[i + 1];
    for (var j = 0; j <= k; j++) {
      final t = j / (k + 1);
      out.add(_Ring(a.c + (b.c - a.c) * t, (a.u + (b.u - a.u) * t).unit, (a.v + (b.v - a.v) * t).unit,
          a.a + (b.a - a.a) * t, a.b + (b.b - a.b) * t));
    }
  }
  out.add(rings.last);
  return out;
}

/// Superficie que une los anillos, con tapas redondeadas (o planas).
void _loft(_Mesh m, List<_Ring> rings, _Shade shade,
    {int seg = 16, bool roundStart = true, bool roundEnd = true, int dense = 2}) {
  rings = _dense(rings, dense);
  final all = <(_Ring, double, double, V3)>[]; // anillo, t, inclinación de la normal, eje
  final d0 = (rings[1].c - rings[0].c).unit;
  final d1 = (rings.last.c - rings[rings.length - 2].c).unit;
  void cap(_Ring r, V3 dir, bool start, bool round) {
    final phis = round ? [70.0, 45.0, 20.0] : [89.0];
    final list = <(_Ring, double, double, V3)>[];
    for (final phi in phis) {
      final p = phi * pi / 180;
      final reach = round ? (r.a + r.b) / 2 * sin(p) : 0.0;
      list.add((
        _Ring(r.c + dir * (start ? -reach : reach), r.u, r.v, max(r.a * cos(p), 0.05), max(r.b * cos(p), 0.05)),
        start ? 0.0 : 1.0,
        start ? -p : p,
        dir,
      ));
    }
    if (start) {
      all.addAll(list);
    } else {
      all.addAll(list.reversed);
    }
  }

  cap(rings.first, d0, true, roundStart);
  for (var i = 0; i < rings.length; i++) {
    // La normal se inclina hacia donde la superficie se angosta.
    final prev = rings[max(i - 1, 0)], next = rings[min(i + 1, rings.length - 1)];
    final along = next.c - prev.c;
    final dr = ((next.a + next.b) - (prev.a + prev.b)) / 2;
    all.add((rings[i], i / (rings.length - 1), atan2(-dr, along.length), along.unit));
  }
  cap(rings.last, d1, false, roundEnd);

  final ids = <List<int>>[];
  for (final (r, t, tilt, axis) in all) {
    final row = <int>[];
    for (var j = 0; j < seg; j++) {
      final th = 2 * pi * j / seg;
      var n = r.normal(th);
      if (tilt != 0) n = (n * cos(tilt) + axis * sin(tilt)).unit;
      row.add(m.add(r.at(th), n, shade(t, n)));
    }
    ids.add(row);
  }
  for (var i = 0; i + 1 < ids.length; i++) {
    for (var j = 0; j < seg; j++) {
      final a = ids[i][j], b = ids[i][(j + 1) % seg];
      final c = ids[i + 1][j], d = ids[i + 1][(j + 1) % seg];
      m.tri(a, c, b);
      m.tri(b, c, d);
    }
  }
  // Polos.
  final r0 = rings.first, r1 = rings.last;
  final p0 = roundStart ? r0.c - d0 * ((r0.a + r0.b) / 2) : r0.c;
  final p1 = roundEnd ? r1.c + d1 * ((r1.a + r1.b) / 2) : r1.c;
  final pole0 = m.add(p0, d0 * -1, shade(0, d0 * -1));
  final pole1 = m.add(p1, d1, shade(1, d1));
  for (var j = 0; j < seg; j++) {
    m.tri(pole0, ids.first[j], ids.first[(j + 1) % seg]);
    m.tri(pole1, ids.last[(j + 1) % seg], ids.last[j]);
  }
}

/// Cilindro (o cápsula) entre [a] y [b].
void _tube(_Mesh m, V3 a, V3 b, double r, Color c, {bool round = false, int seg = 12, double? r2}) {
  final axis = (b - a).unit;
  final (u, v) = _basis(axis, const V3(0, 1, 0));
  _loft(m, [_Ring(a, u, v, r, r), _Ring(b, u, v, r2 ?? r, r2 ?? r)], (t, n) => c,
      seg: seg, roundStart: round, roundEnd: round, dense: 0);
}

/// Caja subdividida (para bancos, cajones y la prensa).
void _box(_Mesh m, V3 center, V3 ax, V3 ay, V3 az, Color c, {int div = 3}) {
  // ax, ay, az: semiejes.
  for (final (n, s, t) in [
    (ax, ay, az), (ax * -1, az, ay), (ay, az, ax), (ay * -1, ax, az), (az, ax, ay), (az * -1, ay, ax),
  ]) {
    final nu = n.unit;
    final ids = <List<int>>[];
    for (var i = 0; i <= div; i++) {
      final row = <int>[];
      for (var j = 0; j <= div; j++) {
        final p = center + n + s * (2 * i / div - 1) + t * (2 * j / div - 1);
        row.add(m.add(p, nu, c));
      }
      ids.add(row);
    }
    for (var i = 0; i < div; i++) {
      for (var j = 0; j < div; j++) {
        m.tri(ids[i][j], ids[i + 1][j], ids[i][j + 1]);
        m.tri(ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]);
      }
    }
  }
}

/// Franja fina sobre la superficie (costuras de acento).
void _ribbon(_Mesh m, List<V3> pts, List<V3> normals, List<V3> across, double w, Color c) {
  final ids = <(int, int)>[];
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i] + normals[i] * 0.35;
    ids.add((m.add(p - across[i] * (w / 2), normals[i], c), m.add(p + across[i] * (w / 2), normals[i], c)));
  }
  for (var i = 0; i + 1 < ids.length; i++) {
    m.tri(ids[i].$1, ids[i + 1].$1, ids[i].$2);
    m.tri(ids[i + 1].$1, ids[i + 1].$2, ids[i].$2);
  }
}

/// Cámara fija un poco elevada que mira hacia abajo, girada [yaw] grados
/// alrededor del cuerpo.
class _Camera {
  _Camera(this.framing, double yaw, this.size, {double elevation = 13})
      : _cy = cos(yaw * pi / 180),
        _sy = sin(yaw * pi / 180),
        _ce = cos(elevation * pi / 180),
        _se = sin(elevation * pi / 180),
        scale = min(size.height * 0.88 / max(framing.top, 120), size.width * 0.8 / (2 * framing.radius));

  static const d = 520.0;
  final Framing framing;
  final Size size;
  final double _cy, _sy, _ce, _se;
  final double scale;

  double get _py => framing.top * 0.45;

  V3 view(V3 v) {
    final x = v.x - framing.cx, z = v.z - framing.cz;
    final zx = -x * _sy + z * _cy;
    final yy = v.y - _py;
    return V3(x * _cy + z * _sy, yy * _ce - zx * _se + _py, yy * _se + zx * _ce);
  }

  V3 viewDir(V3 v) {
    final zx = -v.x * _sy + v.z * _cy;
    return V3(v.x * _cy + v.z * _sy, v.y * _ce - zx * _se, v.y * _se + zx * _ce);
  }

  Offset project(V3 w) {
    final f = d / (d - w.z);
    return Offset(size.width / 2 + w.x * f * scale, size.height * 0.9 - w.y * f * scale);
  }

  Offset proj(V3 v) => project(view(v));
}

/// Píxeles RGBA del maniquí.
class MannequinPixels {
  const MannequinPixels(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width, height;

  Future<ui.Image> toImage() {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }
}

/// Maniquí 3D vestido (camiseta, pantalón largo, zapatillas), sin rostro,
/// con sombreado suave y los músculos trabajados teñidos sobre la ropa.
class MannequinPainter extends CustomPainter {
  MannequinPainter({
    required this.pose,
    required this.female,
    required this.yaw,
    required this.primary,
    required this.secondary,
    this.props = const [],
    this.framing,
    this.showMuscles = true,
    this.image,
    this.elevation = 13,
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

  /// Tiñe sobre la figura lo que trabaja (rojo) y lo que ayuda (naranja).
  final bool showMuscles;

  /// El maniquí ya dibujado por [rasterize] (si aún no está, solo el piso).
  final ui.Image? image;

  /// Grados que la cámara mira hacia abajo (más alto para ejercicios
  /// acostados, así se ven el torso y los brazos).
  final double elevation;

  Color get accent => female ? avatarAccentFemale : avatarAccentMale;

  /// Mezcla el color con el tono del músculo según cuánto pertenece a la zona.
  Color _tint(Color base, Map<Muscle, double> zones) {
    if (!showMuscles) return base;
    var p = 0.0, s = 0.0;
    zones.forEach((mu, w) {
      if (primary.contains(mu)) p = max(p, w);
      if (secondary.contains(mu)) s = max(s, w);
    });
    if (p > 0.01) return Color.lerp(base, primaryColor, 0.78 * p)!;
    if (s > 0.01) return Color.lerp(base, secondaryColor, 0.7 * s)!;
    return base;
  }

  _Mesh _build(Skeleton sk) {
    final m = _Mesh();
    final k = female ? 0.94 : 1.0;
    final pelvis = sk['pelvis'], neck = sk['neck'];
    final axis = (neck - pelvis).unit;
    final hipLat = (sk['rHip'] - sk['lHip']).unit;
    final shLat = (sk['rShoulder'] - sk['lShoulder']).unit;
    final fwdTop = _cross(shLat, axis).unit;
    final len = (neck - pelvis).length;

    // ----- Torso: de la cadera al cuello -----
    final spec = female
        ? [(-7.0, 14.6, 10.6, 0.0), (0.0, 15.6, 11.0, 0.0), (11.0, 12.0, 8.6, 0.0), (22.0, 12.8, 9.0, 0.6),
           (31.0, 13.4, 10.6, 1.4), (39.0, 14.8, 9.4, 0.6), (45.0, 13.2, 7.6, 0.0), (49.0, 7.5, 5.0, 0.0)]
        : [(-7.0, 13.2, 9.8, 0.0), (0.0, 14.6, 10.4, 0.0), (11.0, 13.4, 9.4, 0.0), (22.0, 15.0, 10.2, 0.3),
           (32.0, 17.0, 11.2, 0.8), (40.0, 18.6, 10.4, 0.4), (46.0, 15.0, 8.2, 0.0), (51.0, 7.8, 5.2, 0.0)];
    final rings = <_Ring>[];
    final ringLat = <V3>[];
    for (final (h0, a, b, fwd) in spec) {
      final h = h0 / 51 * len;
      final w = _smooth(8, 30, h0);
      final lat = (hipLat * (1 - w) + shLat * w).unit;
      final (u, v) = _basis(axis, lat);
      final vv = _dot(v, fwdTop) < 0 ? v * -1 : v;
      rings.add(_Ring(pelvis + axis * h + vv * fwd, u, vv, a * k, b * k));
      ringLat.add(u);
    }
    final fwd0 = rings.first.v;
    _loft(m, rings, (t, n) {
      // Altura aproximada sobre la cadera (las tallas están en cm de la tabla).
      final f = _dot(n, fwdTop), up = -7 + t * (spec.last.$1 + 7);
      final side = _dot(n, shLat).abs();
      final isPants = up < 4;
      var c = isPants ? _pants : _shirt;
      if (!isPants) {
        c = _tint(c, {
          Muscle.chest: _smooth(0.2, 0.6, f) * _smooth(24, 32, up),
          Muscle.abs: _smooth(0.35, 0.75, f) * (1 - _smooth(22, 28, up)),
          Muscle.obliques: _smooth(0.55, 0.85, side) * (1 - _smooth(24, 30, up)),
          Muscle.lats: _smooth(0.3, 0.7, -_dot(n, fwdTop) + side * 0.4) * _smooth(20, 26, up) * (1 - _smooth(38, 44, up)),
          Muscle.midBack: _smooth(0.55, 0.9, -f) * _smooth(26, 32, up) * (1 - _smooth(40, 44, up)),
          Muscle.traps: _smooth(0.0, 0.5, -f + 0.2) * _smooth(41, 46, up),
          Muscle.lowerBack: _smooth(0.55, 0.9, -f) * (1 - _smooth(16, 22, up)) * _smooth(0, 4, up),
          Muscle.shoulders: _smooth(0.75, 0.95, side) * _smooth(38, 44, up),
        });
      } else {
        c = _tint(c, {Muscle.glutes: _smooth(0.25, 0.7, -_dot(n, fwd0)) * _smooth(-8, -3, up)});
      }
      return c;
    }, seg: 30);
    // Costuras laterales de la camiseta.
    for (final s in [-1.0, 1.0]) {
      final pts = <V3>[], ns = <V3>[], ac = <V3>[];
      for (var i = 2; i < rings.length - 2; i++) {
        final r = rings[i];
        final th = s > 0 ? 0.0 : pi;
        pts.add(r.at(th));
        ns.add(r.normal(th));
        ac.add(r.v);
      }
      _ribbon(m, pts, ns, ac, 0.9, accent);
    }

    // ----- Cuello y cabeza -----
    final headC = sk['head'];
    final headAxis = (headC - neck).unit;
    final neckTop = neck + headAxis * 8 * k;
    _tube(m, neck - axis * 3, neckTop, (female ? 4.6 : 5.4) * k, _skin, seg: 14, r2: (female ? 4.2 : 5.0) * k);
    final (hu, hv0) = _basis(headAxis, shLat);
    final hv = _dot(hv0, fwdTop) < 0 ? hv0 * -1 : hv0;
    final headRings = <_Ring>[];
    for (var i = 0; i <= 16; i++) {
      final a = -pi / 2 + pi * i / 16;
      final rr = cos(a);
      headRings.add(_Ring(headC + headAxis * (11.2 * k * sin(a)), hu, hv,
          max(8.3 * k * rr, 0.3), max(9.6 * k * rr, 0.3)));
    }
    _loft(m, headRings.sublist(1, 16), (t, n) {
      final up = _dot(n, headAxis), f = _dot(n, hv);
      final side = _dot(n, hu).abs();
      final hair = (up > 0.42 - 0.18 * f) || (f < -0.15 && up > -0.5) || (side > 0.82 && up > -0.05 && f < 0.35);
      return hair ? _hair : _skin;
    }, seg: 24, dense: 0);
    if (female) {
      final bun = headC + headAxis * 9.5 * k - hv * 7.5 * k;
      _tube(m, bun - headAxis * 2, bun + headAxis * 2.5, 4.8 * k, _hair, round: true, seg: 12);
    }

    // ----- Brazos -----
    for (final (s, sign) in [('l', -1.0), ('r', 1.0)]) {
      final sh = sk['${s}Shoulder'], el = sk['${s}Elbow'], wr = sk['${s}Hand'];
      final ua = (el - sh).unit, fa = (wr - el).unit;
      final outward = shLat * sign;
      final (u1, v1) = _basis(ua, outward);
      final ra = (female ? 5.2 : 6.3) * k, rb = (female ? 4.1 : 4.9) * k, rc = (female ? 2.9 : 3.4) * k;
      _loft(m, [
        _Ring(sh, u1, v1, ra * 1.05, ra),
        _Ring(sh + (el - sh) * 0.5, u1, v1, ra * 0.95, ra * 0.9),
        _Ring(el, u1, v1, rb, rb),
      ], (t, n) {
        final sleeve = t < 0.48;
        final front = _dot(n, _perp(fwdTop, ua, _cross(ua, shLat))), out = _dot(n, outward);
        final base = sleeve ? _shirt : _skin;
        return _tint(base, {
          Muscle.shoulders: 1 - _smooth(0.25, 0.45, t),
          Muscle.biceps: _smooth(0.0, 0.5, front) * _smooth(0.2, 0.4, t),
          Muscle.triceps: _smooth(0.0, 0.5, -front + out * 0.3) * _smooth(0.2, 0.4, t),
        });
      }, seg: 18);
      final (u2, v2) = _basis(fa, outward);
      _loft(m, [_Ring(el, u2, v2, rb, rb * 0.95), _Ring(el + (wr - el) * 0.4, u2, v2, rb * 0.95, rb * 0.85), _Ring(wr, u2, v2, rc * 1.1, rc * 0.8)],
          (t, n) => _tint(_skin, {Muscle.forearms: 1 - _smooth(0.7, 1, t)}), seg: 16);
      // Mano.
      final hand = wr + fa * 5.5 * k;
      final (u3, v3) = _basis(fa, outward);
      _loft(m, [
        _Ring(wr, u3, v3, 2.6 * k, 1.6 * k),
        _Ring(hand, u3, v3, 3.6 * k, 1.8 * k),
        _Ring(wr + fa * 9.5 * k, u3, v3, 2.6 * k, 1.5 * k),
      ], (t, n) => _skin, seg: 12);
    }

    // ----- Piernas y zapatillas -----
    for (final (s, sign) in [('l', -1.0), ('r', 1.0)]) {
      final hip = sk['${s}Hip'], kn = sk['${s}Knee'], an = sk['${s}Ankle'], toe = sk['${s}Toe'];
      final th = (kn - hip).unit, sh = (an - kn).unit;
      final outward = hipLat * sign;
      final r1 = (female ? 9.4 : 9.2) * k, r2 = (female ? 5.9 : 6.2) * k, r3 = (female ? 4.2 : 4.5) * k;
      final (u1, v1) = _basis(th, outward);
      _loft(m, [
        _Ring(hip + th * 2, u1, v1, r1, r1 * 0.95),
        _Ring(hip + (kn - hip) * 0.45, u1, v1, r1 * 0.86, r1 * 0.84),
        _Ring(kn, u1, v1, r2, r2),
      ], (t, n) {
        final frontish = _dot(n, _cross(th, hipLat).unit), inner = -_dot(n, outward);
        return _tint(_pants, {
          Muscle.quads: _smooth(-0.1, 0.45, frontish) * (1 - _smooth(0.85, 1, t)),
          Muscle.hamstrings: _smooth(-0.1, 0.45, -frontish) * (1 - _smooth(0.85, 1, t)),
          Muscle.adductors: _smooth(0.5, 0.85, inner) * (1 - _smooth(0.55, 0.8, t)),
          Muscle.glutes: _smooth(0.2, 0.6, -frontish) * (1 - _smooth(0.0, 0.18, t)),
        });
      }, seg: 22);
      final (u2, v2) = _basis(sh, outward);
      _loft(m, [
        _Ring(kn, u2, v2, r2, r2),
        _Ring(kn + (an - kn) * 0.35, u2, v2, r2 * 0.98, r2 * 1.02),
        _Ring(an - sh * 2, u2, v2, r3, r3),
      ], (t, n) {
        final back = -_dot(n, _cross(sh, hipLat).unit);
        return _tint(_pants, {Muscle.calves: _smooth(0.0, 0.5, back) * _smooth(0.05, 0.2, t) * (1 - _smooth(0.6, 0.85, t))});
      }, seg: 18);
      // Costura exterior del pantalón.
      final pts = <V3>[], ns = <V3>[], ac = <V3>[];
      for (final (a, b, uu, vv, ra, rb) in [(hip + th * 2, kn, u1, v1, r1, r2), (kn, an - sh * 2, u2, v2, r2, r3)]) {
        for (var i = 0; i <= 4; i++) {
          final t = i / 4;
          final r = ra + (rb - ra) * t;
          pts.add(a + (b - a) * t + uu * r);
          ns.add(uu);
          ac.add(vv);
        }
      }
      _ribbon(m, pts, ns, ac, 0.8, accent);
      // Zapatilla: del talón a la punta.
      final foot = (toe - an).unit;
      final down = (_cross(foot, outward)).unit;
      final dn = _dot(down, sh) < 0 ? down * -1 : down;
      final heel = an - foot * 3.5 * k + dn * 3 * k;
      final tip = toe + dn * 3 * k;
      final (fu, fv0) = _basis(foot, outward);
      final fv = _dot(fv0, dn) > 0 ? fv0 * -1 : fv0; // fv hacia arriba del pie
      final shoeRings = [
        _Ring(heel, fu, fv, 3.8 * k, 4.4 * k),
        _Ring(heel + (tip - heel) * 0.45, fu, fv, 4.6 * k, 4.0 * k),
        _Ring(tip - (tip - heel) * 0.12, fu, fv, 4.4 * k, 2.8 * k),
      ];
      _loft(m, shoeRings, (t, n) => _dot(n, fv) < -0.45 ? _sole : _shoe, seg: 16);
      final sp = <V3>[], sn = <V3>[], sa = <V3>[];
      for (var i = 0; i <= 6; i++) {
        final t = i / 6 * 0.9;
        final c = heel + (tip - heel) * t;
        sp.add(c + fu * (4.4 * k) - fv * 1.2 * k);
        sn.add(fu);
        sa.add(fv);
      }
      _ribbon(m, sp, sn, sa, 0.8, accent);
    }

    _addHeldProps(sk, m);
    _addFixedProps(sk, m);
    return m;
  }

  V3 _grip(Skeleton sk, String side) {
    final wr = sk['${side}Hand'];
    return wr + (wr - sk['${side}Elbow']).unit * 5.5;
  }

  void _addHeldProps(Skeleton sk, _Mesh m) {
    final lat = sk.lateral;
    final up = (sk['neck'] - sk['pelvis']).unit;
    final fwd = _cross(lat, up).unit;
    void dumbbell(V3 c, V3 dir) {
      _tube(m, c - dir * 7, c + dir * 7, 1.5, _steel, seg: 8);
      for (final s in [-1.0, 1.0]) {
        _tube(m, c + dir * (s * 6.5), c + dir * (s * 12), 5, _plate, seg: 10);
      }
    }

    for (final p in props) {
      switch (p) {
        case Prop.barbellBack:
        case Prop.barbellHands:
          final c = p == Prop.barbellBack
              ? sk['neck'] - fwd * 9 - up * 3
              : (_grip(sk, 'l') + _grip(sk, 'r')) * 0.5;
          _tube(m, c - lat * 80, c + lat * 80, 1.4, _steel, seg: 8);
          for (final s in [-1.0, 1.0]) {
            _tube(m, c + lat * (s * 58), c + lat * (s * 61), 3.2, _steel, seg: 8);
            _tube(m, c + lat * (s * 61), c + lat * (s * 67), 11, _plate, seg: 18);
          }
        case Prop.dumbbells:
          dumbbell(_grip(sk, 'l'), lat);
          dumbbell(_grip(sk, 'r'), lat);
        case Prop.dumbbellRight:
          dumbbell(_grip(sk, 'r'), lat);
        case Prop.goblet:
          dumbbell((_grip(sk, 'l') + _grip(sk, 'r')) * 0.5 - fwd * 1, up);
        case Prop.bar:
          final c = (_grip(sk, 'l') + _grip(sk, 'r')) * 0.5;
          _tube(m, c - lat * 60, c + lat * 60, 1.5, _steel, seg: 8);
        default:
          break;
      }
    }
  }

  void _addFixedProps(Skeleton sk, _Mesh m) {
    final bodyAxis = sk['neck'] - sk['pelvis'];
    final flat = V3(bodyAxis.x, 0, bodyAxis.z);
    final along = (flat.length < 1 ? const V3(0, 0, 1) : flat).unit;
    final across = V3(-along.z, 0, along.x);
    const up = V3(0, 1, 0);
    void bench(V3 c, double top, double halfLen, double halfW, V3 al, V3 ac) {
      // Colchoneta arriba y base metálica.
      _box(m, V3(c.x, top - 3, c.z), al * halfLen, up * 3, ac * halfW, _pad);
      _box(m, V3(c.x, (top - 6) / 2, c.z), al * (halfLen * 0.75), up * ((top - 6) / 2), ac * (halfW * 0.4), _frame, div: 2);
    }

    for (final p in props) {
      switch (p) {
        case Prop.bench:
          final c = (sk['pelvis'] + sk['neck']) * 0.5;
          final top = min(sk['pelvis'].y, sk['neck'].y) - 11;
          bench(c, top, 55, 14, along, across);
        case Prop.benchUnderHands:
          final l = sk['lHand'], r = sk['rHand'];
          final both = (l.y - r.y).abs() < 4;
          final c = both ? (l + r) * 0.5 : (l.y < r.y ? l : r);
          bench(c, c.y - 2, 14, both ? 45 : 20, const V3(0, 0, 1), const V3(1, 0, 0));
        case Prop.benchBack:
          final c = sk['neck'] + (sk['waist'] - sk['neck']) * 0.3;
          bench(c, c.y - 11, 14, 55, along, across);
        case Prop.box:
          final c = sk['pelvis'] - along * 0;
          final fwd = _cross(sk.lateral, (sk['neck'] - sk['pelvis']).unit).unit;
          final cc = c - fwd * 10;
          final h = max(20.0, sk['pelvis'].y - 10) / 2;
          _box(m, V3(cc.x, h, cc.z - 6), const V3(17, 0, 0), up * h, const V3(0, 0, 17), _pad);
        case Prop.footPlate:
          final c = (sk['lAnkle'] + sk['rAnkle']) * 0.5;
          final n = ((sk['lKnee'] + sk['rKnee']) * 0.5 - c).unit;
          final s = sk.lateral;
          final v = _cross(s, n).unit;
          _box(m, c - n * 5, s * 26, v * 24, n * 1.5, _frame, div: 2);
        default:
          break;
      }
    }
  }

  /// Cámara para [size]: proyección a pantalla y giro de direcciones.
  _Camera _camera(Size size, Skeleton sk) => _Camera(framing ?? Framing.of([sk]), yaw, size, elevation: elevation);

  /// Dibuja el maniquí en píxeles con prueba de profundidad (sin cortes
  /// entre piezas) a [ss] veces el tamaño, para suavizar los bordes al
  /// reducirlo. Devuelve RGBA con fondo transparente.
  MannequinPixels rasterize(Size size, {double ss = 2}) {
    final sk = solve(pose, female);
    final W = max(1, (size.width * ss).round()), H = max(1, (size.height * ss).round());
    final cam = _Camera(framing ?? Framing.of([sk]), yaw, Size(W.toDouble(), H.toDouble()), elevation: elevation);
    final m = _build(sk);
    final n = m.pos.length;
    final sx = Float32List(n), sy = Float32List(n), sz = Float32List(n);
    final cr = Float32List(n), cg = Float32List(n), cb = Float32List(n);
    final l = const V3(-0.45, 0.7, 0.55).unit;
    final fillL = const V3(0.6, 0.2, 0.5).unit;
    final half = (l + const V3(0, 0, 1)).unit;
    final viewNormals = List<V3>.filled(n, const V3(0, 0, 1));
    final viewPos = List<V3>.filled(n, const V3(0, 0, 0));
    for (var i = 0; i < n; i++) {
      final w = cam.view(m.pos[i]);
      viewPos[i] = w;
      final o = cam.project(w);
      sx[i] = o.dx;
      sy[i] = o.dy;
      sz[i] = w.z;
      final nn = cam.viewDir(m.nrm[i]);
      viewNormals[i] = nn;
      final diff = max(0.0, _dot(nn, l));
      final fill = max(0.0, _dot(nn, fillL)) * 0.25;
      // Luz de borde con el acento, solo en el contorno (no en caras planas).
      final rim = nn.z < 0.35 ? pow(1 - nn.z.abs().clamp(0.0, 1.0), 3).toDouble() * 0.35 * (1 - nn.y.abs()) : 0.0;
      final spec = pow(max(0.0, _dot(nn, half)), 24).toDouble() * 0.12;
      final base = m.col[i];
      final k = 0.42 + 0.6 * diff + fill;
      cr[i] = (base.r * k + accent.r * rim + spec).clamp(0.0, 1.0) * 255;
      cg[i] = (base.g * k + accent.g * rim + spec).clamp(0.0, 1.0) * 255;
      cb[i] = (base.b * k + accent.b * rim + spec).clamp(0.0, 1.0) * 255;
    }
    final px = Uint32List(W * H);
    final zb = Float32List(W * H)..fillRange(0, W * H, -1e9);
    for (var t = 0; t < m.idx.length; t += 3) {
      final a = m.idx[t], b = m.idx[t + 1], c = m.idx[t + 2];
      // Descarta las caras que miran hacia atrás.
      final na = viewNormals[a] + viewNormals[b] + viewNormals[c];
      final ce = (viewPos[a] + viewPos[b] + viewPos[c]) * (1 / 3);
      if (_dot(na, V3(-ce.x, -ce.y, _Camera.d - ce.z)) < 0) continue;
      _fill(px, zb, W, H, sx, sy, sz, cr, cg, cb, a, b, c);
    }
    return MannequinPixels(px.buffer.asUint8List(), W, H);
  }

  static void _fill(Uint32List px, Float32List zb, int W, int H, Float32List sx, Float32List sy, Float32List sz,
      Float32List cr, Float32List cg, Float32List cb, int a, int b, int c) {
    final x0 = sx[a], y0 = sy[a], x1 = sx[b], y1 = sy[b], x2 = sx[c], y2 = sy[c];
    final area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
    if (area.abs() < 1e-9) return;
    final inv = 1 / area;
    final minX = max(0, min(x0, min(x1, x2)).floor()), maxX = min(W - 1, max(x0, max(x1, x2)).ceil());
    final minY = max(0, min(y0, min(y1, y2)).floor()), maxY = min(H - 1, max(y0, max(y1, y2)).ceil());
    if (minX > maxX || minY > maxY) return;
    // Baricéntricas incrementales: w0 (vértice a) y w1 (vértice b).
    final dw0x = (y1 - y2) * inv, dw1x = (y2 - y0) * inv;
    final z0 = sz[a], z1 = sz[b], z2 = sz[c];
    final r0 = cr[a], r1 = cr[b], r2 = cr[c];
    final g0 = cg[a], g1 = cg[b], g2 = cg[c];
    final b0 = cb[a], b1 = cb[b], b2 = cb[c];
    for (var y = minY; y <= maxY; y++) {
      final py = y + 0.5, pxs = minX + 0.5;
      var w0 = ((x1 - pxs) * (y2 - py) - (x2 - pxs) * (y1 - py)) * inv;
      var w1 = ((x2 - pxs) * (y0 - py) - (x0 - pxs) * (y2 - py)) * inv;
      var row = y * W + minX;
      for (var x = minX; x <= maxX; x++, row++, w0 += dw0x, w1 += dw1x) {
        final w2 = 1 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        final z = w0 * z0 + w1 * z1 + w2 * z2;
        if (z <= zb[row]) continue;
        zb[row] = z;
        final r = (w0 * r0 + w1 * r1 + w2 * r2).toInt();
        final g = (w0 * g0 + w1 * g1 + w2 * g2).toInt();
        final bl = (w0 * b0 + w1 * b1 + w2 * b2).toInt();
        px[row] = 0xFF000000 | (bl << 16) | (g << 8) | r;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    try {
      _paint(canvas, size);
    } catch (_) {
      // Una pose imposible no debe romper la pantalla: no se dibuja.
    }
  }

  void _paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final sk = solve(pose, female);
    final cam = _camera(size, sk);
    final fr = cam.framing;
    // Piso: sombra y aro de acento.
    final floorC = cam.proj(V3(fr.cx, 0, fr.cz));
    canvas.drawOval(
      Rect.fromCenter(center: floorC, width: 120 * cam.scale, height: 22 * cam.scale),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final ring = Path();
    for (var i = 0; i <= 48; i++) {
      final a = 2 * pi * i / 48;
      final p = cam.proj(V3(fr.cx + cos(a) * 62, 0, fr.cz + sin(a) * 62));
      i == 0 ? ring.moveTo(p.dx, p.dy) : ring.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(ring, Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    _drawFlatProps(canvas, sk, cam.proj);
    final img = image;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    _drawLines(canvas, sk, cam.proj);
  }

  void _drawFlatProps(Canvas canvas, Skeleton sk, Offset Function(V3) proj) {
    for (final p in props) {
      switch (p) {
        case Prop.wall:
          final f = sk['lHand'].z > sk['pelvis'].z ? max(sk['lHand'].z, sk['rHand'].z) + 3 : 40.0;
          final quad = [V3(-60, 0, f), V3(60, 0, f), V3(60, 200, f), V3(-60, 200, f)];
          canvas.drawPath(Path()..addPolygon([for (final q in quad) proj(q)], true),
              Paint()..color = const Color(0x332E3442));
        case Prop.floorMat:
          final c = sk['pelvis'];
          final quad = [
            V3(c.x - 35, 0.2, c.z - 95), V3(c.x + 35, 0.2, c.z - 95),
            V3(c.x + 35, 0.2, c.z + 95), V3(c.x - 35, 0.2, c.z + 95),
          ];
          canvas.drawPath(Path()..addPolygon([for (final q in quad) proj(q)], true),
              Paint()..color = accent.withValues(alpha: 0.16));
        default:
          break;
      }
    }
  }

  void _drawLines(Canvas canvas, Skeleton sk, Offset Function(V3) proj) {
    final cable = Paint()
      ..color = accent.withValues(alpha: 0.9)
      ..strokeWidth = 1.6;
    final hands = (_grip(sk, 'l') + _grip(sk, 'r')) * 0.5;
    for (final p in props) {
      switch (p) {
        case Prop.cableForward:
          canvas.drawLine(proj(hands), proj(V3(hands.x, sk['pelvis'].y, 120)), cable);
        case Prop.cableHigh:
          canvas.drawLine(proj(hands), proj(V3(hands.x, 230, hands.z)), cable);
        case Prop.cableSide:
          canvas.drawLine(proj(hands), proj(V3(-110, hands.y, hands.z)), cable);
        case Prop.band:
          canvas.drawLine(proj(_grip(sk, 'l')), proj(_grip(sk, 'r')),
              Paint()
                ..color = accent
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round);
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(MannequinPainter old) => true;
}
