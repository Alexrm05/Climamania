import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../visitas/widgets/gestion_detalle_body.dart';
import 'incidencia_detalle_controller.dart';

/// Detalle de una incidencia. Réplica de IncidenciaDetalleActivity.
class IncidenciaDetalleScreen extends StatelessWidget {
  final String idIncidencia;

  const IncidenciaDetalleScreen({super.key, required this.idIncidencia});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => IncidenciaDetalleController(
        ctx.read<IncidenciaRepository>(),
        ctx.read<SessionService>(),
        idIncidencia,
      )..init(),
      child: _View(idIncidencia: idIncidencia),
    );
  }
}

class _View extends StatelessWidget {
  final String idIncidencia;
  const _View({required this.idIncidencia});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Incidencia #$idIncidencia')),
      body: Consumer<IncidenciaDetalleController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.detalle == null) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: c.errorMsg ?? 'No se pudo cargar la incidencia',
              subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
            );
          }
          final d = c.detalle!;
          return GestionDetalleBody(
            item: d.visita,
            muro: d.muro,
            ficheros: d.ficheros,
            esIncidencia: true,
            gestionarLabel: 'Gestionar incidencia',
            onRefresh: c.load,
            onGestionar: () async {
              await context.push('/incidencia-enviar', extra: {
                'id': d.visita.id,
                'cliente': d.visita.cliente,
                'direccion': d.visita.direccion,
                'poblacion': d.visita.poblacion,
              });
              await c.load();
            },
          );
        },
      ),
    );
  }
}
