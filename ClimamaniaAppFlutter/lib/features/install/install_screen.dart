import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/status_badge.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Hub del flujo "Realizar instalación". Réplica de InstallActivity.
class InstallScreen extends StatefulWidget {
  final String referencia;
  final String cliente;

  const InstallScreen({super.key, required this.referencia, this.cliente = ''});

  @override
  State<InstallScreen> createState() => _InstallScreenState();
}

class _InstallScreenState extends State<InstallScreen> {
  final _notaCtrl = TextEditingController();
  Fotografias? _fotos;

  @override
  void initState() {
    super.initState();
    _notaCtrl.text =
        context.read<SessionService>().privateNote(widget.referencia);
    _cargarEstadoFotos();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoFotos() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (mounted && res.pedido != null) {
        setState(() => _fotos = res.pedido!.fotografias);
      }
    } catch (_) {}
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _guardarNota() async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al guardar
    await context
        .read<SessionService>()
        .savePrivateNote(widget.referencia, _notaCtrl.text);
    if (mounted) _msg('Comentario guardado en este dispositivo');
  }

  void _abrirFotos(String categoria, String titulo, String clave) {
    context.push('/fotos', extra: {
      'titulo': titulo,
      'referencia': widget.referencia,
      'categoria': categoria,
      'clave': clave,
    });
  }

  Future<void> _anadirComentario() async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir comentario'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe un comentario...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.confirm),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (texto == null || texto.isEmpty || !mounted) return;
    final session = context.read<SessionService>();
    final repo = context.read<PedidoRepository>();
    final (ok, msg) = await repo.addComentario(
          referencia: widget.referencia,
          usuario: session.displayName(fallback: 'Instalador'),
          texto: texto,
        );
    if (mounted) _msg(ok ? 'Comentario guardado' : msg);
  }

  void _firmaConforme() {
    context.push('/conforme', extra: {
      'referencia': widget.referencia,
      'cliente': widget.cliente,
    });
  }

  void _finalizar() {
    // Sin confirmación aquí: lleva al formulario; la confirmación está al final
    // (botón "Finalizar ahora" de la pantalla de finalizar).
    context.push('/finalizar', extra: {'referencia': widget.referencia});
  }

  bool _tieneFotos(String cat) =>
      (_fotos?.byCategoria(cat).isNotEmpty) ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Realizar instalación')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          _notas(),
          const SizedBox(height: AppSpacing.md),
          _seccion(
            'Fotografías y documentación',
            Column(
              children: [
                _fotoRow('Fotos previas', 'previas', 'PREINST'),
                _rowDivider(),
                _fotoRow('Fotos incidencias', 'incidencias', 'DURINST'),
                _rowDivider(),
                _fotoRow('Fotos acabada', 'acabada', 'POSTINST'),
                _rowDivider(),
                _fotoRow('Fotos conforme', 'conforme', 'CONFCLI'),
                _rowDivider(),
                _fotoRow('Documento BOE', 'boe', 'DOCUBOE'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _seccion(
            'Acciones',
            Column(
              children: [
                _accionRow('Añadir comentarios', 'Notas para el pedido',
                    Icons.chat_outlined, AppColors.successFg,
                    AppColors.successTint, _anadirComentario),
                _rowDivider(),
                _accionRow('Firma conforme cliente', 'Recoge la conformidad',
                    Icons.draw_outlined, AppColors.infoFg, AppColors.infoTint,
                    _firmaConforme),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _finalizar,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.confirm,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brPill)),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Finalizar instalación'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final t = Theme.of(context).textTheme;
    final cliente = widget.cliente.isNotEmpty
        ? _titleCase(widget.cliente)
        : 'Pedido ${widget.referencia}';
    return Container(
      decoration: AppDecorations.detailHero,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusBadge('Instalación',
                      tone: BadgeTone.brand, icon: Icons.hvac),
                  const Spacer(),
                  if (widget.referencia.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: AppDecorations.chipLight,
                      child: Text('Nº ${widget.referencia}',
                          style: t.labelMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(cliente,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sube las fotos de cada fase, firma el conforme del cliente y finaliza la instalación.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notas() {
    return _seccion(
      'Comentario privado',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solo se guarda en este dispositivo.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: AppDecorations.editText,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _notaCtrl,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: AppDecorations.bareInput(
                hintText: 'Notas privadas...',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _guardarNota,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.confirm,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brPill)),
              child: const Text('Guardar comentario'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String title, Widget child) {
    return Container(
      width: double.infinity,
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowDivider() => const Divider(height: 1, color: AppColors.border);

  Widget _fotoRow(String label, String categoria, String clave) {
    final tiene = _tieneFotos(categoria);
    return _hubRow(
      label: label,
      subtitle: tiene ? 'Fotos añadidas' : 'Sin fotos aún',
      icon: tiene ? Icons.check_circle : Icons.photo_camera_outlined,
      fg: tiene ? AppColors.successFg : AppColors.primary,
      tint: tiene ? AppColors.successTint : AppColors.footerActiveBg,
      onTap: () => _abrirFotos(categoria, label, clave),
    );
  }

  Widget _accionRow(String label, String subtitle, IconData icon, Color fg,
      Color tint, VoidCallback onTap) {
    return _hubRow(
        label: label,
        subtitle: subtitle,
        icon: icon,
        fg: fg,
        tint: tint,
        onTap: onTap);
  }

  Widget _hubRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color fg,
    required Color tint,
    required VoidCallback onTap,
  }) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: tint, borderRadius: AppRadius.brMd),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
