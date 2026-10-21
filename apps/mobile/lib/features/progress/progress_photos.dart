import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format.dart';

/// Ángulo de la foto.
enum PhotoPose {
  front('front', 'Frente'),
  side('side', 'Perfil'),
  back('back', 'Espalda');

  const PhotoPose(this.code, this.label);
  final String code;
  final String label;

  static PhotoPose parse(String? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => front);
}

/// Una foto de progreso guardada.
class ProgressPhoto {
  const ProgressPhoto({
    this.id,
    required this.date,
    required this.pose,
    required this.path,
  });

  factory ProgressPhoto.fromRow(Map<String, dynamic> row) => ProgressPhoto(
        id: row['id'] as String?,
        date: DateTime.parse(row['taken_on'] as String),
        pose: PhotoPose.parse(row['pose'] as String?),
        path: row['path'] as String,
      );

  final String? id;
  final DateTime date;
  final PhotoPose pose;

  /// Ruta en el bucket privado: `<user_id>/<fecha>_<pose>_<aleatorio>.<ext>`.
  final String path;

  @override
  bool operator ==(Object other) => other is ProgressPhoto && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Días desde la última foto; `null` si nunca ha subido una.
int? daysSinceLastPhoto(List<ProgressPhoto> photos, DateTime today) {
  if (photos.isEmpty) return null;
  final last = photos.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
  return DateTime(today.year, today.month, today.day).difference(last).inHours ~/ 24;
}

/// Fechas con fotos, de la más reciente a la más antigua.
List<DateTime> photoDates(List<ProgressPhoto> photos) =>
    ({for (final p in photos) p.date}.toList()..sort((a, b) => b.compareTo(a)));

ProgressPhoto? photoFor(List<ProgressPhoto> photos, DateTime date, PhotoPose pose) {
  for (final p in photos) {
    if (p.date == date && p.pose == pose) return p;
  }
  return null;
}

String _extFor(String mediaType) => switch (mediaType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };

/// Ruta nueva dentro de la carpeta del usuario.
String photoPath(String userId, DateTime date, PhotoPose pose, String mediaType,
    [Random? random]) {
  final r = random ?? Random.secure();
  final suffix = List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$userId/${isoDate(date)}_${pose.code}_$suffix.${_extFor(mediaType)}';
}

abstract interface class ProgressPhotoRepository {
  /// Todas las fotos del usuario, de la más reciente a la más antigua.
  Future<List<ProgressPhoto>> list();
  Future<void> upload({
    required DateTime date,
    required PhotoPose pose,
    required Uint8List bytes,
    required String mediaType,
  });
  Future<Uint8List> bytes(ProgressPhoto photo);
  Future<void> delete(ProgressPhoto photo);
}

class SupabaseProgressPhotoRepository implements ProgressPhotoRepository {
  SupabaseProgressPhotoRepository(this._client);

  final SupabaseClient _client;
  static const bucket = 'progress-photos';

  StorageFileApi get _storage => _client.storage.from(bucket);

  @override
  Future<List<ProgressPhoto>> list() async {
    final rows = await _client
        .from('progress_photos')
        .select()
        .order('taken_on', ascending: false);
    return [for (final r in rows) ProgressPhoto.fromRow(r)];
  }

  @override
  Future<void> upload({
    required DateTime date,
    required PhotoPose pose,
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final path = photoPath(_client.auth.currentUser!.id, date, pose, mediaType);
    await _storage.uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: mediaType));
    try {
      await _client.from('progress_photos').insert({
        'taken_on': isoDate(date),
        'pose': pose.code,
        'path': path,
      });
    } catch (_) {
      // Sin fila no se vería nunca: no dejar la imagen huérfana.
      await _storage.remove([path]);
      rethrow;
    }
  }

  @override
  Future<Uint8List> bytes(ProgressPhoto photo) => _storage.download(photo.path);

  @override
  Future<void> delete(ProgressPhoto photo) async {
    await _storage.remove([photo.path]);
    await _client.from('progress_photos').delete().eq('path', photo.path);
  }
}
