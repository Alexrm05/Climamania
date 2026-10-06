import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/consumible_tarifa.dart';
import '../../data/repositories/consumibles_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Pedido de consumibles: carrito, observaciones y envío.
///
/// El pedido solo se registra y se avisa por correo; no entra en PrestaShop,
/// GOTEL ni ClimaGEST. Los precios que se ven aquí son orientativos: al
/// enviar, el servidor los vuelve a leer de la tarifa.
///
/// Devuelve `true` si el pedido se envió, para que la tarifa vacíe el carrito.
class PedidoConsumiblesScreen extends StatefulWidget {
  final List<LineaPedidoConsumible> lineas;

  const PedidoConsumiblesScreen({super.key, required this.lineas});

  @override
  State<PedidoConsumiblesScreen> createState() =>
      _PedidoConsumiblesScreenState();
}

class _PedidoConsumiblesScreenState extends State<PedidoConsumiblesScreen> {
  final _obsCtrl = TextEditingController();
  late final TextEditingController _emailCtrl;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl =
        TextEditingController(text: context.read<SessionService>().email);
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  double get _total =>
      widget.lineas.fold(0.0, (a, l) => a + l.importe);

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _cambiarCantidad(LineaPedidoConsumible l) async {
    final ctrl =
        TextEditingController(text: l.cantidadFormatos.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad · ${l.articulo.codigo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se pide por formato completo: ${l.articulo.textoFormato}',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  suffixText: 'formatos', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v == null || !mounted) return;
    setState(() => l.cantidadFormatos = v < 1 ? 1 : v);
  }

  void _quitar(LineaPedidoConsumible l) {
    setState(() => widget.lineas.remove(l));
    if (widget.lineas.isEmpty) context.pop(false);
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (widget.lineas.isEmpty) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _msg('Indica un email válido para la confirmación');
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar pedido'),
        content: Text(
          'Se enviarán ${widget.lineas.length} '
          'artículo${widget.lineas.length == 1 ? '' : 's'} por un total '
          'estimado de ${formatoEuros(_total)} sin IVA.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _enviando = true);
    final session = context.read<SessionService>();
    try {
      final res = await context.read<ConsumiblesRepository>().pedir(
            usuario: session.usuarioForRequests,
            equipo: session.readEquipo(),
            email: email,
            observaciones: _obsCtrl.text.trim(),
            lineas: widget.lineas,
          );
      if (!mounted) return;
      if (!res.ok) {
        _msg(res.message.isEmpty ? 'No se pudo enviar el pedido' : res.message);
        return;
      }
      await _pantallaFinal(res);
      if (mounted) context.pop(true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _pantallaFinal(ResultadoPedidoConsumibles res) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(res.conAvisoCorreo ? Icons.warning_amber : Icons.check_circle,
            color: res.conAvisoCorreo ? AppColors.errorFg : AppColors.successFg,
            size: 40),
        title: Text('Pedido ${res.referencia} enviado'),
        content: Text(
          res.conAvisoCorreo
              ? 'El pedido ha quedado registrado, pero no se pudo enviar el '
                  'correo. Avisa a la oficina indicando la referencia.'
              : 'Tu pedido de consumibles se ha solicitado correctamente y se '
                  'tramitará en breve.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Pedido de consumibles')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.brMd)),
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando…' : 'Enviar pedido'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final l in widget.lineas) _lineaCard(t, l),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: AppDecorations.whiteCard,
            child: Row(
              children: [
                Expanded(
                    child: Text('Total estimado sin IVA',
                        style: t.titleSmall)),
                Text(formatoEuros(_total),
                    style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _campo(t, 'Observaciones', _obsCtrl,
              hint: 'Opcional: algo que deba saber la oficina', lineas: 3),
          const SizedBox(height: AppSpacing.md),
          _campo(t, 'Email de confirmación', _emailCtrl,
              hint: 'tucorreo@climamania.com',
              teclado: TextInputType.emailAddress),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Precios orientativos sin IVA: al enviar se aplican los de la '
            'tarifa en ese momento.',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _campo(TextTheme t, String titulo, TextEditingController ctrl,
      {String hint = '', int lineas = 1, TextInputType? teclado}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: t.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: AppDecorations.editText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: ctrl,
            minLines: lineas,
            maxLines: lineas,
            keyboardType: teclado,
            decoration: AppDecorations.bareInput(
                hintText: hint,
                contentPadding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
      ],
    );
  }

  Widget _lineaCard(TextTheme t, LineaPedidoConsumible l) {
    final a = l.articulo;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.whiteCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.codigo,
                    style: t.titleSmall?.copyWith(color: AppColors.primary)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.errorFg),
                tooltip: 'Quitar del pedido',
                onPressed: () => _quitar(l),
              ),
            ],
          ),
          Text(a.descripcion, style: t.bodyMedium),
          if (a.textoFormato.isNotEmpty)
            Text(a.textoFormato,
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _botonCantidad(Icons.remove, () {
                if (l.cantidadFormatos > 1) {
                  setState(() => l.cantidadFormatos -= 1);
                }
              }),
              InkWell(
                onTap: () => _cambiarCantidad(l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: Text('${l.cantidadFormatos}',
                      style: t.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              _botonCantidad(
                  Icons.add, () => setState(() => l.cantidadFormatos += 1)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${formatoUnidades(l.unidades)} ${a.unidadVenta}',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(formatoEuros(l.importe),
                  style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback onTap) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.brSm,
            side: const BorderSide(color: AppColors.borderStrong)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icono, size: 20, color: AppColors.primary),
          ),
        ),
      );
}
