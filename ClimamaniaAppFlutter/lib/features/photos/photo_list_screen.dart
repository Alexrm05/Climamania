import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'photo_category.dart';
import 'photo_list_controller.dart';

enum _Source { cameraPhoto, galleryPhoto, galleryVideo }

/// Pantalla de fotos por categoría. Réplica de PhotoListActivity.
class PhotoListScreen extends StatelessWidget {
  final String titulo;
  final String referencia;
  final String categoria;
  final String clave;

  const PhotoListScreen({
    super.key,
    required this.titulo,
    required this.referencia,
    required this.categoria,
    required this.clave,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PhotoListController(
        ctx.read<PedidoRepository>(),
        ctx.read<ApiClient>(),
        ctx.read<SessionService>(),
        referencia: referencia,
        categoria: categoria,
        clave: clave,
      )..init(),
      child: _PhotoListView(titulo: titulo, referencia: referencia),
    );
  }
}

class _PhotoListView extends StatelessWidget {
  final String titulo;
  final String referencia;

  const _PhotoListView({required this.titulo, required this.referencia});

  void _msg(BuildContext context, String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pickAndUpload(BuildContext context, _Source source) async {
    final controller = context.read<PhotoListController>();
    final picker = ImagePicker();
    try {
      if (source == _Source.galleryVideo) {
        final file = await picker.pickVideo(source: ImageSource.gallery);
        if (file == null) return;
        final (ok, msg) = await controller.uploadPath(file.path, file.name);
        if (context.mounted) _msg(context, msg);
        return;
      }

      final file = await picker.pickImage(
        source: source == _Source.cameraPhoto
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (file == null) return;

      // Comprimir + corregir rotación (autoCorrectionAngle por defecto).
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 85,
      );
      final bytes = compressed ?? await file.readAsBytes();
      final name = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final (ok, msg) = await controller.uploadBytes(bytes, name);
      if (context.mounted) _msg(context, msg);
    } catch (_) {
      if (context.mounted) _msg(context, 'No se pudo procesar el archivo');
    }
  }

  void _showUploadOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.primary),
              title: const Text('Cámara (foto)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(context, _Source.cameraPhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Galería (foto)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(context, _Source.galleryPhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: AppColors.primary),
              title: const Text('Galería (vídeo)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(context, _Source.galleryVideo);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Abre el fichero (imagen/PDF) dentro de la app con el WebView, más fiable
  // que lanzar Safari externo.
  void _open(BuildContext context, String doc) {
    context.push('/webview', extra: {'url': AppConfig.fotoUrl(doc)});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text(titulo)),
      body: Consumer<PhotoListController>(
        builder: (context, c, _) {
          return Column(
            children: [
              if (c.uploading)
                LinearProgressIndicator(
                  value: c.uploadProgress > 0 ? c.uploadProgress : null,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: AppDecorations.chipLight,
                    child: Text('Nº $referencia',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                ),
              ),
              Expanded(child: _list(context, c)),
              if (c.canUpload)
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border:
                        Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: c.uploading
                              ? null
                              : () => _showUploadOptions(context),
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.brPill)),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Subir foto o vídeo'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, PhotoListController c) {
    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.fotos.isEmpty) {
      final hasError = c.errorMsg != null;
      return EmptyState(
        icon: hasError
            ? Icons.cloud_off_outlined
            : Icons.photo_library_outlined,
        title: hasError ? c.errorMsg! : 'No hay archivos todavía',
        subtitle: c.canUpload
            ? 'Usa el botón de abajo para subir fotos o vídeos.'
            : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: c.fotos.length,
      itemBuilder: (_, i) {
        final doc = c.fotos[i];
        final kind = fileKindOf(doc, c.categoria);
        if (kind == FileKind.image) {
          return _imageCard(context, c, doc);
        }
        return _fileRow(context, c, doc, kind);
      },
    );
  }

  Future<void> _eliminarFoto(
      BuildContext context, PhotoListController c, String doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Seguro que quieres eliminar esta foto?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoutRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final (ok, msg) = await c.eliminarFoto(doc);
    if (context.mounted) _msg(context, msg);
  }

  Widget _deleteButton(BuildContext context, PhotoListController c, String doc) {
    if (!c.puedeEliminar(doc)) return const SizedBox.shrink();
    if (c.deletingDocs.contains(doc)) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: AppColors.logoutRed),
      tooltip: 'Eliminar foto',
      onPressed: () => _eliminarFoto(context, c, doc),
    );
  }

  Widget _imageCard(BuildContext context, PhotoListController c, String doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _open(context, doc),
        child: Container(
          decoration: AppDecorations.whiteCard,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 200),
                child: Image.network(
                  AppConfig.fotoUrl(doc),
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (ctx, _, _) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('No se pudo cargar')),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(fileNameOf(doc),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ),
                  _deleteButton(context, c, doc),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileRow(
      BuildContext context, PhotoListController c, String doc, FileKind kind) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
                kind == FileKind.video
                    ? Icons.play_circle_outline
                    : Icons.description_outlined,
                color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(fileNameOf(doc),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            ),
            TextButton(
              onPressed: () => kind == FileKind.video
                  ? context.push('/video',
                      extra: {'url': AppConfig.fotoUrl(doc)})
                  : _open(context, doc),
              child: Text(kind == FileKind.video ? 'Ver vídeo' : 'Abrir'),
            ),
            _deleteButton(context, c, doc),
          ],
        ),
      ),
    );
  }
}
