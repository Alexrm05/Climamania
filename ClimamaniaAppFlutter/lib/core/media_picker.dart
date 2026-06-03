import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

enum MediaSource { cameraPhoto, cameraVideo, galleryPhoto, galleryVideo }

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
/// Devuelve null si el usuario cancela.
Future<PreparedMedia?> pickMedia(MediaSource source) async {
  final picker = ImagePicker();

  if (source == MediaSource.cameraVideo ||
      source == MediaSource.galleryVideo) {
    final file = await picker.pickVideo(
      source: source == MediaSource.cameraVideo
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (file == null) return null;
    return PreparedMedia(path: file.path, filename: file.name, isVideo: true);
  }

  final file = await picker.pickImage(
    source: source == MediaSource.cameraPhoto
        ? ImageSource.camera
        : ImageSource.gallery,
  );
  if (file == null) return null;
  final compressed = await FlutterImageCompress.compressWithFile(
    file.path,
    minWidth: 1600,
    minHeight: 1600,
    quality: 85,
  );
  final bytes = compressed ?? await file.readAsBytes();
  return PreparedMedia(
    bytes: bytes,
    filename: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
    isVideo: false,
  );
}
