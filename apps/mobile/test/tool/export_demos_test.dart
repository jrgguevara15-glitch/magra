// Exporta las animaciones del maniquí para el generador de Blender
// (tools/avatar). Solo corre si se pide:
//   flutter test test/tool/export_demos_test.dart --dart-define=DEMO_EXPORT=../../tools/avatar/anims.json
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/exercise_guides.dart';
import 'package:magra/core/recommendation/warmup.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/body_map.dart';
import 'package:magra/features/training/demo_assets.dart';
import 'package:magra/features/training/mannequin.dart';
import 'package:magra/features/training/mannequin_poses.dart';

const out = String.fromEnvironment('DEMO_EXPORT');

/// Músculos de cada ejercicio y de cada paso de calentamiento/estiramiento.
Map<String, List<String>> musclesByName() {
  final m = <String, List<String>>{
    for (final l in exerciseGuides.values)
      for (final g in l) g.name: g.muscles,
  };
  for (final eq in Equipment.values) {
    for (final injuries in [const <Injury>[], Injury.values]) {
      final q = Questionnaire.initial.copyWith(equipment: eq, injuries: injuries);
      for (final f in SessionFocus.values) {
        for (final low in [false, true]) {
          for (final d in [
            ...warmUp(focus: f, questionnaire: q, lowImpact: low),
            ...coolDown(focus: f, questionnaire: q),
          ]) {
            if (d.muscles.isNotEmpty) m.putIfAbsent(d.name, () => d.muscles);
          }
        }
      }
    }
  }
  return m;
}

Map<String, Object?> seg(Seg s) => {'flex': s.flex, 'abd': s.abd};

Map<String, Object?> pose(Pose p) => {
      'pitch': p.pitch,
      'trunk': p.trunk,
      'twist': p.twist,
      'side': p.side,
      'rootY': p.rootY,
      'armsWithTrunk': p.armsWithTrunk,
      'lUpperArm': seg(p.lUpperArm),
      'rUpperArm': seg(p.rUpperArm),
      'lForearm': seg(p.lForearm),
      'rForearm': seg(p.rForearm),
      'lThigh': seg(p.lThigh),
      'rThigh': seg(p.rThigh),
      'lShin': seg(p.lShin),
      'rShin': seg(p.rShin),
    };

void main() {
  test('exportar animaciones', () {
    if (out.isEmpty) {
      markTestSkipped('Sin DEMO_EXPORT');
      return;
    }
    final muscles = musclesByName();
    final anims = <String, Object?>{};
    for (final name in animatedNames) {
      final a = animFor(name)!;
      final split = splitMuscles(muscles[name] ?? const []);
      final n = demoFrameCount(a);
      anims[name] = {
        'slug': demoSlug(name),
        'kind': a.effectiveKind.name,
        'loop': a.loop,
        'yaw': a.yaw,
        'elevation': a.elevation,
        'props': [for (final p in a.props) p.name],
        'primary': [for (final m in split.primary) m.name],
        'secondary': [for (final m in split.secondary) m.name],
        'frames': [for (var k = 0; k < n; k++) pose(a.at(demoFramePhase(a, k)))],
      };
    }
    File(out).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(anims));
  });
}
