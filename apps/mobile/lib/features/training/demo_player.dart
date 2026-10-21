import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formulas/formulas.dart' show Sex;
import 'body_map.dart';
import 'demo_assets.dart';
import 'mannequin.dart';

/// Demostración renderizada del ejercicio [name]: el maniquí 3D hace el
/// movimiento en bucle con vistas fijas (frente, lado, espalda). Se pausa,
/// se reinicia y se recorre paso a paso. Si la imagen no está, usa el
/// maniquí simple dibujado en la app.
class DemoPlayer extends ConsumerStatefulWidget {
  const DemoPlayer({
    super.key,
    required this.name,
    required this.anim,
    required this.sex,
    required this.primary,
    this.secondary = const {},
    this.height = 300,
    this.controls = true,
    this.animate = true,
  });

  final String name;
  final MoveAnim anim;

  /// Figura por defecto (la del perfil); el visor permite cambiarla.
  final Sex sex;
  final Set<Muscle> primary;
  final Set<Muscle> secondary;
  final double height;
  final bool controls;

  /// `false`: muestra la pose final quieta.
  final bool animate;

  @override
  ConsumerState<DemoPlayer> createState() => _DemoPlayerState();
}

class _DemoPlayerState extends ConsumerState<DemoPlayer> with SingleTickerProviderStateMixin {
  late DemoView _view = DemoView.closestTo(widget.anim.yaw);
  double _phase = 0.5;
  bool _playing = true;
  bool _failed = false;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  ui.Image? _sheet;
  String? _sheetPath;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _canAnimate => widget.animate && ref.read(figureAnimationProvider) && !_reduceMotion;

  bool get _female => (ref.read(avatarChoiceProvider) ?? widget.sex) == Sex.female;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
    _load();
  }

  @override
  void didUpdateWidget(DemoPlayer old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _view = DemoView.closestTo(widget.anim.yaw);
      _phase = _canAnimate ? 0 : 0.5;
      _failed = false;
      _load();
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

  /// Carga la hoja de cuadros de la figura y vista actuales.
  void _load() {
    final path = demoSheet(widget.name, female: _female, view: _view);
    if (path == _sheetPath) return;
    _sheetPath = path;
    _detach();
    final stream = AssetImage(path).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted || _sheetPath != path) return;
        setState(() {
          _sheet = info.image;
        });
      },
      onError: (e, st) {
        if (mounted && _sheetPath == path) setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detach() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _ticker?.dispose();
    super.dispose();
  }

  void _setView(DemoView v) {
    setState(() => _view = v);
    _load();
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen(avatarChoiceProvider, (prev, next) => _load());
    final female = _female;
    if (_failed) {
      return MannequinView(
        anim: widget.anim,
        sex: female ? Sex.female : Sex.male,
        primary: widget.primary,
        secondary: widget.secondary,
        height: widget.height,
        controls: widget.controls,
        animate: widget.animate,
      );
    }
    final frame = demoFrameAt(widget.anim, _phase);
    final figure = Semantics(
      label: 'Demostración con maniquí ${female ? 'de mujer' : 'de hombre'}, vista ${_view.label.toLowerCase()}.',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _sheet == null
            ? Center(
                child: Text('Cargando demostración…', style: Theme.of(context).textTheme.bodySmall),
              )
            : CustomPaint(
                painter: _SheetPainter(
                  sheet: _sheet!,
                  frame: frame,
                  count: demoFrameCount(widget.anim),
                  loop: widget.anim.loop,
                ),
              ),
      ),
    );
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
            for (final v in DemoView.values)
              ChoiceChip(
                showCheckmark: false,
                label: Text(v.label),
                selected: _view == v,
                onSelected: (_) => _setView(v),
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
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            LegendDot(color: primaryColor, label: 'Trabaja más'),
            LegendDot(color: secondaryColor, label: 'Ayuda'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _reduceMotion
              ? 'Reducir movimiento está activado: usa la barra para ver el ejercicio paso a paso.'
              : 'Elige la vista: frente, lado o espalda.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Dibuja el cuadro [frame] de la hoja, fundido con el siguiente.
class _SheetPainter extends CustomPainter {
  _SheetPainter({required this.sheet, required this.frame, required this.count, required this.loop});

  final ui.Image sheet;
  final double frame;
  final int count;
  final bool loop;

  Rect _src(int k) {
    final w = sheet.width / demoColumns;
    return Rect.fromLTWH((k % demoColumns) * w, (k ~/ demoColumns) * w, w, w);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    final k = frame.floor();
    final t = frame - k;
    final a = loop ? k % count : k.clamp(0, count - 1);
    final b = loop ? (k + 1) % count : (k + 1).clamp(0, count - 1);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(sheet, _src(a), dst, paint);
    if (t > 0.01 && a != b) {
      canvas.drawImageRect(sheet, _src(b), dst, paint..color = Color.fromRGBO(0, 0, 0, t));
    }
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.sheet != sheet || old.frame != frame;
}
