import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Qué muestra la foto.
enum PhotoMode { plate, label }

/// Un alimento que la IA reconoció en la foto. Editable antes de guardar.
class PhotoItem {
  PhotoItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num? ?? 0).toDouble();
    return PhotoItem(
      name: j['name'] as String? ?? 'Alimento',
      quantity: d('quantity'),
      unit: j['unit'] as String? ?? 'g',
      kcal: d('kcal'),
      protein: d('protein_g'),
      carbs: d('carbs_g'),
      fat: d('fat_g'),
    );
  }

  String name;
  double quantity;
  String unit;
  double kcal;
  double protein;
  double carbs;
  double fat;
  bool include = true;

  /// Cambia la cantidad y ajusta los nutrientes en la misma proporción.
  void scaleTo(double newQuantity) {
    if (quantity <= 0 || newQuantity <= 0) return;
    final k = newQuantity / quantity;
    kcal *= k;
    protein *= k;
    carbs *= k;
    fat *= k;
    quantity = newQuantity;
  }
}

class PhotoAnalysis {
  const PhotoAnalysis({
    required this.items,
    required this.confidence,
    required this.notes,
  });

  factory PhotoAnalysis.fromJson(Map<String, dynamic> j) => PhotoAnalysis(
        items: [
          for (final i in (j['items'] as List? ?? const []))
            PhotoItem.fromJson(i as Map<String, dynamic>),
        ],
        confidence: j['confidence'] as String? ?? 'media',
        notes: j['notes'] as String? ?? '',
      );

  final List<PhotoItem> items;

  /// 'alta', 'media' o 'baja'.
  final String confidence;
  final String notes;
}

/// Error con un mensaje listo para mostrar.
class PhotoException implements Exception {
  const PhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PhotoAnalyzer {
  Future<PhotoAnalysis> analyze({
    required Uint8List bytes,
    required String mediaType,
    required PhotoMode mode,
    String? note,
    double? remainingKcal,
  });

  /// Lo que comió, escrito o dictado por voz.
  Future<PhotoAnalysis> describe({required String text, double? remainingKcal});
}

/// Tipo de imagen según el nombre del archivo.
String mediaTypeFor(String fileName, String? reported) {
  if (reported != null && reported.startsWith('image/')) return reported;
  final n = fileName.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

/// Mensaje para el usuario según la respuesta de la función. Incluye el
/// código de estado cuando el error es inesperado, para poder diagnosticar.
String photoErrorMessage(int status, Object? details) {
  if (details is Map && details['error'] is String) {
    final text = details['error'] as String;
    return status >= 500 ? '$text (error $status)' : text;
  }
  return switch (status) {
    401 || 403 =>
      'El servidor rechazó tu sesión (error $status). Cierra sesión y vuelve '
          'a entrar; si sigue, hay que revisar la verificación JWT de ai-photo.',
    404 => 'La función de IA aún no está instalada en el servidor.',
    413 => 'La imagen es demasiado grande.',
    429 => 'Llegaste al límite de análisis por hoy.',
    _ => 'No se pudo analizar (error $status). Intenta de nuevo.',
  };
}

/// Llama a la función `ai-photo` del servidor.
class SupabasePhotoAnalyzer implements PhotoAnalyzer {
  SupabasePhotoAnalyzer(this._client);

  final SupabaseClient _client;

  @override
  Future<PhotoAnalysis> analyze({
    required Uint8List bytes,
    required String mediaType,
    required PhotoMode mode,
    String? note,
    double? remainingKcal,
  }) async {
    try {
      final res = await _client.functions.invoke('ai-photo', body: {
        'image': base64Encode(bytes),
        'media_type': mediaType,
        'mode': mode == PhotoMode.label ? 'label' : 'plate',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (remainingKcal != null) 'remaining_kcal': remainingKcal,
      });
      return PhotoAnalysis.fromJson(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      throw PhotoException(photoErrorMessage(e.status, e.details));
    } catch (_) {
      throw const PhotoException(
          'No hay conexión con el servidor. Revisa tu internet.');
    }
  }

  @override
  Future<PhotoAnalysis> describe({
    required String text,
    double? remainingKcal,
  }) async {
    try {
      final res = await _client.functions.invoke('ai-photo', body: {
        'mode': 'text',
        'text': text.trim(),
        if (remainingKcal != null) 'remaining_kcal': remainingKcal,
      });
      return PhotoAnalysis.fromJson(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      throw PhotoException(photoErrorMessage(e.status, e.details));
    } catch (_) {
      throw const PhotoException(
          'No hay conexión con el servidor. Revisa tu internet.');
    }
  }
}

/// Imagen elegida por el usuario.
typedef PickedImage = ({Uint8List bytes, String name, String? mimeType});

/// Abre la cámara o la galería. Devuelve `null` si el usuario cancela.
typedef ImagePickFn = Future<PickedImage?> Function({required bool camera});

/// Implementación real con image_picker: imagen reducida a 1.280 px y
/// calidad 85 para que viaje liviana.
Future<PickedImage?> pickWithImagePicker({required bool camera}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 85,
  );
  if (file == null) return null;
  return (bytes: await file.readAsBytes(), name: file.name, mimeType: file.mimeType);
}
