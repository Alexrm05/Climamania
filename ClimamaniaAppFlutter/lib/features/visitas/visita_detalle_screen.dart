import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import 'visita_detalle_controller.dart';
import 'widgets/gestion_detalle_body.dart';

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
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: c.errorMsg ?? 'No se pudo cargar la visita',
              subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
            );
          }
          final d = c.detalle!;
          return GestionDetalleBody(
            item: d.visita,
            muro: d.muro,
            ficheros: d.ficheros,
            esIncidencia: false,
            gestionarLabel: 'Gestionar visita',
            onRefresh: c.load,
            onGestionar: () async {
              await context.push('/visita-enviar', extra: {
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
