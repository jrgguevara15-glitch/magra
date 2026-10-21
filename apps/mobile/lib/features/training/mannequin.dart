import 'dart:math';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formulas/formulas.dart' show Sex;
import 'body_map.dart';
import 'mannequin_render.dart';

export 'mannequin_render.dart' show MannequinPainter, MannequinPixels, avatarAccentFemale, avatarAccentMale;

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

/// Qué tipo de demostración es (define las fases que se muestran).
enum DemoKind {
  /// Repeticiones de fuerza: inicio, excéntrica, transición, concéntrica.
  strength,

  /// Isométrico (p. ej. plancha): se mantiene la posición.
  hold,

  /// Estiramiento: entrar suave, mantener y salir.
  stretch,

  /// Movilidad continua (círculos, trote, rotaciones).
  mobility,
}

/// Animación de un ejercicio: poses clave que se recorren ida y vuelta,
/// con pausas cortas en la posición inicial y en la transición.
class MoveAnim {
  const MoveAnim(
    this.keys, {
    this.props = const [],
    this.yaw = 35,
    this.seconds = 3.2,
    this.loop = false,
    this.kind = DemoKind.strength,
    this.eccentricFirst = true,
    this.elevation = 13,
  });

  final List<Pose> keys;
  final List<Prop> props;

  /// Ángulo de cámara inicial (0 = de frente, 90 = de lado).
  final double yaw;

  /// Grados que la cámara mira hacia abajo.
  final double elevation;
  final double seconds;

  /// Recorre las poses en círculo (en vez de ida y vuelta).
  final bool loop;
  final DemoKind kind;

  /// Si el primer tramo (de la primera a la última pose) es la fase
  /// excéntrica (bajar o alargar el músculo bajo carga).
  final bool eccentricFirst;

  DemoKind get effectiveKind => loop ? DemoKind.mobility : kind;

  /// Fracción del ciclo quieta al inicio y en la transición.
  (double, double) get _holds => switch (effectiveKind) {
        DemoKind.strength => (0.1, 0.1),
        DemoKind.stretch => (0.06, 0.44),
        _ => (0.0, 0.0),
      };

  /// Avance 0–1 entre la primera y la última pose en el instante [phase].
  double _progress(double phase) {
    final (hs, he) = _holds;
    final move = (1 - hs - he) / 2;
    if (phase < hs) return 0;
    if (phase < hs + move) return (phase - hs) / move;
    if (phase < hs + move + he) return 1;
    return 1 - (phase - hs - move - he) / move;
  }

  /// Avance 0–1 de la primera a la última pose en [phase] (sin bucle).
  double progressAt(double phase) => _progress(phase);

  /// El instante del primer tramo (ida) en que el avance vale [p].
  double phaseForProgress(double p) {
    final (hs, he) = _holds;
    final move = (1 - hs - he) / 2;
    return hs + p.clamp(0.0, 1.0) * move;
  }

  /// La pose en el instante [phase] (0–1) del ciclo.
  Pose at(double phase) {
    if (keys.length == 1) return keys.first;
    final n = keys.length;
    final double pos = loop ? phase * n : _progress(phase) * (n - 1);
    final i = pos.floor() % n;
    final j = loop ? (i + 1) % n : min(i + 1, n - 1);
    final t = pos - pos.floor();
    final eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
    return Pose.lerp(keys[i], keys[j], eased.toDouble());
  }

  /// Nombre de la fase en el instante [phase], para mostrar bajo la figura.
  String phaseLabel(double phase) {
    switch (effectiveKind) {
      case DemoKind.mobility:
        return 'Movimiento continuo y controlado';
      case DemoKind.hold:
        return 'Mantén la posición y respira';
      case DemoKind.stretch:
      case DemoKind.strength:
        final (hs, he) = _holds;
        final move = (1 - hs - he) / 2;
        final stretch = effectiveKind == DemoKind.stretch;
        if (phase < hs) return stretch ? 'Posición inicial' : 'Inicio';
        if (phase < hs + move) {
          if (stretch) return 'Entra suave en el estiramiento';
          return eccentricFirst ? 'Fase excéntrica · controla el movimiento' : 'Fase concéntrica · aplica fuerza';
        }
        if (phase < hs + move + he) return stretch ? 'Mantén y respira' : 'Transición';
        if (stretch) return 'Vuelve suave';
        return eccentricFirst ? 'Fase concéntrica · aplica fuerza' : 'Fase excéntrica · controla el movimiento';
    }
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

/// Figura elegida a mano en el visor; `null` = la del perfil.
class AvatarChoice extends Notifier<Sex?> {
  @override
  Sex? build() => null;

  void choose(Sex sex) => state = sex;
}

final avatarChoiceProvider = NotifierProvider<AvatarChoice, Sex?>(AvatarChoice.new);

/// Maniquí 3D vestido y sin rostro que hace el ejercicio en bucle: se pausa,
/// se reinicia, se recorre paso a paso y gira 360° con el dedo.
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

  /// Figura por defecto (la del perfil); el visor permite cambiarla.
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
  double _phase = 0.5;
  bool _playing = true;
  bool _muscles = true;
  bool _failed = false;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  final Map<bool, Framing> _framings = {};

  ui.Image? _image;
  Object? _imageKey;
  int _inFlight = 0;
  int _frameId = 0;
  int _shownId = 0;
  Object? _pendingKey;
  bool _renderQueued = false;
  Size _size = Size.zero;

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _canAnimate => widget.animate && ref.read(figureAnimationProvider) && !_reduceMotion;

  bool get _female => (ref.read(avatarChoiceProvider) ?? widget.sex) == Sex.female;

  Framing _framing(bool female) => _framings.putIfAbsent(female, () => Framing.ofAnim(widget.anim, female));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(MannequinView old) {
    super.didUpdateWidget(old);
    if (old.anim != widget.anim) {
      _framings.clear();
      _yaw = widget.anim.yaw;
      _phase = _canAnimate ? 0 : 0.5;
      _failed = false;
    }
  }

  void _syncTicker() {
    final run = _canAnimate && _playing;
    final ticker = _ticker ??= createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      setState(() => _phase = (_phase + dt / widget.anim.seconds) % 1);
    });
    if (run && !ticker.isActive) {
      _last = Duration.zero;
      ticker.start();
    } else if (!run && ticker.isActive) {
      ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _image?.dispose();
    super.dispose();
  }

  void _setYaw(double y) => setState(() => _yaw = y);

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _syncTicker();
  }

  void _restart() {
    setState(() {
      _phase = 0;
      _playing = true;
    });
    _syncTicker();
  }

  void _scrub(double v) {
    setState(() {
      _phase = v;
      _playing = false;
    });
    _syncTicker();
  }

  MannequinPainter _painter({ui.Image? image}) {
    final female = _female;
    return MannequinPainter(
      pose: widget.anim.at(_phase),
      female: female,
      yaw: _yaw,
      primary: widget.primary,
      secondary: widget.secondary,
      props: widget.anim.props,
      framing: _framing(female),
      showMuscles: _muscles,
      image: image,
      elevation: widget.anim.elevation,
    );
  }

  Object get _key => (_phase, _yaw, _female, _muscles, _size, _supersample, widget.anim);

  /// Dibuja el cuadro actual fuera del build. Hasta dos cuadros en
  /// camino: mientras uno se convierte en imagen, ya se dibuja el siguiente.
  void _scheduleRender() {
    final key = _key;
    if (_renderQueued || _inFlight >= 2 || _failed || _size.isEmpty || _imageKey == key || _pendingKey == key) {
      return;
    }
    _renderQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _renderQueued = false;
      if (!mounted) return;
      _render();
    });
  }

  /// Resolución del dibujo: la del dispositivo (hasta 2,5×) si está quieto;
  /// en la web, algo menor mientras se anima para mantener la fluidez.
  double get _supersample {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2;
    final moving = _ticker?.isActive ?? false;
    if (_size.width < 120) return 2;
    if (kIsWeb && moving) return (dpr * 0.75).clamp(1.0, 1.6);
    return dpr.clamp(1.5, moving ? 2.0 : 2.5);
  }

  void _render() {
    final key = _key;
    MannequinPixels pixels;
    try {
      pixels = _painter().rasterize(_size, ss: _supersample);
    } catch (_) {
      setState(() => _failed = true);
      return;
    }
    final id = ++_frameId;
    _inFlight++;
    _pendingKey = key;
    pixels.toImage().then((img) {
      _inFlight--;
      if (!mounted || id < _shownId) {
        img.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = img;
        _imageKey = key;
        _shownId = id;
      });
    }, onError: (_) {
      _inFlight--;
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(avatarChoiceProvider);
    final female = _female;
    if (_failed) {
      // Alternativa estática si el dibujo 3D no se puede generar.
      return BodyMap(
        sex: female ? Sex.female : Sex.male,
        primary: widget.primary,
        secondary: widget.secondary,
        height: widget.height,
      );
    }
    final figure = LayoutBuilder(builder: (context, c) {
      _size = Size(c.maxWidth.isFinite ? c.maxWidth : widget.height, widget.height);
      _scheduleRender();
      return GestureDetector(
        onHorizontalDragUpdate: (d) => _setYaw(_yaw - d.delta.dx * 0.9),
        child: Semantics(
          label: 'Maniquí ${female ? 'de mujer' : 'de hombre'} haciendo el ejercicio. '
              'Desliza para girarlo.',
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(painter: _painter(image: _image)),
          ),
        ),
      );
    });
    if (!widget.controls) return figure;
    final animated = _canAnimate;
    final accent = female ? avatarAccentFemale : avatarAccentMale;
    return Column(
      children: [
        figure,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.anim.phaseLabel(_phase),
                    key: const ValueKey('fase'), style: theme.textTheme.labelLarge),
              ),
            ],
          ),
        ),
        Slider(
          value: _phase.clamp(0.0, 1.0),
          onChanged: _scrub,
          activeColor: accent,
          semanticFormatterCallback: (v) => 'Paso del movimiento ${(v * 100).round()} %',
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            if (animated || !_playing)
              IconButton(
                tooltip: _playing && animated ? 'Pausar' : 'Reproducir',
                onPressed: _reduceMotion || !widget.animate || !ref.read(figureAnimationProvider) ? null : _togglePlay,
                icon: Icon(_playing && animated ? Icons.pause_circle_outline : Icons.play_circle_outline),
              ),
            IconButton(
              tooltip: 'Reiniciar',
              onPressed: _restart,
              icon: const Icon(Icons.replay),
            ),
            for (final (label, y) in [('Frente', 0.0), ('Lado', 90.0), ('Espalda', 180.0)])
              ChoiceChip(
                showCheckmark: false,
                label: Text(label),
                selected: ((_yaw % 360 + 360) % 360 - y).abs() < 1,
                onSelected: (_) => _setYaw(y),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (label, sex) in [('Figura mujer', Sex.female), ('Figura hombre', Sex.male)])
              ChoiceChip(
                showCheckmark: false,
                label: Text(label),
                selected: (sex == Sex.female) == female,
                onSelected: (_) => ref.read(avatarChoiceProvider.notifier).choose(sex),
              ),
            FilterChip(
              label: const Text('Músculos'),
              selected: _muscles,
              onSelected: (v) => setState(() => _muscles = v),
            ),
          ],
        ),
        if (_muscles) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              LegendDot(color: primaryColor, label: 'Trabaja más'),
              LegendDot(color: secondaryColor, label: 'Ayuda'),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          _reduceMotion
              ? 'Reducir movimiento está activado: usa la barra para ver el ejercicio paso a paso.'
              : 'Desliza el maniquí para girarlo en 360°.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Punto de color con su etiqueta (leyenda de músculos).
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

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
