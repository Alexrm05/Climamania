/// Tipo de archivo para decidir cómo se muestra.
enum FileKind { image, video, document }

const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
const _videoExts = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'avi', 'mkv'};

FileKind fileKindOf(String path, String categoria) {
  // Las categorías documentales se tratan como fichero aunque la extensión varíe.
  if (categoria == 'boe' || categoria == 'documentos') return FileKind.document;
  final lower = path.toLowerCase();
  final ext = lower.contains('.') ? lower.split('.').last : '';
  if (_imageExts.contains(ext)) return FileKind.image;
  if (_videoExts.contains(ext)) return FileKind.video;
  return FileKind.document;
}

String fileNameOf(String path) {
  final clean = path.split('?').first;
  final parts = clean.split('/');
  return parts.isEmpty ? path : parts.last;
}
