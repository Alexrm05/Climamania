import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/media_picker.dart';
import '../../core/priority.dart';
import '../../core/widgets/busy_overlay.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/gestion_enviar_body.dart';

/// Gestión de una visita: comentarios, fotos/vídeo, prioridad, finalizar/cancelar.
/// Réplica de VisitaEnviarActivity.
class VisitaEnviarScreen extends StatefulWidget {
  final String idVisita;
  final String cliente;
  final String direccion;
  final String poblacion;

  const VisitaEnviarScreen({
    super.key,
    required this.idVisita,
    this.cliente = '',
    this.direccion = '',
    this.poblacion = '',
  });

  @override
  State<VisitaEnviarScreen> createState() => _VisitaEnviarScreenState();
}

class _VisitaEnviarScreenState extends State<VisitaEnviarScreen> {
  bool _busy = false;

  VisitaRepository get _repo => context.read<VisitaRepository>();
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.confirm),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (texto == null || texto.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final c = _ctx();
    final (ok, msg) = await _repo.enviarComentario(
      idVisita: widget.idVisita,
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
      final (ok, msg) = media.isVideo
          ? await _repo.enviarFotoPath(
              idVisita: widget.idVisita,
              rol: c['rol']!,
              usuario: c['usuario']!,
              equipo: c['equipo']!,
              autor: c['autor']!,
              iniciales: _session.iniciales,
              path: media.path!,
              filename: media.filename,
            )
          : await _repo.enviarFotoBytes(
              idVisita: widget.idVisita,
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
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      _msg('No se pudo procesar el archivo');
    }
  }

  Future<void> _prioridad() async {
    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar prioridad de la visita'),
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
    final (ok, msg) = await _repo.cambiarPrioridad(
      idVisita: widget.idVisita,
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
    await context.push('/cerrar-gestion', extra: {
      'tipo': 'visita',
      'id': widget.idVisita,
      'cliente': widget.cliente,
      'direccion': widget.direccion,
      'poblacion': widget.poblacion,
    });
  }

  @override
  Widget build(BuildContext context) {
    final direccion = [widget.direccion, widget.poblacion]
        .where((e) => e.isNotEmpty)
        .join(', ');
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Gestionar visita #${widget.idVisita}')),
      body: BusyOverlay(
        busy: _busy,
        child: GestionEnviarBody(
          cliente: widget.cliente,
          direccion: direccion,
          esIncidencia: false,
          actions: [
            GestionEnviarAction(
                icon: Icons.chat_outlined,
                label: 'Comentarios',
                subtitle: 'Añadir nota',
                onTap: _comentario),
            GestionEnviarAction(
                icon: Icons.photo_camera_outlined,
                label: 'Fotos y vídeos',
                subtitle: 'Cámara o galería',
                onTap: _fotos),
            GestionEnviarAction(
                icon: Icons.flag_outlined,
                label: 'Prioridad',
                subtitle: 'Alta · media · baja',
                onTap: _prioridad),
            GestionEnviarAction(
                icon: Icons.task_alt,
                label: 'Finalizar',
                subtitle: 'o cancelar',
                onTap: _cerrar,
                danger: true),
          ],
        ),
      ),
    );
  }
}
