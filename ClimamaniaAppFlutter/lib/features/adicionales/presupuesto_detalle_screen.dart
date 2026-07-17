import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/fecha.dart';
import '../../core/format.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/presupuesto_detalle.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

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
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorFg,
                  foregroundColor: AppColors.white),
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
    final t = Theme.of(context).textTheme;
    final cancelado = d.estado.toUpperCase() == 'CANCELADO';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pedido ${d.numeroPedido}',
                        style: t.titleMedium),
                  ),
                  StatusBadge(d.estado,
                      tone: cancelado ? BadgeTone.danger : BadgeTone.success,
                      solid: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (d.cliente.isNotEmpty)
                _info(Icons.person_outline, _titleCase(d.cliente)),
              if (d.direccion.isNotEmpty)
                _info(Icons.place_outlined, d.direccion),
              if (d.telefono.isNotEmpty) _info(Icons.call_outlined, d.telefono),
              if (d.email.isNotEmpty) _info(Icons.mail_outline, d.email),
              if (d.equipo.isNotEmpty)
                _info(Icons.groups_outlined, 'Equipo ${d.equipo}'),
              if (d.usuario.isNotEmpty)
                _info(Icons.badge_outlined, d.usuario),
              if (d.fecha.isNotEmpty)
                _info(Icons.event_outlined, Fecha.parse(d.fecha)),
              _info(
                  d.mailEnviado
                      ? Icons.mark_email_read_outlined
                      : Icons.schedule_send_outlined,
                  d.mailEnviado ? 'Mail enviado' : 'Mail pendiente'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(d.pdfUrl),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.brPill)),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Abrir PDF'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _open(d.firmaUrl),
                      style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.brPill)),
                      icon: const Icon(Icons.draw_outlined, size: 18),
                      label: const Text('Ver firma'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Líneas', style: t.titleMedium),
              const SizedBox(height: AppSpacing.md),
              if (d.lineas.isEmpty)
                Text('Sin líneas.',
                    style:
                        t.bodyMedium?.copyWith(color: AppColors.textMuted))
              else
                for (final l in d.lineas) _lineaItem(l),
              const SizedBox(height: AppSpacing.xs),
              Container(
                  height: 1, width: double.infinity, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              _totalRow('Subtotal (sin IVA)', d.importeSinIva),
              _totalRow('IVA', d.importeIva),
              _totalRow('Total (con IVA)', d.importeConIva, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }

  Widget _lineaItem(DetalleLineaPres l) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text('${l.cantidad} ×',
                style: t.titleSmall?.copyWith(color: AppColors.textPrimary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (l.articulo.isNotEmpty)
                  Text(l.articulo,
                      style:
                          t.titleSmall?.copyWith(color: AppColors.primary)),
                Text(l.descripcion, style: t.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(euros(l.totalConIva),
              style: t.titleSmall?.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value,
                style: t.bodyMedium?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    final style = bold
        ? t.titleMedium
        : t.bodyMedium?.copyWith(color: AppColors.textSecondary);
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              if (puedeCancelar) ...[
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _cancelar,
                      style: AppDecorations.redButton,
                      child: const Text('Cancelar'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: AppDecorations.redButton,
                    child: const Text('Volver'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
