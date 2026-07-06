import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

enum MediaSource { cameraPhoto, cameraVideo, galleryPhoto, galleryVideo }

/// Tamaño máximo de subida (80 MB), igual que `MAX_UPLOAD_BYTES` en Android.
const int kMaxUploadBytes = 80 * 1024 * 1024;

/// Se lanza cuando el fichero elegido supera el límite de subida.
class MediaTooLargeException implements Exception {
  final String message;
  MediaTooLargeException([this.message = 'El archivo supera 80 MB']);
  @override
  String toString() => message;
}

/// Medio ya preparado para subir: imagen comprimida (bytes) o vídeo (ruta).
class PreparedMedia {
  final List<int>? bytes;
  final String? path;
  final String filename;
  final bool isVideo;

  const PreparedMedia({
    this.bytes,
    this.path,
    required this.filename,
    required this.isVideo,
  });
}

/// Captura/elige un medio y lo prepara (comprime imágenes, corrige rotación).
/// Devuelve null si el usuario cancela. Lanza [MediaTooLargeException] si el
/// fichero supera 80 MB.
Future<PreparedMedia?> pickMedia(MediaSource source) async {
  final picker = ImagePicker();
  final isCamera =
      source == MediaSource.cameraPhoto || source == MediaSource.cameraVideo;
  final ts = DateTime.now().millisecondsSinceEpoch;

  if (source == MediaSource.cameraVideo ||
      source == MediaSource.galleryVideo) {
    final file = await picker.pickVideo(
      source: isCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null) return null;
    final len = await File(file.path).length();
    if (len > kMaxUploadBytes) throw MediaTooLargeException();
    final name = isCamera ? 'visita_video_$ts.mp4' : _ensureVideoName(file.name);
    return PreparedMedia(path: file.path, filename: name, isVideo: true);
  }

  final file = await picker.pickImage(
    source: isCamera ? ImageSource.camera : ImageSource.gallery,
  );
  if (file == null) return null;
  final original = await file.readAsBytes();
  final bytes = await _compressMaxSide(original) ?? original;
  if (bytes.length > kMaxUploadBytes) throw MediaTooLargeException();
  final name = isCamera ? 'foto_$ts.jpg' : _ensureJpgName(file.name);
  return PreparedMedia(bytes: bytes, filename: name, isVideo: false);
}

/// Comprime la imagen reduciendo su **lado mayor** a ≤1600 px (como Android),
/// conservando la corrección de rotación EXIF de flutter_image_compress.
Future<List<int>?> _compressMaxSide(Uint8List data) async {
  var targetW = 1600, targetH = 1600;
  try {
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final w = frame.image.width, h = frame.image.height;
    frame.image.dispose();
    final maxSide = max(w, h);
    if (maxSide <= 1600) {
      targetW = w;
      targetH = h;
    } else {
      final scale = 1600 / maxSide;
      targetW = (w * scale).round();
      targetH = (h * scale).round();
    }
  } catch (_) {
    // Si no podemos leer dimensiones, usamos 1600 como cota.
  }
  final out = await FlutterImageCompress.compressWithList(
    data,
    minWidth: targetW,
    minHeight: targetH,
    quality: 85,
  );
  return out.isEmpty ? null : out;
}

String _basename(String name) {
  final slash = name.lastIndexOf(RegExp(r'[\\/]'));
  return slash >= 0 ? name.substring(slash + 1) : name;
}

/// Conserva el nombre original de galería forzando la extensión `.jpg`.
String _ensureJpgName(String name) {
  final base = _basename(name).trim();
  if (base.isEmpty) return 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  return '$stem.jpg';
}

const _videoExts = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'avi', 'mkv'};

/// Conserva el nombre original de galería para vídeos; si no trae extensión de
/// vídeo reconocible, añade `.mp4`.
String _ensureVideoName(String name) {
  final base = _basename(name).trim();
  if (base.isEmpty) return 'visita_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  final dot = base.lastIndexOf('.');
  final ext = dot > 0 ? base.substring(dot + 1).toLowerCase() : '';
  if (_videoExts.contains(ext)) return base;
  return '$base.mp4';
}
