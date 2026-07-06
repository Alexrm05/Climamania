import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/gestion_item.dart';
import '../../theme/app_colors.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
import '../visitas/widgets/visita_card.dart';

/// Histórico de incidencias asociadas a una referencia (mostrado desde el
/// detalle del pedido). Réplica de IncidenciasPreviasActivity: tarjetas sin
/// acciones, estado "Incidencia previa"; al pulsar abre el detalle pasando el
/// id de la incidencia y la referencia.
class IncidenciasPreviasScreen extends StatelessWidget {
  final List<GestionItem> incidencias;
  final String referencia;

  const IncidenciasPreviasScreen({
    super.key,
    required this.incidencias,
    this.referencia = '',
  });

  void _openIncidencia(BuildContext context, GestionItem i) {
    final id = i.id.trim();
    if (id.isEmpty || id == '0' || id.toLowerCase() == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID de incidencia no disponible')));
      return;
    }
    context.push('/incidencia', extra: {'id': id, 'referencia': i.referencia});
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: incidencias.isEmpty
          ? const Center(
              child: Text('No hay incidencias previas.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (referencia.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Listado de incidencias asociadas a la referencia: $referencia',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                for (final i in incidencias)
                  VisitaCard(
                    visita: i,
                    estadoLabel: 'Incidencia previa',
                    showActions: false,
                    codigo: i.referencia.isNotEmpty
                        ? i.referencia
                        : 'Incidencia #${i.id}',
                    onTap: () => _openIncidencia(context, i),
                  ),
              ],
            ),
    );
  }
}
