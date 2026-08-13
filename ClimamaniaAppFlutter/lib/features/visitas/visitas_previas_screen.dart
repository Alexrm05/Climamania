import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/gestion_item.dart';
import '../../theme/app_colors.dart';
import 'widgets/visita_card.dart';

/// Lista de visitas previas del mismo cliente (filtradas por teléfono y
/// dirección en el detalle del pedido). Réplica de VisitasPreviasActivity.
class VisitasPreviasScreen extends StatelessWidget {
  final List<GestionItem> visitas;
  final String referencia;

  const VisitasPreviasScreen({
    super.key,
    required this.visitas,
    this.referencia = '',
  });

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
      appBar: AppBar(title: const Text('Visitas previas')),
      body: visitas.isEmpty
          ? const Center(
              child: Text('No hay visitas previas.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    referencia.isEmpty
                        ? 'Visitas realizadas del mismo cliente'
                        : 'Visitas realizadas del cliente · Pedido $referencia',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                for (final v in visitas)
                  VisitaCard(
                    visita: v,
                    estadoLabel: 'Visita previa',
                    onTap: () => context.push('/visita', extra: {'id': v.id}),
                    onMaps: () => _maps(context, v),
                    onCall: () => _call(context, v),
                    onMessage: () => _message(context, v),
                  ),
              ],
            ),
    );
  }
}
