import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/consumible_tarifa.dart';
import '../../data/repositories/consumibles_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Tarifa de consumibles: la misma que el PDF de ClimaGEST, consultable desde
/// el móvil. Solo lectura; los precios se piden al servidor cada vez que se
/// abre porque cambian.
///
/// Desde aquí se añaden artículos al pedido, que se envía en
/// [PedidoConsumiblesScreen].
class TarifaConsumiblesScreen extends StatefulWidget {
  const TarifaConsumiblesScreen({super.key});

  @override
  State<TarifaConsumiblesScreen> createState() =>
      _TarifaConsumiblesScreenState();
}

enum _Orden { codigo, nombre }

class _TarifaConsumiblesScreenState extends State<TarifaConsumiblesScreen> {
  final _buscarCtrl = TextEditingController();
  final List<LineaPedidoConsumible> _carrito = [];

  List<ConsumibleTarifa> _articulos = [];
  bool _cargando = true;
  _Orden _orden = _Orden.codigo;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final r = await context.read<ConsumiblesRepository>().getTarifa();
    if (!mounted) return;
    setState(() {
      _articulos = r;
      _cargando = false;
    });
  }

  List<ConsumibleTarifa> get _visibles {
    final f = _filtro.trim().toLowerCase();
    final lista = f.isEmpty
        ? [..._articulos]
        : _articulos.where((a) => a.textoBusqueda.contains(f)).toList();
    lista.sort((a, b) => _orden == _Orden.codigo
        ? a.codigo.compareTo(b.codigo)
        : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return lista;
  }

  int get _unidadesEnCarrito =>
      _carrito.fold(0, (a, l) => a + l.cantidadFormatos);

  void _pedir(ConsumibleTarifa a) {
    setState(() {
      final existente = _carrito.where((l) => l.articulo.id == a.id).firstOrNull;
      if (existente != null) {
        existente.cantidadFormatos += 1;
      } else {
        _carrito.add(LineaPedidoConsumible(articulo: a));
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${a.codigo} añadido al pedido'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(label: 'Ver pedido', onPressed: _abrirPedido),
      ));
  }

  Future<void> _abrirPedido() async {
    if (_carrito.isEmpty) return;
    final enviado =
        await context.push<bool>('/pedido-consumibles', extra: _carrito);
    if (!mounted) return;
    // Si se envió, el carrito se vacía; si no, vuelve como estaba.
    if (enviado == true) setState(_carrito.clear);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lista = _visibles;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(
        title: const Text('Tarifa de consumibles'),
        actions: [
          PopupMenuButton<_Orden>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _orden,
            onSelected: (v) => setState(() => _orden = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Orden.codigo, child: Text('Por código')),
              PopupMenuItem(value: _Orden.nombre, child: Text('Por nombre')),
            ],
          ),
        ],
      ),
      floatingActionButton: _carrito.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrirPedido,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text('Pedido · $_unidadesEnCarrito'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Container(
              decoration: AppDecorations.editText,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _buscarCtrl,
                onChanged: (v) => setState(() => _filtro = v),
                decoration: AppDecorations.bareInput(
                  hintText: 'Buscar por código o descripción',
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: lista.isEmpty
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _articulos.isEmpty
                                    ? 'No se pudo cargar la tarifa. Desliza para reintentar.'
                                    : 'Ningún artículo coincide con la búsqueda.',
                                textAlign: TextAlign.center,
                                style: t.bodyMedium
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg, 0, AppSpacing.lg, 96),
                            itemCount: lista.length + 1,
                            itemBuilder: (_, i) => i == lista.length
                                ? _pie(t)
                                : _articuloCard(t, lista[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pie(TextTheme t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Precios sin IVA. Los artículos con formato (rollo, tira, caja…) '
          'se venden por formato completo.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      );

  Widget _articuloCard(TextTheme t, ConsumibleTarifa a) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.whiteCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _foto(a),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.codigo,
                    style: t.titleSmall?.copyWith(color: AppColors.primary)),
                Text(a.descripcion, style: t.bodyMedium),
                if (a.textoFormato.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Se vende en: ${a.textoFormato}',
                        style:
                            t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatoEuros(a.precioFormato),
                              style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark)),
                          if (a.muestraPrecioUnidad)
                            Text(
                              '(${formatoEuros(a.precioUnidad, decimales: a.precioUnidad < 1 ? 4 : 2)}'
                              '/${a.unidadVenta})',
                              style: t.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pedir(a),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.brMd)),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Pedir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La foto se puede cachear: si cambia, cambia la URL (lleva ?v=).
  Widget _foto(ConsumibleTarifa a) {
    const lado = 64.0;
    final marco = BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: AppRadius.brMd,
      border: Border.all(color: AppColors.border),
    );
    if (a.fotoUrl.isEmpty) {
      return Container(
        width: lado,
        height: lado,
        decoration: marco,
        child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
      );
    }
    return Container(
      width: lado,
      height: lado,
      decoration: marco,
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        a.fotoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined,
            color: AppColors.textMuted),
      ),
    );
  }
}
