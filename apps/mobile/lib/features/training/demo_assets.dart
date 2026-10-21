/// Demostraciones renderizadas (maniquí 3D en Blender, tools/avatar):
/// una hoja de cuadros por ejercicio, figura y vista, incluidas en la app.
library;

import 'mannequin.dart';

/// Vistas fijas de cada demostración.
enum DemoView {
  front('f', 'Frente', 0),
  side('l', 'Lado', 90),
  back('b', 'Espalda', 180);

  const DemoView(this.code, this.label, this.yaw);

  final String code;
  final String label;
  final double yaw;

  /// La vista más parecida al ángulo de cámara preferido del ejercicio.
  static DemoView closestTo(double yaw) {
    final y = (yaw % 360 + 360) % 360;
    if (y >= 135 && y <= 225) return DemoView.back;
    return y >= 45 && y <= 315 ? DemoView.side : DemoView.front;
  }
}

/// Columnas de la hoja de cuadros y tamaño de cada cuadro (px).
const demoColumns = 4;
const demoFrameSize = 384;

/// Nombre de archivo a partir del nombre del ejercicio.
String demoSlug(String name) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final ch in name.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Cuadros renderizados: la ida completa (o la vuelta entera si es bucle).
int demoFrameCount(MoveAnim a) => a.loop ? 16 : 12;

/// Instante del ciclo que muestra el cuadro [k].
double demoFramePhase(MoveAnim a, int k) {
  final n = demoFrameCount(a);
  return a.loop ? k / n : a.phaseForProgress(k / (n - 1));
}

/// Cuadro (con fracción, para fundir con el siguiente) en el instante [phase].
double demoFrameAt(MoveAnim a, double phase) {
  final n = demoFrameCount(a);
  if (a.loop) return (phase % 1) * n;
  return a.progressAt(phase) * (n - 1);
}

String demoSheet(String name, {required bool female, required DemoView view}) =>
    'assets/demos/${demoSlug(name)}_${female ? 'f' : 'm'}_${view.code}.webp';

String demoThumb(String name, {required bool female}) =>
    'assets/demos/thumbs/${demoSlug(name)}_${female ? 'f' : 'm'}.webp';
