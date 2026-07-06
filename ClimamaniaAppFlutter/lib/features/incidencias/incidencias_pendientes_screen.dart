import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/external_actions.dart';
import '../../data/models/gestion_item.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
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

  String _dir(GestionItem v) => [
        if (v.direccion.isNotEmpty) v.direccion,
        if (v.poblacion.isNotEmpty) v.poblacion,
      ].join(', ');

  void _openIncidencia(BuildContext context, GestionItem v) {
    final id = v.id.trim();
    if (id.isEmpty || id == '0' || id.toLowerCase() == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID de incidencia no disponible')));
      return;
    }
    context.push('/incidencia', extra: {'id': id, 'referencia': v.referencia});
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: Consumer<IncidenciasPendientesController>(
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
                    onTap: () => _openIncidencia(context, v),
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
