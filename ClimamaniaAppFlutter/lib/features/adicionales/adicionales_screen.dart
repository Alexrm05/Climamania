import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../core/fecha.dart';
import '../../core/format.dart';
import '../../data/models/catalogo.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Pantalla de la pestaña "Adicionales": crear presupuesto y buscar presupuestos.
/// Réplica de AdicionalesPresupuestoActivity. Se muestra dentro del shell.
class AdicionalesScreen extends StatefulWidget {
  const AdicionalesScreen({super.key});

  @override
  State<AdicionalesScreen> createState() => _AdicionalesScreenState();
}

class _AdicionalesScreenState extends State<AdicionalesScreen> {
  int _tab = 0; // 0 = Nuevo, 1 = Buscar

  // --- Nuevo ---
  final _refCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _catalogoCtrl = TextEditingController();
  Timer? _catalogoDebounce;
  bool _buscandoCatalogo = false;
  List<CatalogProduct> _resultadosCatalogo = [];
  List<CatalogProduct> _masUsados = [];
  final List<BudgetLine> _lineas = [];
  final Map<int, TextEditingController> _descCtrls = {};
  late final SignatureController _sig;
  bool _guardando = false;

  // --- Buscar ---
  final _buscarCtrl = TextEditingController();
  Timer? _buscarDebounce;
  bool _buscando = false;
  String _estado = 'TODOS';
  List<String> _estados = ['TODOS'];
  List<PresupuestoResumen> _presupuestos = [];

  bool _cargandoRef = false;

  AdicionalesRepository get _repo => context.read<AdicionalesRepository>();
  SessionService get _session => context.read<SessionService>();

  /// Carga los datos del cliente a partir del número de pedido/referencia.
  Future<void> _cargarReferencia() async {
    FocusScope.of(context).unfocus();
    final ref = _refCtrl.text.trim();
    if (ref.isEmpty) {
      _msg('Escribe el número de pedido');
      return;
    }
    setState(() => _cargandoRef = true);
    final res = await context.read<PedidoRepository>().getPedido(ref);
    if (!mounted) return;
    setState(() => _cargandoRef = false);
    final p = res.pedido;
    if (p == null) {
      _msg('No se encontró el pedido $ref');
      return;
    }
    final tel = [
      p.entrega?.telefono ?? '',
      p.facturacion?.telefono ?? '',
    ].map((e) => e.trim()).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    setState(() {
      if (p.cliente.isNotEmpty) _nombreCtrl.text = p.cliente;
      if (p.emailCliente.isNotEmpty) _emailCtrl.text = p.emailCliente;
      if (tel.isNotEmpty) _telefonoCtrl.text = tel;
    });
    _msg('Datos cargados del pedido $ref');
  }

  @override
  void initState() {
    super.initState();
    _sig = SignatureController(
      penStrokeWidth: 2.4,
      penColor: AppColors.primary,
      exportBackgroundColor: Colors.white,
    );
    // Dev: abrir directamente la pestaña Buscar.
    if (const String.fromEnvironment('START_TAB') == 'buscar') {
      _tab = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _buscar();
      });
    }
    _cargarMasUsados();
  }

  Future<void> _cargarMasUsados() async {
    final res = await _repo.getMasUsados();
    if (mounted) setState(() => _masUsados = res);
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _catalogoCtrl.dispose();
    _buscarCtrl.dispose();
    _catalogoDebounce?.cancel();
    _buscarDebounce?.cancel();
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    _sig.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- Catálogo / líneas ----------

  void _onCatalogoChanged(String q) {
    _catalogoDebounce?.cancel();
    _catalogoDebounce = Timer(const Duration(milliseconds: 300), () {
      _buscarCatalogo(q.trim());
    });
  }

  Future<void> _buscarCatalogo(String q) async {
    if (q.isEmpty) {
      setState(() => _resultadosCatalogo = []);
      return;
    }
    setState(() => _buscandoCatalogo = true);
    final res = await _repo.getCatalogo(q);
    if (!mounted) return;
    setState(() {
      _resultadosCatalogo = res;
      _buscandoCatalogo = false;
    });
  }

  void _addLine(CatalogProduct p) {
    final existing = _lineas.where((l) => l.product.idProduct == p.idProduct);
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.quantity += 1;
      } else {
        final line = BudgetLine(product: p);
        _lineas.add(line);
        _descCtrls[p.idProduct] =
            TextEditingController(text: line.descripcion);
      }
    });
  }

  void _removeLine(BudgetLine l) {
    setState(() {
      _lineas.remove(l);
      _descCtrls.remove(l.product.idProduct)?.dispose();
    });
  }

  void _changeQty(BudgetLine l, double delta) {
    setState(() {
      final q = (l.quantity + delta);
      l.quantity = q < 0.1 ? 0.1 : double.parse(q.toStringAsFixed(1));
    });
  }

  double get _totalSinIva =>
      _lineas.fold(0, (s, l) => s + l.pricing.totalSinIva);
  double get _totalConIva =>
      _lineas.fold(0, (s, l) => s + l.pricing.totalConIva);
  double get _totalIva => _totalConIva - _totalSinIva;

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al guardar
    if (_lineas.isEmpty) {
      _msg('Añade al menos una línea al presupuesto');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _msg('Indica un email de cliente válido');
      return;
    }
    if (_sig.isEmpty) {
      _msg('Falta la firma del cliente');
      return;
    }
    final locationService = context.read<LocationService>();
    final session = _session;
    setState(() => _guardando = true);
    try {
      final pngBytes = await _sig.toPngBytes();
      if (pngBytes == null) {
        _msg('No se pudo procesar la firma');
        return;
      }
      final loc = await locationService.capture();
      final ref = _refCtrl.text.trim();
      final lineasJson = <Map<String, dynamic>>[];
      for (var i = 0; i < _lineas.length; i++) {
        final l = _lineas[i];
        final pr = l.pricing;
        lineasJson.add({
          'orden': i + 1,
          'cantidad': l.quantity.toStringAsFixed(2),
          'articulo': l.product.codigo,
          'descripcion': _descCtrls[l.product.idProduct]?.text ?? l.descripcion,
          'precio_unitario_sin_iva': pr.unitSinIva.toStringAsFixed(6),
          'precio_total_linea_sin_iva': pr.totalSinIva.toStringAsFixed(2),
          'iva_pct': pr.ivaPct.toStringAsFixed(3),
          'precio_total_linea_con_iva': pr.totalConIva.toStringAsFixed(2),
          'iva_fallback': pr.ivaFallback,
        });
      }
      final res = await _repo.guardar({
        'referencia': ref,
        'numero_pedido': ref.isNotEmpty ? ref : 'MANUAL',
        'nombre_cliente': _nombreCtrl.text.trim(),
        'direccion_cliente': '',
        'telefono': _telefonoCtrl.text.trim(),
        'email_cliente': email,
        'usuario_instalador': session.displayName(fallback: 'Instalador'),
        'equipo_instaladores': session.readEquipo(),
        'total_sin_iva': _totalSinIva.toStringAsFixed(2),
        'total_iva': _totalIva.toStringAsFixed(2),
        'total_con_iva': _totalConIva.toStringAsFixed(2),
        'firma_base64': base64Encode(pngBytes),
        'lineas_json': jsonEncode(lineasJson),
        'latitud': loc.latParam,
        'longitud': loc.lngParam,
      });
      if (!mounted) return;
      _msg(res.ok ? 'Presupuesto guardado' : (res.message.isEmpty ? 'No se pudo guardar' : res.message));
      if (res.ok) _resetNuevo();
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo guardar el presupuesto');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _resetNuevo() {
    setState(() {
      _lineas.clear();
      for (final c in _descCtrls.values) {
        c.dispose();
      }
      _descCtrls.clear();
      _resultadosCatalogo = [];
      _catalogoCtrl.clear();
      _sig.clear();
    });
  }

  // ---------- Buscar ----------

  void _onBuscarChanged(String q) {
    _buscarDebounce?.cancel();
    _buscarDebounce = Timer(const Duration(milliseconds: 300), _buscar);
  }

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    final res = await _repo.getPresupuestos(
      rol: _session.rol,
      usuario: _session.usuarioForRequests,
      equipo: _session.readEquipo(),
      q: _buscarCtrl.text.trim(),
      estado: _estado,
    );
    if (!mounted) return;
    setState(() {
      _presupuestos = res.items;
      if (res.estados.isNotEmpty) {
        _estados = ['TODOS', ...res.estados.where((e) => e != 'TODOS')];
      }
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: Column(
        children: [
          _tabs(),
          Expanded(child: _tab == 0 ? _nuevo() : _buscarTab()),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: AppRadius.brPill,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(child: _seg('Nuevo presupuesto', 0)),
            Expanded(child: _seg('Buscar', 1)),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, int index) {
    final active = _tab == index;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        setState(() => _tab = index);
        if (index == 1 && _presupuestos.isEmpty) _buscar();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.brPill,
          boxShadow: active ? AppShadows.card : null,
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.labelLarge?.copyWith(
                color: active ? AppColors.white : AppColors.textSecondary)),
      ),
    );
  }

  // ---------- Nuevo tab ----------

  Widget _nuevo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        _card('Datos del cliente', Column(
          children: [
            _field('Referencia / pedido (opcional)', _refCtrl),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _cargandoRef ? null : _cargarReferencia,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.infoFg),
                icon: _cargandoRef
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : const Icon(Icons.search),
                label: const Text('Cargar datos del pedido'),
              ),
            ),
            const SizedBox(height: 8),
            _field('Nombre del cliente', _nombreCtrl),
            const SizedBox(height: 8),
            _field('Email del cliente', _emailCtrl,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 8),
            _field('Teléfono', _telefonoCtrl, keyboard: TextInputType.phone),
          ],
        )),
        _card('Catálogo', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Buscar artículo (código o descripción)', _catalogoCtrl,
                onChanged: _onCatalogoChanged),
            if (_buscandoCatalogo)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final p in _resultadosCatalogo) _resultadoCatalogo(p),
            // Sin búsqueda activa: acceso rápido a los 5 más usados.
            if (!_buscandoCatalogo &&
                _catalogoCtrl.text.trim().isEmpty &&
                _resultadosCatalogo.isEmpty &&
                _masUsados.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 2),
                child: Text('Más usados',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ),
              for (final p in _masUsados) _resultadoCatalogo(p),
            ],
          ],
        )),
        if (_lineas.isNotEmpty)
          _card('Líneas del presupuesto', Column(
            children: [for (final l in _lineas) _lineaWidget(l)],
          )),
        _card('Totales', Column(
          children: [
            _totalRow('Subtotal (sin IVA)', _totalSinIva),
            _totalRow('IVA', _totalIva),
            _totalRow('Total (con IVA)', _totalConIva, bold: true),
          ],
        )),
        _card('Firma del cliente', Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.brMd,
              ),
              clipBehavior: Clip.antiAlias,
              child: Signature(controller: _sig, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _sig.clear()),
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar firma'),
              ),
            ),
          ],
        )),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.confirm),
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : const Text('Aceptar y guardar presupuesto'),
          ),
        ),
      ],
    );
  }

  Widget _resultadoCatalogo(CatalogProduct p) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _addLine(p),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.codigo.isEmpty ? 'SIN CÓDIGO' : p.codigo,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppColors.primary)),
                    Text(p.descripcion,
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                        'IVA ${p.ivaPct.toStringAsFixed(0)}%${p.ivaFallback ? ' (estimado)' : ''} · Tocar para añadir',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineaWidget(BudgetLine l) {
    final pr = l.pricing;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    l.product.codigo.isEmpty ? 'SIN CÓDIGO' : l.product.codigo,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.primary)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.errorFg),
                onPressed: () => _removeLine(l),
              ),
            ],
          ),
          TextField(
            controller: _descCtrls[l.product.idProduct],
            minLines: 1,
            maxLines: 3,
            onChanged: (v) => l.descripcion = v,
            decoration: const InputDecoration(
                labelText: 'Descripción', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _qtyBtn(Icons.remove, () => _changeQty(l, -1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l.quantity.toStringAsFixed(l.quantity % 1 == 0 ? 0 : 1),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _qtyBtn(Icons.add, () => _changeQty(l, 1)),
              const Spacer(),
              Text(euros(pr.totalConIva),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
            ],
          ),
          Text(
              'P. unit: ${euros(pr.unitConIva)} (IVA incl.) · IVA ${pr.ivaPct.toStringAsFixed(0)}%${pr.ivaFallback ? ' (estimado)' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brSm,
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppColors.primaryDark : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(euros(value), style: style)],
      ),
    );
  }

  // ---------- Buscar tab ----------

  Widget _buscarTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _field('Buscar por cliente, pedido o id', _buscarCtrl,
              onChanged: _onBuscarChanged),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final e in _estados)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e),
                    selected: _estado == e,
                    onSelected: (_) {
                      setState(() => _estado = e);
                      _buscar();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _buscando
              ? const Center(child: CircularProgressIndicator())
              : _presupuestos.isEmpty
                  ? const EmptyState(
                      icon: Icons.request_quote_outlined,
                      title: 'Sin presupuestos',
                      subtitle:
                          'No hay presupuestos para esta búsqueda o filtro.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      children: [
                        for (final p in _presupuestos) _presupuestoItem(p)
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _presupuestoItem(PresupuestoResumen p) {
    final cancelado = p.estado.toUpperCase() == 'CANCELADO';
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        decoration: AppDecorations.whiteCard,
        child: ClipRRect(
          borderRadius: AppRadius.brLg,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/presupuesto', extra: {'id': p.id}),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('#${p.id} · Pedido ${p.numeroPedido}',
                              style: t.labelMedium
                                  ?.copyWith(color: AppColors.textMuted)),
                        ),
                        StatusBadge(p.estado,
                            tone: cancelado
                                ? BadgeTone.danger
                                : BadgeTone.success,
                            solid: true),
                      ],
                    ),
                    if (p.cliente.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(_titleCase(p.cliente), style: t.titleSmall),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                        [
                          if (p.telefono.isNotEmpty) p.telefono,
                          if (p.equipo.isNotEmpty) 'Equipo ${p.equipo}',
                          if (p.usuario.isNotEmpty) p.usuario,
                          if (p.fecha.isNotEmpty) Fecha.parse(p.fecha),
                        ].join(' · '),
                        style: t.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text('Total ${euros(p.importeConIva)}',
                            style: t.titleSmall
                                ?.copyWith(color: AppColors.primaryDark)),
                        const Spacer(),
                        Icon(
                            p.mailEnviado
                                ? Icons.mark_email_read_outlined
                                : Icons.schedule_send_outlined,
                            size: 15,
                            color: p.mailEnviado
                                ? AppColors.successFg
                                : AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(p.mailEnviado ? 'Mail OK' : 'Mail pendiente',
                            style: t.labelMedium?.copyWith(
                                color: p.mailEnviado
                                    ? AppColors.successFg
                                    : AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- helpers ----------

  Widget _card(String title, Widget child) {
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard,
      int lines = 1,
      ValueChanged<String>? onChanged}) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 1,
        onChanged: onChanged,
        decoration: AppDecorations.bareInput(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }
}
