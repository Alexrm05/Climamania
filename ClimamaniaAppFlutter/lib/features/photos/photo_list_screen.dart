import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/media_picker.dart';
import '../../core/photo_network_image.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
import 'photo_category.dart';
import 'photo_list_controller.dart';

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

  Future<void> _pickAndUpload(BuildContext context, MediaSource source) async {
    final controller = context.read<PhotoListController>();
    try {
      final media = await pickMedia(source);
      if (media == null) return;
      final (_, msg) = media.isVideo
          ? await controller.uploadPath(media.path!, media.filename)
          : await controller.uploadBytes(media.bytes!, media.filename);
      if (context.mounted) _msg(context, msg);
    } on MediaTooLargeException catch (e) {
      if (context.mounted) _msg(context, e.message);
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
                _pickAndUpload(context, MediaSource.cameraPhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Galería (foto)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(context, MediaSource.galleryPhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: AppColors.primary),
              title: const Text('Galería (vídeo)'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUpload(context, MediaSource.galleryVideo);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el documento/imagen en el WebView interno (como WebViewActivity), con
  /// la primera URL candidata.
  void _open(BuildContext context, String doc) {
    final candidates = AppConfig.buildPhotoCandidates(doc);
    if (candidates.isEmpty) return;
    context.push('/webview', extra: {'url': candidates.first});
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      onReload: () => context.read<PhotoListController>().load(),
      child: Consumer<PhotoListController>(
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
                  child: Text('Referencia $referencia',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              ),
              Expanded(child: _list(context, c)),
              if (c.canUpload)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: c.uploading
                            ? null
                            : () => _showUploadOptions(context),
                        icon: const Icon(Icons.upload),
                        label: const Text('Subir foto o vídeo'),
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
      return Center(
        child: Text(
          c.errorMsg ?? 'No hay archivos disponibles.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: c.fotos.length,
      itemBuilder: (_, i) {
        final doc = c.fotos[i];
        final kind = fileKindOf(doc, c.categoria);
        if (kind == FileKind.image) {
          return _imageCard(context, doc);
        }
        return _fileRow(context, doc, kind);
      },
    );
  }

  Widget _imageCard(BuildContext context, String doc) {
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
              SizedBox(
                height: 220,
                child: PhotoNetworkImage(
                  candidates: AppConfig.buildPhotoCandidates(doc),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: 220,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(fileNameOf(doc),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileRow(BuildContext context, String doc, FileKind kind) {
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
                      extra: {'urls': AppConfig.buildPhotoCandidates(doc)})
                  : _open(context, doc),
              child: Text(kind == FileKind.video ? 'Ver vídeo' : 'Abrir'),
            ),
          ],
        ),
      ),
    );
  }
}
