import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/formulas/formulas.dart' show Sex;

/// Zonas musculares que se pueden destacar en la figura.
enum Muscle {
  shoulders(true),
  chest(true),
  biceps(true),
  forearms(true),
  abs(true),
  obliques(true),
  quads(true),
  adductors(true),
  traps(false),
  lats(false),
  midBack(false),
  triceps(false),
  lowerBack(false),
  glutes(false),
  hamstrings(false),
  calves(false);

  const Muscle(this.front);

  /// Se ve de frente (si no, de espalda).
  final bool front;
}

/// Músculos de una ficha (nombres en español) → zonas de la figura.
Set<Muscle> musclesFromNames(Iterable<String> names) {
  final out = <Muscle>{};
  for (final raw in names) {
    final n = raw.toLowerCase();
    if (n.contains('pector')) out.add(Muscle.chest);
    if (n.contains('hombro') || n.contains('deltoid')) out.add(Muscle.shoulders);
    if (n.contains('bíceps')) out.add(Muscle.biceps);
    if (n.contains('tríceps')) out.add(Muscle.triceps);
    if (n.contains('antebrazo')) out.add(Muscle.forearms);
    if (n.contains('oblicuo')) {
      out.add(Muscle.obliques);
    } else if (n.contains('core') || n.contains('abdomen')) {
      out.addAll({Muscle.abs, Muscle.obliques});
    }
    if (n.contains('cuádriceps')) out.add(Muscle.quads);
    if (n.contains('aductor')) out.add(Muscle.adductors);
    if (n.contains('glúteo')) out.add(Muscle.glutes);
    if (n.contains('isquio')) out.add(Muscle.hamstrings);
    if (n.contains('pantorrilla') || n.contains('gemelo')) out.add(Muscle.calves);
    if (n.contains('dorsal')) out.add(Muscle.lats);
    if (n.contains('romboide') || n.contains('espalda alta')) out.add(Muscle.midBack);
    if (n.contains('trapecio')) out.add(Muscle.traps);
    if (n.contains('espalda baja') || n.contains('lumbar')) out.add(Muscle.lowerBack);
  }
  return out;
}

/// Principales (los primeros de la lista) y secundarios (el resto).
({Set<Muscle> primary, Set<Muscle> secondary}) splitMuscles(List<String> names) {
  final cut = names.length >= 3 ? 2 : 1;
  final primary = musclesFromNames(names.take(cut));
  final secondary = musclesFromNames(names.skip(cut))..removeAll(primary);
  return (primary: primary, secondary: secondary);
}

const primaryColor = Color(0xFFFF3B5C);
const secondaryColor = Color(0xFFFF9F43);

/// Figura anatómica sin rostro (hombre o mujer) que gira con el dedo o
/// con los botones, con los músculos trabajados en rojo y los
/// secundarios en naranja.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.sex,
    required this.primary,
    this.secondary = const {},
    this.height = 300,
  });

  final Sex sex;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;
  final double height;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late double _angle = _startAngle;
  Animation<double>? _tween;

  /// Empieza mirando hacia donde está la mayor parte de lo trabajado.
  double get _startAngle {
    final all = {...widget.primary, ...widget.secondary};
    final front = widget.primary.where((m) => m.front).length * 2 +
        all.where((m) => m.front).length;
    final back = widget.primary.where((m) => !m.front).length * 2 +
        all.where((m) => !m.front).length;
    return back > front ? pi : 0;
  }

  bool get _showingFront => cos(_angle) >= 0;

  @override
  void initState() {
    super.initState();
    _turn.addListener(() {
      final t = _tween;
      if (t != null) setState(() => _angle = t.value);
    });
  }

  @override
  void didUpdateWidget(BodyMap old) {
    super.didUpdateWidget(old);
    // Otro ejercicio: vuelve a mirar hacia lo que trabaja.
    if (old.primary != widget.primary || old.secondary != widget.secondary) {
      _turn.stop();
      _angle = _startAngle;
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _rotateTo(double target) {
    _tween = Tween(begin: _angle, end: target)
        .animate(CurvedAnimation(parent: _turn, curve: Curves.easeInOutCubic));
    _turn.forward(from: 0);
  }

  void _flip() => _rotateTo(_showingFront ? _nearest(pi) : _nearest(0));

  /// El ángulo equivalente a [base] más cercano al actual (sigue girando
  /// en el mismo sentido).
  double _nearest(double base) {
    final k = ((_angle - base) / (2 * pi)).round();
    return base + k * 2 * pi;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final squash = cos(_angle).abs().clamp(0.08, 1.0).toDouble();
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragUpdate: (d) {
            _turn.stop();
            setState(() => _angle += d.delta.dx / 90);
          },
          onHorizontalDragEnd: (_) =>
              _rotateTo(_showingFront ? _nearest(0) : _nearest(pi)),
          onTap: _flip,
          child: Semantics(
            label: 'Figura ${widget.sex == Sex.female ? 'de mujer' : 'de hombre'}, '
                'vista de ${_showingFront ? 'frente' : 'espalda'}. Desliza para girarla.',
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(squash, 1, 1),
                child: CustomPaint(
                  painter: _BodyPainter(
                    female: widget.sex == Sex.female,
                    front: _showingFront,
                    primary: widget.primary,
                    secondary: widget.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Frente')),
                ButtonSegment(value: false, label: Text('Espalda')),
              ],
              selected: {_showingFront},
              onSelectionChanged: (s) => _rotateTo(s.first ? _nearest(0) : _nearest(pi)),
            ),
            IconButton(
              tooltip: 'Girar',
              onPressed: _flip,
              icon: const Icon(Icons.threesixty),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          children: [
            _Legend(color: primaryColor, label: 'Trabaja más'),
            _Legend(color: secondaryColor, label: 'Ayuda'),
          ],
        ),
        Text('Desliza o toca la figura para girarla.',
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Miniatura sin controles: la vista donde más se trabaja.
class BodyThumb extends StatelessWidget {
  const BodyThumb({super.key, required this.sex, required this.primary, this.secondary = const {}});

  final Sex sex;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;

  @override
  Widget build(BuildContext context) {
    final back = primary.where((m) => !m.front).length > primary.where((m) => m.front).length;
    return CustomPaint(
      painter: _BodyPainter(
        female: sex == Sex.female,
        front: !back,
        primary: primary,
        secondary: secondary,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

/// Dibuja la figura en una caja de 200 × 420 escalada al espacio.
class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.female,
    required this.front,
    required this.primary,
    required this.secondary,
  });

  final bool female;
  final bool front;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;

  // Medidas del cuerpo (mitad izquierda; la derecha es simétrica).
  double get _shoulder => female ? 60 : 52;
  double get _waist => female ? 76 : 70;
  double get _hip => female ? 62 : 70;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / 200, size.height / 420);
    canvas.translate((size.width - 200 * s) / 2, (size.height - 420 * s) / 2);
    canvas.scale(s);

    final skin = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2B3550), Color(0xFF1C2338)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(0, 0, 200, 420));
    final outline = Paint()
      ..color = const Color(0xFF3E4A6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final body = _bodyPath();
    canvas.drawPath(body, skin);
    canvas.drawPath(body, outline);

    for (final m in Muscle.values.where((m) => m.front == front)) {
      final path = _musclePath(m);
      final Color fill;
      if (primary.contains(m)) {
        fill = primaryColor;
        canvas.drawPath(path, Paint()
          ..color = primaryColor.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      } else if (secondary.contains(m)) {
        fill = secondaryColor;
      } else {
        fill = const Color(0xFF34405F);
      }
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8);
    }

    // Detalles sin rostro: línea de columna o de abdomen.
    final line = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 1;
    if (front) {
      canvas.drawLine(const Offset(100, 124), const Offset(100, 192), line);
    } else {
      canvas.drawLine(const Offset(100, 70), const Offset(100, 200), line);
    }
  }

  Path _bodyPath() {
    final p = Path();
    // Cabeza sin rostro y cuello.
    p.addOval(Rect.fromCenter(center: const Offset(100, 32), width: 36, height: 44));
    p.addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTRB(91, 50, 109, 70), const Radius.circular(6)));
    // Torso.
    final sh = _shoulder, wa = _waist, hi = _hip;
    p.moveTo(sh, 76);
    p.quadraticBezierTo(100, 64, 200 - sh, 76);
    p.quadraticBezierTo(200 - sh + 6, 110, 200 - wa, 165);
    p.quadraticBezierTo(200 - hi + 2, 190, 200 - hi, 212);
    p.lineTo(hi, 212);
    p.quadraticBezierTo(hi - 2, 190, wa, 165);
    p.quadraticBezierTo(sh - 6, 110, sh, 76);
    p.close();
    if (female && front) {
      p.addOval(Rect.fromCenter(center: const Offset(84, 112), width: 30, height: 24));
      p.addOval(Rect.fromCenter(center: const Offset(116, 112), width: 30, height: 24));
    }
    // Brazos y piernas (izquierda y espejo).
    for (final mirror in [false, true]) {
      double x(double v) => mirror ? 200 - v : v;
      final arm = Path()
        ..moveTo(x(sh - 2), 80)
        ..quadraticBezierTo(x(sh - 16), 90, x(sh - 14), 150)
        ..lineTo(x(sh - 12), 218)
        ..lineTo(x(sh - 2), 218)
        ..lineTo(x(sh + 2), 150)
        ..quadraticBezierTo(x(sh + 4), 110, x(sh + 8), 92)
        ..close();
      p.addPath(arm, Offset.zero);
      p.addOval(Rect.fromCenter(center: Offset(x(sh - 7), 228), width: 13, height: 20));
      final leg = Path()
        ..moveTo(x(hi), 205)
        ..lineTo(x(99), 222)
        ..lineTo(x(96), 300)
        ..lineTo(x(93), 388)
        ..lineTo(x(80), 388)
        ..lineTo(x(hi + 6), 300)
        ..quadraticBezierTo(x(hi - 4), 250, x(hi), 205)
        ..close();
      p.addPath(leg, Offset.zero);
      p.addOval(Rect.fromCenter(center: Offset(x(86), 394), width: 22, height: 10));
    }
    return p;
  }

  Path _both(Rect left) => Path()
    ..addOval(left)
    ..addOval(Rect.fromLTRB(200 - left.right, left.top, 200 - left.left, left.bottom));

  Path _musclePath(Muscle m) {
    final sh = _shoulder, hi = _hip;
    return switch (m) {
      Muscle.shoulders => _both(Rect.fromCenter(center: Offset(sh + 2, 88), width: 20, height: 24)),
      Muscle.chest => Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(sh + 12, 90, 98, 120), const Radius.circular(10)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(102, 90, 200 - sh - 12, 120), const Radius.circular(10))),
      Muscle.biceps => _both(Rect.fromCenter(center: Offset(sh - 6, 120), width: 12, height: 36)),
      Muscle.triceps => _both(Rect.fromCenter(center: Offset(sh - 6, 120), width: 12, height: 38)),
      Muscle.forearms => _both(Rect.fromCenter(center: Offset(sh - 7, 182), width: 10, height: 44)),
      Muscle.abs => Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(87, 124, 113, 194), const Radius.circular(8))),
      Muscle.obliques => _both(const Rect.fromLTRB(74, 132, 86, 190)),
      Muscle.quads => _both(Rect.fromLTRB(hi + 4, 222, 97, 296)),
      Muscle.adductors => _both(const Rect.fromLTRB(93, 222, 99, 262)),
      Muscle.traps => Path()
        ..moveTo(82, 66)
        ..lineTo(118, 66)
        ..lineTo(132, 80)
        ..lineTo(100, 116)
        ..lineTo(68, 80)
        ..close(),
      Muscle.lats => _both(Rect.fromLTRB(sh + 10, 104, 94, 168)),
      Muscle.midBack => Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(88, 84, 112, 124), const Radius.circular(6))),
      Muscle.lowerBack => Path()
        ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(86, 166, 114, 200), const Radius.circular(8))),
      Muscle.glutes => _both(Rect.fromLTRB(hi + 2, 196, 99, 236)),
      Muscle.hamstrings => _both(Rect.fromLTRB(hi + 6, 240, 96, 300)),
      Muscle.calves => _both(const Rect.fromLTRB(78, 312, 94, 368)),
    };
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.front != front ||
      old.female != female ||
      old.primary != primary ||
      old.secondary != secondary;
}
