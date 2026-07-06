import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/gestion_item.dart';
import '../../theme/app_colors.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';
import 'widgets/visita_card.dart';

/// Histórico de visitas asociadas a una referencia (mostrado desde el detalle
/// del pedido). Réplica de VisitasPreviasActivity: tarjetas sin acciones, estado
/// "Visita previa"; al pulsar abre el detalle de la visita.
class VisitasPreviasScreen extends StatelessWidget {
  final List<GestionItem> visitas;
  final String referencia;

  const VisitasPreviasScreen({
    super.key,
    required this.visitas,
    this.referencia = '',
  });

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
      child: visitas.isEmpty
          ? const Center(
              child: Text('No hay visitas previas.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (referencia.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Listado de visitas asociadas a la referencia: $referencia',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                for (final v in visitas)
                  VisitaCard(
                    visita: v,
                    estadoLabel: 'Visita previa',
                    showActions: false,
                    codigo: v.referencia.isNotEmpty
                        ? v.referencia
                        : 'Visita #${v.id}',
                    onTap: () => _openVisita(context, v),
                  ),
              ],
            ),
    );
  }
}
