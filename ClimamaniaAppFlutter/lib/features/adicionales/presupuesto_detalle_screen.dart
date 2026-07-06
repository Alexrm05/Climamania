import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/ui_text.dart';
import '../../data/models/catalogo.dart';
import '../../data/models/presupuesto_detalle.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

/// Detalle de un presupuesto. Réplica de PresupuestoInstaladorDetalleActivity.
/// Incluye modo edición completo cuando `can_edit` y estado != CANCELADO.
class PresupuestoDetalleScreen extends StatefulWidget {
  final String id;

  const PresupuestoDetalleScreen({super.key, required this.id});

  @override
  State<PresupuestoDetalleScreen> createState() =>
      _PresupuestoDetalleScreenState();
}

class _PresupuestoDetalleScreenState extends State<PresupuestoDetalleScreen> {
  bool _loading = true;
  bool _busy = false; // cancelando
  bool _saving = false;
  String? _error;
  PresupuestoDetalle? _detalle;

  bool _canEdit = false;
  String _estado = '';
  String _numeroPedido = '';
  String _pdfUrl = '';
  String _firmaUrl = '';

  // Campos de cliente editables.
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Líneas editables.
  int _nextLocalId = 1;
  final List<EditableDetalleLinea> _lineas = [];
  final Map<int, TextEditingController> _descCtrls = {};
  final Map<int, TextEditingController> _qtyCtrls = {};
  final Map<int, String?> _qtyErrors = {};

  // Buscador de catálogo (solo edición).
  final _catalogoCtrl = TextEditingController();
  Timer? _catalogoDebounce;
  bool _buscandoCatalogo = false;
  List<CatalogProduct> _resultadosCatalogo = [];
  String _catalogoMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _catalogoCtrl.dispose();
    _catalogoDebounce?.cancel();
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _idInt => int.tryParse(widget.id.trim()) ?? 0;

  Future<void> _load() async {
    // Valida id vacío/≤0 al entrar (aviso + no peticiona).
    if (_idInt <= 0) {
      setState(() {
        _loading = false;
        _error = 'ID de presupuesto no válido';
      });
      return;
    }
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
      final d = res.detalle;
      if (d != null) {
        _canEdit = d.canEdit;
        _estado = d.estado;
        _numeroPedido = d.numeroPedido;
        _pdfUrl = d.pdfUrl;
        _firmaUrl = d.firmaUrl;
        _nombreCtrl.text = d.cliente;
        _direccionCtrl.text = d.direccion;
        _telefonoCtrl.text = d.telefono;
        _emailCtrl.text = d.email;
        _bindLineas(d.lineas);
      }
    });
    if (_canEdit) _buscarCatalogo('');
  }

  void _bindLineas(List<DetalleLineaPres> lineas) {
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    _descCtrls.clear();
    _qtyCtrls.clear();
    _qtyErrors.clear();
    _lineas.clear();
    _nextLocalId = 1;
    for (final l in lineas) {
      final line = EditableDetalleLinea.fromExisting(_nextLocalId++, l);
      _lineas.add(line);
      _descCtrls[line.localId] = TextEditingController(text: line.descripcion);
      _qtyCtrls[line.localId] =
          TextEditingController(text: _formatQty(line.quantity));
      _qtyErrors[line.localId] = null;
    }
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

  // ---------- Totales ----------

  double get _totalSinIva => _lineas.fold(0, (s, l) => s + l.totalSinIva);
  double get _totalConIva => _lineas.fold(0, (s, l) => s + l.totalConIva);
  double get _totalIva => _totalConIva - _totalSinIva;

  // ---------- Cantidad ----------

  double? _validateQuantity(String raw) {
    final s = UiText.sanitizeDbValue(raw).replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d)?$').hasMatch(s)) return null;
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    var s = q.toStringAsFixed(1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 2);
    return s;
  }

  void _stepQty(EditableDetalleLinea l, bool increment) {
    var next = increment ? l.quantity + 1 : l.quantity - 1;
    if (next < 0.1) next = 0.1;
    next = double.parse(next.toStringAsFixed(1));
    setState(() {
      l.quantity = next;
      _qtyCtrls[l.localId]?.text = _formatQty(next);
      _qtyErrors[l.localId] = null;
    });
  }

  void _onQtyChanged(EditableDetalleLinea l, String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return;
    final v = _validateQuantity(clean);
    setState(() {
      if (v == null) {
        _qtyErrors[l.localId] = 'Cantidad inválida';
      } else {
        _qtyErrors[l.localId] = null;
        l.quantity = v;
      }
    });
  }

  void _removeLinea(EditableDetalleLinea l) {
    setState(() {
      _lineas.remove(l);
      _descCtrls.remove(l.localId)?.dispose();
      _qtyCtrls.remove(l.localId)?.dispose();
      _qtyErrors.remove(l.localId);
    });
  }

  // ---------- Catálogo (edición) ----------

  void _onCatalogoChanged(String q) {
    _catalogoDebounce?.cancel();
    _catalogoDebounce = Timer(const Duration(milliseconds: 300), () {
      _buscarCatalogo(q.trim());
    });
  }

  Future<void> _buscarCatalogo(String q) async {
    setState(() => _buscandoCatalogo = true);
    final res = await context.read<AdicionalesRepository>().getCatalogo(q, limit: 20);
    if (!mounted) return;
    setState(() {
      _resultadosCatalogo = res.productos;
      _catalogoMsg = res.productos.isEmpty
          ? (res.message.isEmpty ? 'Sin resultados para esta búsqueda' : res.message)
          : '';
      _buscandoCatalogo = false;
    });
  }

  void _addOrMerge(CatalogProduct p) {
    final existing =
        _lineas.where((l) => l.catalogProductId == p.idProduct).toList();
    setState(() {
      if (existing.isNotEmpty) {
        final l = existing.first;
        l.quantity = l.quantity + 1;
        _qtyCtrls[l.localId]?.text = _formatQty(l.quantity);
        _qtyErrors[l.localId] = null;
      } else {
        final line = EditableDetalleLinea.fromProduct(_nextLocalId++, p);
        _lineas.add(line);
        _descCtrls[line.localId] =
            TextEditingController(text: line.descripcion);
        _qtyCtrls[line.localId] =
            TextEditingController(text: _formatQty(line.quantity));
        _qtyErrors[line.localId] = null;
      }
    });
    _msg('Artículo añadido');
  }

  // ---------- Guardar cambios ----------

  String _apiDecimal(double v, int scale) =>
      roundHalfUp(v, scale).toStringAsFixed(scale);

  Future<void> _guardarCambios() async {
    if (!_canEdit || _saving) return;
    if (_lineas.isEmpty) {
      _msg('Añade al menos una línea');
      return;
    }
    final lineasJson = <Map<String, dynamic>>[];
    for (var i = 0; i < _lineas.length; i++) {
      final l = _lineas[i];
      var desc = UiText.sanitizeDbValue(_descCtrls[l.localId]?.text ?? '');
      if (desc.isEmpty) desc = 'Sin descripción';
      lineasJson.add({
        'orden': i + 1,
        'cantidad': _apiDecimal(l.quantity, 2),
        'articulo': l.articulo.isEmpty ? 'SIN-CODIGO' : l.articulo,
        'descripcion': desc,
        'precio_unitario_sin_iva': _apiDecimal(l.unitSinIva, 6),
        'precio_total_linea_sin_iva': _apiDecimal(l.totalSinIva, 2),
        'iva_pct': _apiDecimal(l.effectiveIvaPct, 3),
        'precio_total_linea_con_iva': _apiDecimal(l.totalConIva, 2),
        'iva_fallback': l.effectiveIvaFallback,
      });
    }

    setState(() => _saving = true);
    final session = context.read<SessionService>();
    final (ok, msg) =
        await context.read<AdicionalesRepository>().actualizarPresupuesto(
              idPresupuesto: widget.id,
              rol: session.rol,
              usuario: session.usuarioForRequests,
              equipo: session.readEquipo(),
              nombreCliente: UiText.sanitizeDbValue(_nombreCtrl.text),
              direccionCliente: UiText.sanitizeDbValue(_direccionCtrl.text),
              telefono: UiText.sanitizeDbValue(_telefonoCtrl.text),
              emailCliente: UiText.sanitizeDbValue(_emailCtrl.text),
              lineasJson: jsonEncode(lineasJson),
            );
    if (!mounted) return;
    setState(() => _saving = false);
    _msg(msg);
    if (ok) context.pop(true);
  }

  Future<void> _cancelar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Cancelar presupuesto'),
        content: const Text(
            'El presupuesto pasará a estado cancelado y se notificará por email a los destinatarios internos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Volver')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dctx, true),
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
    return DetailScaffold(
      activeIndex: NavBranch.adicionales,
      onReload: _load,
      child: Container(
        color: AppColors.primaryLight,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _detalle == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error ?? 'No se pudo cargar',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : _body(_detalle!),
      ),
    );
  }

  Widget _body(PresupuestoDetalle d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cabecera(d),
        const SizedBox(height: 14),
        if (_canEdit) ...[
          _datosClienteEditable(),
          const SizedBox(height: 14),
          _anadirArticulo(),
          const SizedBox(height: 14),
        ],
        _lineasCard(),
        const SizedBox(height: 14),
        _acciones(),
      ],
    );
  }

  Widget _cabecera(PresupuestoDetalle d) {
    final cancelado = _estado.toUpperCase() == 'CANCELADO';
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    'Presupuesto #${widget.id} · Pedido ${_numeroPedido.isEmpty ? '-' : _numeroPedido}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cancelado
                      ? const Color(0xFF9A3412)
                      : const Color(0xFF345C38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_estado.isEmpty ? 'N/D' : _estado,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_canEdit) ...[
            if (d.cliente.isNotEmpty) _line('Cliente', d.cliente),
            if (d.direccion.isNotEmpty) _line('Dirección', d.direccion),
            if (d.telefono.isNotEmpty) _line('Teléfono', d.telefono),
            if (d.email.isNotEmpty) _line('Email', d.email),
          ],
          if (d.equipo.isNotEmpty) _line('Equipo', d.equipo),
          if (d.usuario.isNotEmpty) _line('Instalador', d.usuario),
          if (d.fecha.isNotEmpty) _line('Fecha', d.fecha),
          _line('Mail', d.mailEnviado ? 'Enviado' : 'Pendiente'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(_pdfUrl),
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Abrir PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(_firmaUrl),
                  icon: const Icon(Icons.draw, size: 18),
                  label: const Text('Ver firma'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datosClienteEditable() {
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos del cliente',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 10),
          _field('Nombre del cliente', _nombreCtrl),
          const SizedBox(height: 8),
          _field('Dirección', _direccionCtrl, lines: 2),
          const SizedBox(height: 8),
          _field('Teléfono', _telefonoCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 8),
          _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _anadirArticulo() {
    return Container(
      decoration: AppDecorations.whiteCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Añadir artículo',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 10),
          _field('Buscar artículo (código o descripción)', _catalogoCtrl,
              onChanged: _onCatalogoChanged),
          if (_buscandoCatalogo)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_resultadosCatalogo.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _catalogoMsg.isEmpty
                    ? 'Sin resultados para esta búsqueda'
                    : _catalogoMsg,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final p in _resultadosCatalogo) _resultadoCatalogo(p),
        ],
      ),
    );
  }

  Widget _resultadoCatalogo(CatalogProduct p) {
    var meta = 'IVA ${formatPercent(p.ivaPct)}';
    if (p.ivaFallback) meta += ' (estimado)';
    meta += ' · Tocar para añadir';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _addOrMerge(p),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardStroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.codigo.isEmpty ? 'SIN CÓDIGO' : p.codigo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEE8A2D))),
                    Text(p.descripcion, style: const TextStyle(fontSize: 13)),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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

  Widget _lineasCard() {
    return Container(
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
          if (_lineas.isEmpty)
            const Text('Sin líneas.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            for (final l in _lineas)
              _canEdit ? _lineaEditable(l) : _lineaReadOnly(l),
          const Divider(height: 20),
          _totalRow('Subtotal (sin IVA)', _totalSinIva),
          _totalRow('IVA', _totalIva),
          _totalRow('Total (con IVA)', _totalConIva, bold: true),
        ],
      ),
    );
  }

  Widget _lineaReadOnly(EditableDetalleLinea l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text('${_formatQty(l.quantity)} ×',
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

  Widget _lineaEditable(EditableDetalleLinea l) {
    final err = _qtyErrors[l.localId];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.articulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFEE8A2D))),
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
                onPressed: () => _removeLinea(l),
              ),
            ],
          ),
          TextField(
            controller: _descCtrls[l.localId],
            minLines: 1,
            maxLines: 3,
            onChanged: (v) => l.descripcion = v,
            decoration: const InputDecoration(
                labelText: 'Descripción', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _qtyBtn(Icons.remove, () => _stepQty(l, false)),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _qtyCtrls[l.localId],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textAlign: TextAlign.center,
                  onChanged: (v) => _onQtyChanged(l, v),
                  decoration: InputDecoration(
                    isDense: true,
                    errorText: err,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _qtyBtn(Icons.add, () => _stepQty(l, true)),
              const Spacer(),
              Text(euros(l.totalConIva),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
            ],
          ),
          Text(
              'P. unit: ${euros(l.unitConIva)} (IVA incl.) · IVA ${formatPercent(l.effectiveIvaPct)}${l.effectiveIvaFallback ? ' (estimado)' : ''}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardStroke),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryDark),
      ),
    );
  }

  Widget _acciones() {
    final puedeCancelar = _estado.toUpperCase() != 'CANCELADO';
    return Column(
      children: [
        if (_canEdit)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _guardarCambios,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white))
                  : const Text('Guardar cambios'),
            ),
          ),
        if (_canEdit) const SizedBox(height: 10),
        Row(
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
      ],
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
        decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }
}
