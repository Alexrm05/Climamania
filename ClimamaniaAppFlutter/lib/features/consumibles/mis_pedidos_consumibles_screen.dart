import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/consumible_tarifa.dart';
import '../../data/repositories/consumibles_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Pedidos de consumibles que ya ha enviado el instalador.
///
/// Solo consulta: una vez enviado, el pedido no se modifica desde la app; si
/// hay que cambiar algo, se habla con la oficina indicando la referencia.
class MisPedidosConsumiblesScreen extends StatefulWidget {
  const MisPedidosConsumiblesScreen({super.key});

  @override
  State<MisPedidosConsumiblesScreen> createState() =>
      _MisPedidosConsumiblesScreenState();
}

class _MisPedidosConsumiblesScreenState
    extends State<MisPedidosConsumiblesScreen> {
  static final _fecha = DateFormat('dd/MM/yyyy HH:mm');

  List<PedidoEnviado> _pedidos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final session = context.read<SessionService>();
    final r = await context.read<ConsumiblesRepository>().getMisPedidos(
          usuario: session.usuarioForRequests,
          rol: session.rol,
        );
    if (!mounted) return;
    setState(() {
      _pedidos = r;
      _cargando = false;
    });
  }

  String _fechaCorta(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _fecha.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_pedidos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        'Todavía no has pedido consumibles.',
                        textAlign: TextAlign.center,
                        style:
                            t.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                    )
                  else ...[
                    for (final p in _pedidos) _pedidoCard(t, p),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Los pedidos enviados no se pueden modificar desde la '
                      'app. Si necesitas cambiar algo, avisa a la oficina con '
                      'la referencia del pedido.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _pedidoCard(TextTheme t, PedidoEnviado p) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppDecorations.whiteCard,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Sin las líneas divisorias que ExpansionTile pinta por defecto.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          title: Row(
            children: [
              Expanded(
                child: Text(p.referencia,
                    style: t.titleSmall?.copyWith(color: AppColors.primary)),
              ),
              _estado(t, p),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${_fechaCorta(p.fecha)} · ${p.numLineas} '
              'artículo${p.numLineas == 1 ? '' : 's'} · '
              '${formatoEuros(p.totalSinIva)} sin IVA',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.avisoCorreo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'El pedido quedó registrado, pero algún correo no '
                        'llegó a salir. Confírmalo con la oficina.',
                        style:
                            t.bodySmall?.copyWith(color: AppColors.errorFg),
                      ),
                    ),
                  for (final l in p.lineas) _lineaFila(t, l),
                  if (p.observaciones.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Observaciones', style: t.titleSmall),
                    Text(p.observaciones, style: t.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estado(TextTheme t, PedidoEnviado p) {
    final solicitado = p.estado.toUpperCase() == 'SOLICITADO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: solicitado ? AppColors.infoTint : AppColors.successTint,
          borderRadius: AppRadius.brSm),
      child: Text(
        p.estado.isEmpty ? 'SOLICITADO' : p.estado,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: solicitado ? AppColors.infoFg : AppColors.successFg),
      ),
    );
  }

  Widget _lineaFila(TextTheme t, LineaPedidoEnviado l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.codigo,
              style: t.bodySmall?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          Text(l.descripcion, style: t.bodySmall),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatoUnidades(l.cantidadFormatos)} × '
                  '${l.textoFormato.isEmpty ? 'formato' : l.textoFormato}'
                  ' · ${formatoUnidades(l.cantidadUnidades)} ${l.unidadVenta}',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(formatoEuros(l.importeLinea),
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
