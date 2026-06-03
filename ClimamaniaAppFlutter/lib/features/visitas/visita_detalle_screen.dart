import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/priority.dart';
import '../../data/models/gestion_item.dart';
import '../../data/models/visita_detalle.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import 'visita_detalle_controller.dart';
import 'widgets/visita_card.dart';

/// Detalle de una visita. Réplica de VisitaDetalleActivity.
class VisitaDetalleScreen extends StatelessWidget {
  final String idVisita;

  const VisitaDetalleScreen({super.key, required this.idVisita});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => VisitaDetalleController(
        ctx.read<VisitaRepository>(),
        ctx.read<SessionService>(),
        idVisita,
      )..init(),
      child: _VisitaDetalleView(idVisita: idVisita),
    );
  }
}

class _VisitaDetalleView extends StatelessWidget {
  final String idVisita;
  const _VisitaDetalleView({required this.idVisita});

  /// Vídeos → reproductor interno; resto (imágenes/documentos) → externo.
  void _openFichero(BuildContext context, Fichero f) {
    if (f.isVideo) {
      context.push('/video', extra: {'url': AppConfig.fotoUrl(f.ruta)});
    } else {
      _open(context, f.ruta);
    }
  }

  Future<void> _open(BuildContext context, String ruta) async {
    final uri = Uri.parse(AppConfig.fotoUrl(ruta));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Visita #$idVisita')),
      body: Consumer<VisitaDetalleController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.detalle == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(c.errorMsg ?? 'No se pudo cargar la visita',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          final d = c.detalle!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _datosCard(context, c, d.visita),
              _muroCard(d.muro),
              _ficherosCard(context, d.ficheros),
            ],
          );
        },
      ),
    );
  }

  Widget _datosCard(
      BuildContext context, VisitaDetalleController c, GestionItem v) {
    final prio = Prioridad.parse(v.prioridad);
    final dir = [
      if (v.direccion.isNotEmpty) v.direccion,
      if (v.poblacion.isNotEmpty) v.poblacion,
    ].join(', ');
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(v.cliente.isEmpty ? 'Visita #${v.id}' : v.cliente,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: Prioridad.bg(prio),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(prio,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Prioridad.fg(prio),
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dir.isNotEmpty) _line('Dirección', dir),
          if (v.telefono.isNotEmpty) _line('Teléfono', v.telefono),
          if (v.equipoId.isNotEmpty) _line('Equipo', v.equipoId),
          if (v.fechaSolicitud.isNotEmpty)
            _line('Solicitada', VisitaCard.fechaCorta(v.fechaSolicitud)),
          if (v.solicitante.isNotEmpty) _line('Solicita', v.solicitante),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.build, size: 18),
              label: const Text('Gestionar visita'),
              onPressed: () async {
                await context.push('/visita-enviar', extra: {
                  'id': v.id,
                  'cliente': v.cliente,
                  'direccion': v.direccion,
                  'poblacion': v.poblacion,
                });
                await c.load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _muroCard(List<MuroMensaje> muro) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de la visita',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            if (muro.isEmpty)
              const Text('Sin mensajes.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              for (final m in muro) _muroItem(m),
          ],
        ),
      ),
    );
  }

  Widget _muroItem(MuroMensaje m) {
    final meta = [
      if (m.autor.isNotEmpty) m.autor,
      if (m.rol.isNotEmpty) m.rol,
      if (m.dateAdd.isNotEmpty) VisitaCard.fechaCorta(m.dateAdd),
    ].join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.mensaje.isEmpty ? '—' : m.mensaje,
              style: const TextStyle(fontSize: 15, color: Color(0xFF263238))),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(meta,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _ficherosCard(BuildContext context, List<Fichero> ficheros) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: Container(
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ficheros',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            if (ficheros.isEmpty)
              const Text('Sin ficheros.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              for (final f in ficheros) _ficheroItem(context, f),
          ],
        ),
      ),
    );
  }

  Widget _ficheroItem(BuildContext context, Fichero f) {
    final meta = [
      if (f.tipoFichero.isNotEmpty) f.tipoFichero,
      if (f.usuario.isNotEmpty) f.usuario,
      if (f.dateAdd.isNotEmpty) VisitaCard.fechaCorta(f.dateAdd),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openFichero(context, f),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardStroke),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.isImage)
                Image.network(
                  AppConfig.fotoUrl(f.ruta),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                      height: 60,
                      child: Center(child: Text('No se pudo cargar'))),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                        f.isVideo
                            ? Icons.play_circle_outline
                            : (f.isImage
                                ? Icons.image_outlined
                                : Icons.description_outlined),
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14)),
                          if (meta.isNotEmpty)
                            Text(meta,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(f.isVideo ? 'Ver vídeo' : 'Abrir',
                        style: const TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
