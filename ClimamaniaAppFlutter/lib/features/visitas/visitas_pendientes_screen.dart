import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/external_actions.dart';
import '../../data/models/gestion_item.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
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

  String _dir(GestionItem v) => [
        if (v.direccion.isNotEmpty) v.direccion,
        if (v.poblacion.isNotEmpty) v.poblacion,
      ].join(', ');

  void _openVisita(BuildContext context, GestionItem v) {
    final id = v.id.trim();
    if (id.isEmpty || id == '0' || id.toLowerCase() == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID de visita no disponible')));
      return;
    }
    context.push('/visita', extra: {'id': id});
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: Consumer<VisitasPendientesController>(
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
                    onTap: () => _openVisita(context, v),
                    onMaps: () => ExternalActions.openMaps(context, _dir(v)),
                    onCall: () => ExternalActions.call(context, v.telefono),
                    onMessage: () =>
                        ExternalActions.sms(context, v.telefono, v.cliente),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
