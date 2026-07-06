import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/media_picker.dart';
import '../../core/priority.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

/// Gestión de una incidencia. Réplica de IncidenciaEnviarActivity.
class IncidenciaEnviarScreen extends StatefulWidget {
  final String idIncidencia;
  final String referencia;
  final String cliente;
  final String direccion;
  final String poblacion;

  const IncidenciaEnviarScreen({
    super.key,
    required this.idIncidencia,
    this.referencia = '',
    this.cliente = '',
    this.direccion = '',
    this.poblacion = '',
  });

  @override
  State<IncidenciaEnviarScreen> createState() => _IncidenciaEnviarScreenState();
}

class _IncidenciaEnviarScreenState extends State<IncidenciaEnviarScreen> {
  bool _busy = false;

  IncidenciaRepository get _repo => context.read<IncidenciaRepository>();
  SessionService get _session => context.read<SessionService>();

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Map<String, String> _ctx() => {
        'rol': _session.rol,
        'usuario': _session.usuarioForRequests,
        'equipo': _session.readEquipo(),
        'autor': _session.displayName(fallback: 'Instalador'),
      };

  Future<void> _comentario() async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar comentarios escritos'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe un mensaje...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (texto == null || !mounted) return;
    if (texto.isEmpty) {
      _msg('Debes escribir un comentario');
      return;
    }
    setState(() => _busy = true);
    final c = _ctx();
    final (_, msg) = await _repo.enviarComentario(
      idIncidencia: widget.idIncidencia,
      rol: c['rol']!,
      usuario: c['usuario']!,
      equipo: c['equipo']!,
      autor: c['autor']!,
      mensaje: texto,
    );
    if (mounted) setState(() => _busy = false);
    _msg(msg);
  }

  void _fotos() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opt(sheetCtx, Icons.photo_camera, 'Cámara (foto)',
                MediaSource.cameraPhoto),
            _opt(sheetCtx, Icons.videocam, 'Cámara (vídeo)',
                MediaSource.cameraVideo),
            _opt(sheetCtx, Icons.photo_library, 'Galería (foto)',
                MediaSource.galleryPhoto),
            _opt(sheetCtx, Icons.video_library, 'Galería (vídeo)',
                MediaSource.galleryVideo),
          ],
        ),
      ),
    );
  }

  Widget _opt(BuildContext sheetCtx, IconData icon, String label,
      MediaSource source) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(sheetCtx);
        _subirMedia(source);
      },
    );
  }

  Future<void> _subirMedia(MediaSource source) async {
    try {
      final media = await pickMedia(source);
      if (media == null || !mounted) return;
      setState(() => _busy = true);
      final c = _ctx();
      final (_, msg) = media.isVideo
          ? await _repo.enviarFotoPath(
              idIncidencia: widget.idIncidencia,
              rol: c['rol']!,
              usuario: c['usuario']!,
              equipo: c['equipo']!,
              autor: c['autor']!,
              iniciales: _session.iniciales,
              path: media.path!,
              filename: media.filename,
            )
          : await _repo.enviarFotoBytes(
              idIncidencia: widget.idIncidencia,
              rol: c['rol']!,
              usuario: c['usuario']!,
              equipo: c['equipo']!,
              autor: c['autor']!,
              iniciales: _session.iniciales,
              bytes: media.bytes!,
              filename: media.filename,
            );
      if (mounted) setState(() => _busy = false);
      _msg(msg);
    } on MediaTooLargeException catch (e) {
      if (mounted) setState(() => _busy = false);
      _msg(e.message);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _msg('No se pudo procesar el archivo');
    }
  }

  Future<void> _prioridad() async {
    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar prioridad de la incidencia'),
        children: [
          for (final p in Prioridad.opciones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text(p),
            ),
        ],
      ),
    );
    if (sel == null || !mounted) return;
    setState(() => _busy = true);
    final c = _ctx();
    final (_, msg) = await _repo.cambiarPrioridad(
      idIncidencia: widget.idIncidencia,
      rol: c['rol']!,
      usuario: c['usuario']!,
      equipo: c['equipo']!,
      autor: c['autor']!,
      prioridad: sel,
    );
    if (mounted) setState(() => _busy = false);
    _msg(msg);
  }

  Future<void> _cerrar() async {
    final r = await context.push('/cerrar-gestion', extra: {
      'tipo': 'incidencia',
      'id': widget.idIncidencia,
      'cliente': widget.cliente,
      'direccion': widget.direccion,
      'poblacion': widget.poblacion,
    });
    if (r == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: AppDecorations.whiteCard,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.cliente.isNotEmpty)
                      Text(widget.cliente,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark)),
                    if (widget.direccion.isNotEmpty ||
                        widget.poblacion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                            [widget.direccion, widget.poblacion]
                                .where((e) => e.isNotEmpty)
                                .join(', '),
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF455A64))),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _bigBtn('Enviar comentarios escritos', Icons.comment, _comentario),
              const SizedBox(height: 10),
              _bigBtn('Enviar fotos o vídeos', Icons.photo_camera, _fotos),
              const SizedBox(height: 10),
              _bigBtn('Cambiar prioridad de la incidencia', Icons.flag,
                  _prioridad),
              const SizedBox(height: 10),
              _bigBtn('Finalizar / Cancelar incidencia', Icons.flag_circle,
                  _cerrar,
                  outlined: true),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bigBtn(String label, IconData icon, VoidCallback onTap,
      {bool outlined = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft),
            ),
    );
  }
}
