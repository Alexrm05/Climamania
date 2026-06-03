import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/priority.dart';
import '../../../data/models/gestion_item.dart';
import '../../../theme/app_colors.dart';

/// Tarjeta de visita (pendiente o previa). Réplica de item_visita_pendiente.
class VisitaCard extends StatelessWidget {
  final GestionItem visita;
  final String estadoLabel; // "Visita pendiente" / "Incidencia pendiente"
  final String? codigo; // título; por defecto "Visita #id"
  final bool showActions;
  final VoidCallback onTap;
  final VoidCallback? onMaps;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const VisitaCard({
    super.key,
    required this.visita,
    required this.estadoLabel,
    required this.onTap,
    this.codigo,
    this.showActions = true,
    this.onMaps,
    this.onCall,
    this.onMessage,
  });

  static String fechaCorta(String raw) {
    if (raw.isEmpty) return '';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    return d == null ? raw : DateFormat('dd/MM/yyyy HH:mm', 'es').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final prio = Prioridad.parse(visita.prioridad);
    final dir = [
      if (visita.direccion.isNotEmpty) visita.direccion,
      if (visita.poblacion.isNotEmpty) visita.poblacion,
    ].join(', ');
    final meta = [
      if (visita.equipoId.isNotEmpty) 'Equipo ${visita.equipoId}',
      if (visita.solicitante.isNotEmpty) 'Solicita ${visita.solicitante}',
      if (visita.fechaSolicitud.isNotEmpty) fechaCorta(visita.fechaSolicitud),
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Prioridad.stroke(prio), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(estadoLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Prioridad.bg(prio),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(prio,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Prioridad.fg(prio))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(codigo ?? 'Visita #${visita.id}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEE8A2D))),
                if (visita.cliente.isNotEmpty)
                  Text(visita.cliente.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark)),
                if (dir.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Dirección: $dir',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF455A64))),
                  ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(meta,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                if (showActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _action('Maps', Icons.map, onMaps)),
                      const SizedBox(width: 8),
                      Expanded(child: _action('Llamar', Icons.call, onCall)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _action('Mensaje', Icons.message, onMessage)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(fontSize: 12),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
