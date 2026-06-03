import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/gestion_item.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import 'visitas_pendientes_controller.dart';
import 'widgets/visita_card.dart';

/// Lista de visitas pendientes. Réplica de VisitasPendientesActivity.
class VisitasPendientesScreen extends StatelessWidget {
  const VisitasPendientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => VisitasPendientesController(
        ctx.read<VisitaRepository>(),
        ctx.read<SessionService>(),
      )..init(),
      child: const _VisitasPendientesView(),
    );
  }
}

class _VisitasPendientesView extends StatelessWidget {
  const _VisitasPendientesView();

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir')));
        }
      }
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
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dir)}'),
    );
  }

  void _call(BuildContext context, GestionItem v) {
    if (v.telefono.isEmpty) return;
    _launch(context, Uri.parse('tel:${v.telefono}'));
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
      appBar: AppBar(title: const Text('Visitas pendientes')),
      body: Consumer<VisitasPendientesController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.visitas.isEmpty) {
            return RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      c.errorMsg ?? 'No tienes visitas pendientes.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Ordenadas por prioridad y fecha de solicitud',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                for (final v in c.visitas)
                  VisitaCard(
                    visita: v,
                    estadoLabel: 'Visita pendiente',
                    onTap: () =>
                        context.push('/visita', extra: {'id': v.id}),
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
