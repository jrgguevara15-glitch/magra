import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/format.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/features/profile/user_profile.dart';
import 'package:magra/features/progress/measurement.dart';

void main() {
  test('perfil: ida y vuelta con la fila de Supabase', () {
    final row = {
      'name': 'Junior',
      'sex': 'male',
      'birth_date': '1986-03-01',
      'height_cm': 180,
      'activity_factor': 1.2,
      'pace_kg_week': 0.5,
      'goal_fat_pct': 17,
      'protein_pct': 30,
      'carb_pct': 45,
      'lipid_pct': 25,
      'low_carb_days': [2, 4],
    };
    final p = UserProfile.fromRow(row);
    expect(p.sex, Sex.male);
    expect(p.birthDate, DateTime(1986, 3, 1));
    expect(p.split.isValid, isTrue);
    expect(p.toRow(), {
      ...row,
      'height_cm': 180.0,
      'goal_fat_pct': 17.0,
      'protein_pct': 30.0,
      'carb_pct': 45.0,
      'lipid_pct': 25.0,
    });
  });

  test('medición: fila con nulos y fechas', () {
    final m = Measurement.fromRow({
      'id': 'x',
      'measured_on': '2022-02-23',
      'weight_kg': 110.9,
      'neck_cm': 44,
      'waist_cm': 102,
      'hip_cm': null,
      'reported_fat_pct': 18.74,
      'source': 'Nutri · Dieta 04',
    });
    expect(m.date, DateTime(2022, 2, 23));
    expect(m.hipCm, isNull);
    expect(m.toRow()['measured_on'], '2022-02-23');
    expect(m.toRow().containsKey('id'), isFalse);
  });

  test('formato chileno de números y fechas', () {
    expect(fmt(1976.8), '1.977');
    expect(fmt(1976.8, 1), '1.976,8');
    expect(fmt(110.9, 1), '110,9');
    expect(fmt(-0.5, 2), '−0,50');
    expect(fmt(-0.001, 1), '0,0');
    expect(fmt(null), '—');
    expect(fmtDate(DateTime(2021, 8, 2)), '2-ago-2021');
    expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(parseNum('108,5'), 108.5);
    expect(parseNum(' '), isNull);
    expect(parseNum('abc'), isNull);
  });
}
