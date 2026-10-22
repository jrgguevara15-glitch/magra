import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart' show isoDate;

/// Error del servidor o de la red al evaluar, con mensaje para el usuario.
class BodyException implements Exception {
  const BodyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lo que devuelve la IA al mirar las fotos.
class BodyAiResult {
  const BodyAiResult({
    required this.valid,
    this.invalidReason = '',
    this.fatPct = 0,
    this.fatLow = 0,
    this.fatHigh = 0,
    this.confidence = 'media',
    this.distribution = '',
    this.muscleTone = '',
    this.posture = '',
    this.strengths = const [],
    this.priorities = const [],
    this.nutrition = const [],
    this.training = const [],
    this.photoTips = '',
  });

  final bool valid;
  final String invalidReason;
  final double fatPct;
  final double fatLow;
  final double fatHigh;
  final String confidence;
  final String distribution;
  final String muscleTone;
  final String posture;
  final List<String> strengths;
  final List<String> priorities;
  final List<String> nutrition;
  final List<String> training;
  final String photoTips;

  factory BodyAiResult.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num? ?? 0).toDouble();
    List<String> l(String k) => [for (final s in (j[k] as List? ?? const [])) if (s is String) s];
    String s(String k) => j[k] is String ? j[k] as String : '';
    return BodyAiResult(
      valid: j['valid'] == true,
      invalidReason: s('invalid_reason'),
      fatPct: d('fat_pct'),
      fatLow: d('fat_low'),
      fatHigh: d('fat_high'),
      confidence: s('confidence').isEmpty ? 'media' : s('confidence'),
      distribution: s('fat_distribution'),
      muscleTone: s('muscle_tone'),
      posture: s('posture'),
      strengths: l('strengths'),
      priorities: l('priorities'),
      nutrition: l('nutrition'),
      training: l('training'),
      photoTips: s('photo_tips'),
    );
  }

  Map<String, dynamic> get details => {
        'fat_distribution': distribution,
        'muscle_tone': muscleTone,
        'posture': posture,
        'strengths': strengths,
        'priorities': priorities,
        'nutrition': nutrition,
        'training': training,
        'photo_tips': photoTips,
      };
}

/// Error típico (desviación) de cada método casero, en puntos de % grasa.
const double tapeErrorPct = 3.5;
const double minPhotoErrorPct = 2.5;

/// % de grasa final: promedio de la foto y las medidas ponderado por la
/// precisión de cada una (el rango de la foto dice cuán segura está).
double combinedFat({required double photo, required double low, required double high, double? tape}) {
  if (tape == null) return photo;
  final sPhoto = max(minPhotoErrorPct, (high - low) / 2);
  final wPhoto = 1 / (sPhoto * sPhoto);
  const wTape = 1 / (tapeErrorPct * tapeErrorPct);
  return (photo * wPhoto + tape * wTape) / (wPhoto + wTape);
}

/// Una evaluación guardada (solo el resultado; las fotos no se guardan).
class BodyAssessment {
  const BodyAssessment({
    this.id,
    required this.date,
    required this.weightKg,
    required this.finalFatPct,
    this.photoFatPct,
    this.photoFatLow,
    this.photoFatHigh,
    this.tapeFatPct,
    this.confidence = 'media',
    this.details = const {},
  });

  final String? id;
  final DateTime date;
  final double weightKg;
  final double finalFatPct;
  final double? photoFatPct;
  final double? photoFatLow;
  final double? photoFatHigh;
  final double? tapeFatPct;
  final String confidence;
  final Map<String, dynamic> details;

  BodyAiResult get result => BodyAiResult.fromJson({
        ...details,
        'valid': true,
        'fat_pct': photoFatPct ?? finalFatPct,
        'fat_low': photoFatLow ?? 0,
        'fat_high': photoFatHigh ?? 0,
        'confidence': confidence,
      });

  factory BodyAssessment.fromAi({
    required DateTime date,
    required double weightKg,
    required BodyAiResult ai,
    double? tapeFatPct,
  }) {
    double r1(double v) => (v * 10).round() / 10;
    return BodyAssessment(
      date: date,
      weightKg: r1(weightKg),
      finalFatPct: r1(combinedFat(photo: ai.fatPct, low: ai.fatLow, high: ai.fatHigh, tape: tapeFatPct)),
      photoFatPct: ai.fatPct,
      photoFatLow: ai.fatLow,
      photoFatHigh: ai.fatHigh,
      tapeFatPct: tapeFatPct == null ? null : r1(tapeFatPct),
      confidence: ai.confidence,
      details: ai.details,
    );
  }

  factory BodyAssessment.fromRow(Map<String, dynamic> row) {
    double? d(String k) => (row[k] as num?)?.toDouble();
    final details = row['details'];
    return BodyAssessment(
      id: row['id'] as String?,
      date: DateTime.parse(row['assessed_on'] as String),
      weightKg: d('weight_kg')!,
      finalFatPct: d('final_fat_pct')!,
      photoFatPct: d('photo_fat_pct'),
      photoFatLow: d('photo_fat_low'),
      photoFatHigh: d('photo_fat_high'),
      tapeFatPct: d('tape_fat_pct'),
      confidence: row['confidence'] as String? ?? 'media',
      details: details is Map<String, dynamic> ? details : const {},
    );
  }

  Map<String, dynamic> toRow() => {
        'assessed_on': isoDate(date),
        'weight_kg': weightKg,
        'final_fat_pct': finalFatPct,
        'photo_fat_pct': photoFatPct,
        'photo_fat_low': photoFatLow,
        'photo_fat_high': photoFatHigh,
        'tape_fat_pct': tapeFatPct,
        'confidence': confidence,
        'details': details,
      };
}

/// Una foto para evaluar: 'front', 'side' o 'back'.
typedef BodyPhoto = ({Uint8List bytes, String mediaType, String view});

/// Evaluaciones: permiso, envío a la IA y guardado del resultado.
abstract interface class BodyAssessmentService {
  Future<bool> hasConsent();
  Future<void> setConsent(bool accepted);
  Future<BodyAiResult> assess(List<BodyPhoto> photos, Map<String, dynamic> context);
  Future<List<BodyAssessment>> list();
  Future<void> save(BodyAssessment a);
  Future<void> delete(String id);
}

/// Mensaje según la respuesta de la función `ai-body`.
String bodyErrorMessage(int status, Object? details) {
  if (details is Map && details['error'] is String) {
    final text = details['error'] as String;
    return status >= 500 ? '$text (error $status)' : text;
  }
  return switch (status) {
    404 => 'La evaluación aún no está instalada en el servidor (función ai-body).',
    413 => 'Una de las fotos es demasiado grande.',
    429 => 'Llegaste al límite de evaluaciones por hoy.',
    _ => 'No se pudo evaluar (error $status). Intenta de nuevo.',
  };
}

class SupabaseBodyAssessmentService implements BodyAssessmentService {
  SupabaseBodyAssessmentService(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> hasConsent() async {
    final row = await _client.from('ai_consents').select('feature').eq('feature', 'body').maybeSingle();
    return row != null;
  }

  @override
  Future<void> setConsent(bool accepted) => accepted
      ? _client.from('ai_consents').upsert({'feature': 'body'}, onConflict: 'user_id,feature', ignoreDuplicates: true)
      : _client.from('ai_consents').delete().eq('feature', 'body');

  @override
  Future<BodyAiResult> assess(List<BodyPhoto> photos, Map<String, dynamic> context) async {
    try {
      final res = await _client.functions.invoke('ai-body', body: {
        'images': [
          for (final p in photos) {'data': base64Encode(p.bytes), 'media_type': p.mediaType, 'view': p.view},
        ],
        'context': context,
      });
      return BodyAiResult.fromJson(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      throw BodyException(bodyErrorMessage(e.status, e.details));
    } catch (_) {
      throw const BodyException('No hay conexión con el servidor. Revisa tu internet.');
    }
  }

  @override
  Future<List<BodyAssessment>> list() async {
    final rows = await _client.from('body_assessments').select().order('assessed_on').order('created_at');
    return [for (final r in rows) BodyAssessment.fromRow(r)];
  }

  @override
  Future<void> save(BodyAssessment a) => _client.from('body_assessments').insert(a.toRow());

  @override
  Future<void> delete(String id) => _client.from('body_assessments').delete().eq('id', id);
}
