import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/gestion_item.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../visitas/widgets/visita_card.dart';
import 'incidencias_pendientes_controller.dart';

/// Lista de incidencias pendientes. Réplica de IncidenciasPendientesActivity.
class IncidenciasPendientesScreen extends StatelessWidget {
  const IncidenciasPendientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => IncidenciasPendientesController(
        ctx.read<IncidenciaRepository>(),
        ctx.read<SessionService>(),
      )..init(),
      child: const _View(),
    );
  }
}

String _codigo(GestionItem i) =>
    i.referencia.isNotEmpty ? i.referencia : 'Incidencia #${i.id}';

class _View extends StatelessWidget {
  const _View();

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _maps(BuildContext context, GestionItem v) {
    final dir = [
      if (v.direccion.isNotEmpty) v.direccion,
      if (v.poblacion.isNotEmpty) v.poblacion,
    ].join(', ');
    if (dir.isEmpty) return;
    _launch(
        context,
        Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dir)}'));
  }

  void _call(BuildContext context, GestionItem v) {
    if (v.telefono.isNotEmpty) _launch(context, Uri.parse('tel:${v.telefono}'));
  }

  void _message(BuildContext context, GestionItem v) {
    if (v.telefono.isEmpty) return;
    final body = Uri.encodeComponent('Hola ${v.cliente}, ');
    _launch(context, Uri.parse('sms:${v.telefono}?body=$body'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Incidencias pendientes')),
      body: Consumer<IncidenciasPendientesController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.incidencias.isEmpty) {
            return RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                      child: Text(c.errorMsg ?? 'No tienes incidencias pendientes.',
                          style:
                              const TextStyle(color: AppColors.textSecondary))),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: c.load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                for (final v in c.incidencias)
                  VisitaCard(
                    visita: v,
                    estadoLabel: 'Incidencia pendiente',
                    codigo: _codigo(v),
                    onTap: () => context.push('/incidencia', extra: {'id': v.id}),
                    onMaps: () => _maps(context, v),
                    onCall: () => _call(context, v),
                    onMessage: () => _message(context, v),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
