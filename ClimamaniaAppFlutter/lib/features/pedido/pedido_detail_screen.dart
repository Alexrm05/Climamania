import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/status_badge.dart';
import '../../data/models/gestion_item.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../visitas/widgets/visita_card.dart';
import 'pedido_controller.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Detalle del pedido. Réplica de PedidoDetailActivity + content_pedido_detail.
class PedidoDetailScreen extends StatelessWidget {
  final String referencia;
  final String clienteHint;

  const PedidoDetailScreen({
    super.key,
    required this.referencia,
    this.clienteHint = '',
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PedidoController(
        ctx.read<PedidoRepository>(),
        ctx.read<SearchRepository>(),
        ctx.read<SessionService>(),
        referencia: referencia,
        clienteHint: clienteHint,
      )..init(),
      child: const _PedidoView(),
    );
  }
}

class _PedidoView extends StatefulWidget {
  const _PedidoView();

  @override
  State<_PedidoView> createState() => _PedidoViewState();
}

class _PedidoViewState extends State<_PedidoView> {
  final _comentarioCtrl = TextEditingController();

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _launch(Uri uri, String err) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _msg(err);
      }
    } catch (_) {
      _msg(err);
    }
  }

  Future<void> _openMaps(String dir) async {
    if (dir.trim().isEmpty) {
      _msg('Dirección no disponible');
      return;
    }
    await _launch(
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dir.trim())}'),
      'No se pudo abrir el mapa',
    );
  }

  Future<void> _call(String tel) async {
    if (tel.trim().isEmpty) {
      _msg('Teléfono no disponible');
      return;
    }
    await _launch(Uri.parse('tel:${tel.trim()}'), 'No se pudo iniciar la llamada');
  }

  Future<void> _whatsapp(String tel) async {
    final digits = tel.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _msg('WhatsApp no disponible');
      return;
    }
    await _launch(Uri.parse('https://wa.me/$digits'), 'No se pudo abrir WhatsApp');
  }

  Future<void> _guardarComentario(PedidoController c) async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al enviar
    final (ok, message) = await c.addComentario(_comentarioCtrl.text);
    if (ok) _comentarioCtrl.clear();
    if (mounted) _msg(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      // La barra inferior (Realizar instalación / Volver) queda SIEMPRE fija
      // abajo, sin subir cuando se abre el teclado.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Ficha del pedido')),
      body: Consumer<PedidoController>(
        builder: (context, c, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.pedido == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  c.errorMsg ?? 'No se pudo cargar el pedido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return _content(c);
        },
      ),
      bottomNavigationBar: _bottomActions(),
    );
  }

  Widget _content(PedidoController c) {
    return ListView(
      // Margen inferior extra igual a la altura del teclado, para poder subir
      // el campo de comentario por encima de él (la barra de botones no se mueve).
      padding: EdgeInsets.fromLTRB(
          18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      children: [
        _hero(c),
        _visitasPreviasSection(c),
        if (c.equipoTexto.isNotEmpty)
          _section('Equipo asignado', _bodyText(c.equipoTexto)),
        if (c.detalleLineas.isNotEmpty)
          _section('Detalle del pedido', _detalleTable(c.detalleLineas)),
        if (c.observaciones.isNotEmpty)
          _section('Observaciones del cliente', _bodyText(c.observaciones)),
        _section('Comentarios del instalador', _comentarios(c)),
        _section('Fotografías', _fotos(c)),
      ],
    );
  }

  Widget _hero(PedidoController c) {
    final t = Theme.of(context).textTheme;
    final cliente =
        c.cliente.isNotEmpty ? _titleCase(c.cliente) : 'Pedido ${c.referencia}';
    return Container(
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: badge + Nº
              Row(
                children: [
                  const StatusBadge('Pedido',
                      tone: BadgeTone.brand,
                      icon: Icons.receipt_long_rounded),
                  const Spacer(),
                  if (c.referencia.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: AppDecorations.chipLight,
                      child: Text('Nº ${c.referencia}',
                          style: t.labelMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Identidad: azulejo + cliente + fecha
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.footerActiveBg,
                      borderRadius: AppRadius.brMd,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.hvac,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cliente,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.headlineSmall),
                        if (c.fechaHora.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(Icons.schedule,
                                  size: 15, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(c.fechaHora,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleSmall?.copyWith(
                                        color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                  height: 1, width: double.infinity, color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              // Dirección y teléfono, cada uno en su propia línea.
              _contactRow(
                context,
                Icons.place,
                c.direccion.isNotEmpty
                    ? c.direccion
                    : 'Dirección no disponible',
                available: c.direccion.isNotEmpty,
                maxLines: 3,
              ),
              if (c.telefonoPrincipal.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _contactRow(context, Icons.call, c.telefonoPrincipal,
                    available: true),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                      child: _actionPill(Icons.place, 'Maps',
                          () => _openMaps(c.direccion),
                          primary: true)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: _actionPill(Icons.call, 'Llamar',
                          () => _call(c.telefonoPrincipal),
                          primary: false)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: _actionPill(Icons.chat, 'Mensaje',
                          () => _whatsapp(c.telefonoPrincipal),
                          primary: false)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String text,
      {required bool available, int maxLines = 2}) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.surfaceWarm, borderRadius: AppRadius.brMd),
          child: Center(
              child: Icon(icon, size: 20, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: available
                ? t.titleSmall?.copyWith(color: AppColors.textPrimary)
                : t.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _actionPill(IconData icon, String label, VoidCallback onTap,
      {required bool primary}) {
    final t = Theme.of(context).textTheme;
    final Color fg = primary ? AppColors.white : AppColors.warningFg;
    final content = SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelLarge?.copyWith(color: fg)),
          ),
        ],
      ),
    );
    if (primary) {
      return Material(
        color: AppColors.primary,
        borderRadius: AppRadius.brPill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap, borderRadius: AppRadius.brPill, child: content),
      );
    }
    return Material(
      color: AppColors.footerActiveBg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brPill,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        child: content,
      ),
    );
  }

  /// Sección "Visitas previas": botón para verlas si hay, o aviso si no.
  Widget _visitasPreviasSection(PedidoController c) {
    if (c.visitasPreviasLoading) {
      return _section(
        'Visitas previas',
        Row(children: const [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Buscando visitas previas...',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        ]),
      );
    }
    if (!c.visitasPreviasChecked) return const SizedBox.shrink();
    if (c.visitasPrevias.isEmpty) {
      return _section('Visitas previas', _bodyText('NO HA HABIDO NINGUNA VISITA'));
    }
    // Lista directamente en el detalle (cada visita abre su ficha al tocar).
    return _section(
      'Visitas previas',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < c.visitasPrevias.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _visitaPreviaRow(c.visitasPrevias[i]),
          ],
        ],
      ),
    );
  }

  Widget _visitaPreviaRow(GestionItem v) {
    final fecha = VisitaCard.fechaCorta(
        v.fechaResolucion.isNotEmpty ? v.fechaResolucion : v.fechaSolicitud);
    final dir = [
      if (v.direccion.isNotEmpty) v.direccion,
      if (v.poblacion.isNotEmpty) v.poblacion,
    ].join(', ');
    // Solo información (no navega a "Gestionar visita").
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.history, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visita #${v.id}${fecha.isEmpty ? '' : ' · $fecha'}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark),
                ),
                if (v.cliente.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(v.cliente,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ),
                if (dir.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(dir,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                if (v.telefono.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Tel. ${v.telefono}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                if (v.estado.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Estado: ${v.estado}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        decoration: AppDecorations.whiteCard,
        child: ClipRRect(
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                    builder: (context) => Text(title,
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyText(String text) => Builder(
        builder: (context) => Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.textPrimary, height: 1.4),
        ),
      );

  Widget _detalleTable(List<DetalleLinea> lineas) {
    Widget row(String c1, String c2, String c3, {bool header = false}) {
      final style = TextStyle(
        fontSize: header ? 13 : 14,
        fontWeight: header ? FontWeight.bold : FontWeight.normal,
        color: header ? AppColors.primaryDark : AppColors.textPrimary,
      );
      return Container(
        color: header ? AppColors.primaryLight : null,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: Text(c1, style: style)),
            Expanded(flex: 13, child: Text(c2, style: style)),
            Expanded(flex: 30, child: Text(c3, style: style)),
          ],
        ),
      );
    }

    return Column(
      children: [
        row('CTD', 'Código', 'Descripción', header: true),
        for (final l in lineas) row(l.cantidad, l.referencia, l.nombre),
      ],
    );
  }

  Future<void> _eliminarComentario(
      PedidoController c, ComentarioInstalador com) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text('¿Seguro que quieres eliminar este comentario?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.logoutRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final (ok, msg) = await c.eliminarComentario(com);
    if (mounted) _msg(msg);
  }

  Widget _comentarioItem(PedidoController c, ComentarioInstalador com) {
    final meta = [
      c.fechaComentario(com),
      if (com.usuario.isNotEmpty) com.usuario,
    ].where((e) => e.isNotEmpty).join(' · ');
    final borrando = c.deletingComentarioId == com.id && com.id.isNotEmpty;
    final puedeEliminar = c.puedeEliminar(com);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.isNotEmpty)
                  Text(meta,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                Text(com.texto,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary, height: 1.3)),
              ],
            ),
          ),
          if (borrando)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 4),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (puedeEliminar)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.logoutRed),
              tooltip: 'Eliminar comentario',
              // Los recién añadidos aún no tienen id (se sincroniza en segundos).
              onPressed: com.id.isEmpty
                  ? null
                  : () => _eliminarComentario(c, com),
            ),
        ],
      ),
    );
  }

  Widget _comentarios(PedidoController c) {
    final coments = c.comentarios;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (coments.isNotEmpty) ...[
          for (final com in coments) _comentarioItem(c, com),
          const Divider(height: 20),
        ],
        Container(
          decoration: AppDecorations.editText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _comentarioCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: AppDecorations.bareInput(
              hintText: 'Añadir comentario...',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed:
                c.savingComentario ? null : () => _guardarComentario(c),
            style: AppDecorations.greenButton,
            child: c.savingComentario
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : const Text('Guardar comentario'),
          ),
        ),
      ],
    );
  }

  Widget _fotos(PedidoController c) {
    final n = c.fotosClienteCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cliente',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          n > 0
              ? '$n foto${n == 1 ? '' : 's'} disponible${n == 1 ? '' : 's'}'
              : 'Sin fotos',
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => context.push('/fotos', extra: {
              'titulo': 'Fotos del cliente',
              'referencia': c.referencia,
              // El cliente sube sus fotos como PREINST ("previas").
              'categoria': 'previas',
              'clave': 'PREINST',
            }),
            child: const Text('Ver fotos del cliente'),
          ),
        ),
      ],
    );
  }

  Widget _bottomActions() {
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
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: AppDecorations.redButton.copyWith(
                    padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 22)),
                  ),
                  child: const Text('Volver'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final c = context.read<PedidoController>();
                      context.push('/install', extra: {
                        'referencia': c.referencia,
                        'cliente': c.cliente,
                      });
                    },
                    style: AppDecorations.greenButton,
                    icon: const Icon(Icons.handyman_outlined, size: 20),
                    label: const Text('Realizar instalación'),
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
