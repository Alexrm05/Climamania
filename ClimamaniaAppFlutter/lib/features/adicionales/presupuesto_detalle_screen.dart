import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../data/models/presupuesto_detalle.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Detalle de un presupuesto. Réplica de PresupuestoInstaladorDetalleActivity.
class PresupuestoDetalleScreen extends StatefulWidget {
  final String id;

  const PresupuestoDetalleScreen({super.key, required this.id});

  @override
  State<PresupuestoDetalleScreen> createState() =>
      _PresupuestoDetalleScreenState();
}

class _PresupuestoDetalleScreenState extends State<PresupuestoDetalleScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  PresupuestoDetalle? _detalle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = context.read<SessionService>();
    final res = await context.read<AdicionalesRepository>().getDetalle(
          widget.id,
          rol: session.rol,
          usuario: session.usuarioForRequests,
          equipo: session.readEquipo(),
        );
    if (!mounted) return;
    setState(() {
      _detalle = res.detalle;
      _error = res.detalle == null
          ? (res.message.isEmpty ? 'No se pudo cargar el presupuesto' : res.message)
          : null;
      _loading = false;
    });
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) {
      _msg('No disponible');
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _msg('No se pudo abrir');
    }
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar presupuesto'),
        content: const Text(
            'El presupuesto pasará a estado cancelado y se notificará por email a los destinatarios internos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar presupuesto')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final session = context.read<SessionService>();
    final (ok, msg) = await context.read<AdicionalesRepository>().cancelar(
          widget.id,
          rol: session.rol,
          usuario: session.usuarioForRequests,
          equipo: session.readEquipo(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    _msg(msg);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detalle;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Presupuesto #${widget.id}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'No se pudo cargar',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : _content(d),
      bottomNavigationBar: d == null ? null : _actions(d),
    );
  }

  Widget _content(PresupuestoDetalle d) {
    final cancelado = d.estado.toUpperCase() == 'CANCELADO';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: AppDecorations.whiteCard,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pedido ${d.numeroPedido}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cancelado
                          ? const Color(0xFF9A3412)
                          : const Color(0xFF345C38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d.estado,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (d.cliente.isNotEmpty) _line('Cliente', d.cliente),
              if (d.direccion.isNotEmpty) _line('Dirección', d.direccion),
              if (d.telefono.isNotEmpty) _line('Teléfono', d.telefono),
              if (d.email.isNotEmpty) _line('Email', d.email),
              if (d.equipo.isNotEmpty) _line('Equipo', d.equipo),
              if (d.usuario.isNotEmpty) _line('Instalador', d.usuario),
              if (d.fecha.isNotEmpty) _line('Fecha', d.fecha),
              _line('Mail', d.mailEnviado ? 'Enviado' : 'Pendiente'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(d.pdfUrl),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Abrir PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(d.firmaUrl),
                      icon: const Icon(Icons.draw, size: 18),
                      label: const Text('Ver firma'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: AppDecorations.whiteCard,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Líneas',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 8),
              if (d.lineas.isEmpty)
                const Text('Sin líneas.',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                for (final l in d.lineas) _lineaItem(l),
              const Divider(height: 20),
              _totalRow('Subtotal (sin IVA)', d.importeSinIva),
              _totalRow('IVA', d.importeIva),
              _totalRow('Total (con IVA)', d.importeConIva, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineaItem(DetalleLineaPres l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('${l.cantidad} ×',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (l.articulo.isNotEmpty)
                  Text(l.articulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEE8A2D),
                          fontSize: 13)),
                Text(l.descripcion, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Text(euros(l.totalConIva),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppColors.primaryDark : const Color(0xFF455A64),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(euros(value), style: style)],
      ),
    );
  }

  Widget _actions(PresupuestoDetalle d) {
    final puedeCancelar = d.canEdit && d.estado.toUpperCase() != 'CANCELADO';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            if (puedeCancelar)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _cancelar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB00020),
                      side: const BorderSide(color: Color(0xFFB00020)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                    ),
                    child: const Text('Cancelar presupuesto'),
                  ),
                ),
              ),
            if (puedeCancelar) const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
