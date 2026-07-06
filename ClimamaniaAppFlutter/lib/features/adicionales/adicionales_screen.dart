import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

import '../../core/format.dart';
import '../../core/ui_text.dart';
import '../../data/models/catalogo.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Clave EXACTA de las estadísticas de uso (misma que Android).
const String _prefsUsageKey = 'adicionales_usage_stats';
const int _maxRecommended = 3;

/// Estadística de uso de un producto.
class _ProductUsage {
  int count;
  int lastUsedMs;
  _ProductUsage({this.count = 0, this.lastUsedMs = 0});
}

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
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _catalogoCtrl = TextEditingController();
  Timer? _catalogoDebounce;
  bool _buscandoCatalogo = false;
  List<CatalogProduct> _resultadosCatalogo = [];
  String _catalogoMsg = '';
  final List<BudgetLine> _lineas = [];
  final Map<int, TextEditingController> _descCtrls = {};
  final Map<int, TextEditingController> _qtyCtrls = {};
  final Map<int, String?> _qtyErrors = {};
  late final SignatureController _sig;
  bool _guardando = false;
  bool _firmaActiva = false;

  // Contexto de la instalación.
  String _referencia = '';
  String _referenciaLabel = 'Referencia sin seleccionar';
  bool _referenceHasEmail = false;
  bool _forceNoReference = false;
  bool _cargandoContexto = false;
  String _contextoMsg = '';

  // Estadísticas de uso.
  final Map<int, _ProductUsage> _usage = {};

  // --- Buscar ---
  final _buscarCtrl = TextEditingController();
  Timer? _buscarDebounce;
  bool _buscando = false;
  String _estado = 'TODOS';
  List<String> _estados = ['TODOS'];
  List<PresupuestoResumen> _presupuestos = [];
  String _buscarMsg = '';

  final _fechaFmt = DateFormat('dd/MM/yyyy HH:mm', 'es');

  AdicionalesRepository get _repo => context.read<AdicionalesRepository>();
  SessionService get _session => context.read<SessionService>();

  bool get _hasReferenceForBudget =>
      isPedidoValido(_referencia) && !isManualPedido(_referencia);

  @override
  void initState() {
    super.initState();
    _sig = SignatureController(
      penStrokeWidth: 2.4,
      penColor: const Color(0xFF1565C0),
      exportBackgroundColor: Colors.white,
    );
    // La firma arranca DESACTIVADA (no dibuja hasta pulsar "Activar campo firma").
    _sig.disabled = true;
    _loadUsageStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveInstallationContext();
    });
    // Dev: abrir directamente la pestaña Buscar.
    if (const String.fromEnvironment('START_TAB') == 'buscar') {
      _tab = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _buscar();
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _catalogoCtrl.dispose();
    _buscarCtrl.dispose();
    _catalogoDebounce?.cancel();
    _buscarDebounce?.cancel();
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    for (final c in _qtyCtrls.values) {
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

  // ---------- Estadísticas de uso ----------

  Future<void> _loadUsageStats() async {
    _usage.clear();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsUsageKey) ?? '';
    if (raw.isEmpty) return;
    try {
      final root = jsonDecode(raw);
      if (root is Map) {
        root.forEach((key, value) {
          final id = int.tryParse('$key');
          if (id == null) return;
          if (value is Map) {
            final count = (value['count'] is num)
                ? (value['count'] as num).toInt()
                : 0;
            final last = (value['last_used_ms'] is num)
                ? (value['last_used_ms'] as num).toInt()
                : 0;
            if (count > 0) {
              _usage[id] = _ProductUsage(
                count: count < 0 ? 0 : count,
                lastUsedMs: last < 0 ? 0 : last,
              );
            }
          }
        });
      }
    } catch (_) {
      _usage.clear();
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveUsageStats() async {
    try {
      final root = <String, dynamic>{};
      _usage.forEach((id, u) {
        if (id > 0 && u.count > 0) {
          root['$id'] = {'count': u.count, 'last_used_ms': u.lastUsedMs};
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUsageKey, jsonEncode(root));
    } catch (_) {
      // No interrumpe el flujo.
    }
  }

  void _registerUsage(CatalogProduct p) {
    if (p.idProduct <= 0) return;
    final u = _usage.putIfAbsent(p.idProduct, () => _ProductUsage());
    u.count += 1;
    u.lastUsedMs = DateTime.now().millisecondsSinceEpoch;
    _saveUsageStats();
  }

  // ---------- Contexto de instalación ----------

  Future<void> _resolveInstallationContext() async {
    if (_forceNoReference) {
      _applyNoReference(false);
      return;
    }
    setState(() {
      _cargandoContexto = true;
      _contextoMsg = 'Buscando instalación en curso...';
    });
    final ctx = await _repo.resolveInstallationContext(
      rol: _session.rol,
      usuario: _session.usuarioForRequests,
      equipo: _session.readEquipo(),
    );
    if (!mounted) return;
    if (ctx == null) {
      setState(() {
        _referencia = '';
        _referenciaLabel = 'Referencia sin seleccionar';
        _referenceHasEmail = false;
        _nombreCtrl.text = '';
        _direccionCtrl.text = '';
        _telefonoCtrl.text = '';
        _setEmailForUi('');
        _cargandoContexto = false;
        _contextoMsg = '';
      });
      return;
    }
    setState(() {
      _referencia = ctx.referencia;
      _forceNoReference = false;
      _referenciaLabel = 'Referencia ${ctx.referencia}';
      _nombreCtrl.text = ctx.cliente;
      _direccionCtrl.text = ctx.direccion;
      _telefonoCtrl.text = ctx.telefono;
      _referenceHasEmail = ctx.email.isNotEmpty;
      _setEmailForUi(ctx.email);
      _cargandoContexto = false;
      _contextoMsg = '';
    });
  }

  void _applyNoReference(bool showToast) {
    setState(() {
      _forceNoReference = true;
      _referencia = '';
      _referenciaLabel = 'Sin referencia (manual)';
      _referenceHasEmail = false;
      _nombreCtrl.text = '';
      _direccionCtrl.text = '';
      _telefonoCtrl.text = '';
      _setEmailForUi('');
      _cargandoContexto = false;
      _contextoMsg = '';
    });
    if (showToast) _msg('Modo sin referencia activado');
  }

  void _setEmailForUi(String email) {
    _emailCtrl.text = email;
  }

  Future<void> _loadManualReference(String ref) async {
    setState(() {
      _cargandoContexto = true;
      _contextoMsg = 'Cargando datos de la instalación...';
    });
    final ctx = await _repo.resolveInstallationHeaderByRef(ref);
    if (!mounted) return;
    if (ctx == null) {
      setState(() {
        _cargandoContexto = false;
        _contextoMsg = '';
      });
      _msg('No se pudo cargar la instalación');
      _showManualReferenceDialog();
      return;
    }
    setState(() {
      _referencia = ref;
      _forceNoReference = false;
      _referenciaLabel = 'Referencia $ref';
      _nombreCtrl.text = ctx.cliente;
      _direccionCtrl.text = ctx.direccion;
      _telefonoCtrl.text = ctx.telefono;
      _referenceHasEmail = ctx.email.isNotEmpty;
      _setEmailForUi(ctx.email);
      _cargandoContexto = false;
      _contextoMsg = '';
    });
    _msg('Instalación cargada');
  }

  Future<void> _showManualReferenceDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Seleccionar instalación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Introduce la referencia de la instalación o deja el campo vacío para crear un presupuesto sin referencia.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Referencia de instalación'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dctx);
              _applyNoReference(true);
            },
            child: const Text('Sin referencia'),
          ),
          ElevatedButton(
            onPressed: () {
              final ref = UiText.sanitizeDbValue(ctrl.text);
              if (ref.isEmpty) {
                Navigator.pop(dctx);
                _applyNoReference(true);
                return;
              }
              if (!isPedidoValido(ref) || isManualPedido(ref)) {
                _msg('Referencia no válida');
                return;
              }
              Navigator.pop(dctx);
              _forceNoReference = false;
              _loadManualReference(ref);
            },
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  // ---------- Catálogo / líneas ----------

  void _onCatalogoChanged(String q) {
    _catalogoDebounce?.cancel();
    _catalogoDebounce = Timer(const Duration(milliseconds: 300), () {
      _buscarCatalogo(q.trim());
    });
  }

  Future<void> _buscarCatalogo(String q) async {
    setState(() => _buscandoCatalogo = true);
    final res = await _repo.getCatalogo(q, limit: 0);
    if (!mounted) return;
    setState(() {
      _resultadosCatalogo = res.productos;
      _catalogoMsg = res.productos.isEmpty
          ? (res.message.isEmpty ? 'Sin resultados para esta búsqueda' : res.message)
          : '';
      _buscandoCatalogo = false;
    });
  }

  /// Recomendados: hasta 3 productos ordenados por estadísticas de uso.
  List<CatalogProduct> get _recomendados {
    final list = List<CatalogProduct>.from(_resultadosCatalogo);
    final originalOrder = <int, int>{};
    for (var i = 0; i < list.length; i++) {
      originalOrder[list[i].idProduct] = i;
    }
    list.sort((a, b) {
      final ua = _usage[a.idProduct];
      final ub = _usage[b.idProduct];
      final aUsed = ua != null && ua.count > 0;
      final bUsed = ub != null && ub.count > 0;
      if (aUsed != bUsed) return aUsed ? -1 : 1;
      final countA = ua?.count ?? 0;
      final countB = ub?.count ?? 0;
      final cmpCount = countB.compareTo(countA);
      if (cmpCount != 0) return cmpCount;
      final lastA = ua?.lastUsedMs ?? 0;
      final lastB = ub?.lastUsedMs ?? 0;
      final cmpLast = lastB.compareTo(lastA);
      if (cmpLast != 0) return cmpLast;
      final idxA = originalOrder[a.idProduct] ?? 1 << 30;
      final idxB = originalOrder[b.idProduct] ?? 1 << 30;
      return idxA.compareTo(idxB);
    });
    return list.take(_maxRecommended).toList();
  }

  void _addLine(CatalogProduct p) {
    final existing = _lineas.where((l) => l.product.idProduct == p.idProduct);
    setState(() {
      if (existing.isNotEmpty) {
        final l = existing.first;
        l.quantity = l.quantity + 1;
        _qtyCtrls[p.idProduct]?.text = _formatQty(l.quantity);
        _qtyErrors[p.idProduct] = null;
      } else {
        final line = BudgetLine(product: p);
        _lineas.add(line);
        _descCtrls[p.idProduct] =
            TextEditingController(text: line.descripcion);
        _qtyCtrls[p.idProduct] =
            TextEditingController(text: _formatQty(line.quantity));
        _qtyErrors[p.idProduct] = null;
      }
      _registerUsage(p);
    });
    _msg('Artículo añadido al presupuesto');
  }

  void _removeLine(BudgetLine l) {
    setState(() {
      _lineas.remove(l);
      _descCtrls.remove(l.product.idProduct)?.dispose();
      _qtyCtrls.remove(l.product.idProduct)?.dispose();
      _qtyErrors.remove(l.product.idProduct);
    });
  }

  void _stepQty(BudgetLine l, bool increment) {
    var next = increment ? l.quantity + 1 : l.quantity - 1;
    if (next < 0.1) next = 0.1;
    next = double.parse(next.toStringAsFixed(1));
    setState(() {
      l.quantity = next;
      _qtyCtrls[l.product.idProduct]?.text = _formatQty(next);
      _qtyErrors[l.product.idProduct] = null;
    });
  }

  void _onQtyChanged(BudgetLine l, String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return;
    final v = _validateQuantity(clean);
    setState(() {
      if (v == null) {
        _qtyErrors[l.product.idProduct] = 'Cantidad inválida';
      } else {
        _qtyErrors[l.product.idProduct] = null;
        l.quantity = v;
      }
    });
  }

  /// Réplica de validateQuantity: `^\d+(\.\d)?$` sobre coma→punto, y > 0.
  double? _validateQuantity(String raw) {
    final s = UiText.sanitizeDbValue(raw).replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d)?$').hasMatch(s)) return null;
    final v = double.tryParse(s);
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Réplica de formatQuantity: entero sin decimales, máx 1 decimal sin ceros.
  String _formatQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    var s = q.toStringAsFixed(1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 2);
    return s;
  }

  double get _totalSinIva =>
      _lineas.fold(0, (s, l) => s + l.pricing.totalSinIva);
  double get _totalConIva =>
      _lineas.fold(0, (s, l) => s + l.pricing.totalConIva);
  double get _totalIva => _totalConIva - _totalSinIva;

  // ---------- Firma ----------

  void _toggleFirma() {
    setState(() {
      _firmaActiva = !_firmaActiva;
      _sig.disabled = !_firmaActiva;
    });
  }

  String get _firmaHint {
    if (!_firmaActiva) {
      return _sig.isNotEmpty
          ? 'Firma capturada. Campo desactivado'
          : 'Campo firma desactivado. Pulsa "Activar campo firma"';
    }
    return _sig.isNotEmpty ? 'Firma capturada' : 'Firma aquí con el dedo';
  }

  // ---------- Guardar ----------

  String _resolveEmailForSave() {
    if (_hasReferenceForBudget && _referenceHasEmail) {
      // El email de la referencia SIEMPRE que exista (campo bloqueado).
      return UiText.sanitizeDbValue(_emailCtrl.text);
    }
    return UiText.sanitizeDbValue(_emailCtrl.text);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (_lineas.isEmpty) {
      _msg('Añade al menos una línea al presupuesto');
      return;
    }

    final email = _resolveEmailForSave();
    final refValida = _hasReferenceForBudget;
    if (refValida && _referenceHasEmail) {
      if (!isValidEmail(email)) {
        _msg('Email de referencia no válido');
        return;
      }
    } else if (!refValida) {
      if (!isValidEmail(email)) {
        await _showEmailRequiredDialog();
        return;
      }
    } else {
      // Referencia válida pero sin email.
      if (!isValidEmail(email)) {
        _msg('Esta referencia no tiene email. Introduce uno válido para este envío');
        return;
      }
    }

    if (!_firmaActiva || _sig.isEmpty) {
      _msg('La firma del cliente es obligatoria');
      return;
    }

    final locationService = context.read<LocationService>();
    final session = _session;
    setState(() => _guardando = true);
    try {
      final pngBytes = await _sig.toPngBytes();
      if (pngBytes == null) {
        _msg('No se pudo capturar la firma');
        return;
      }
      final loc = await locationService.capture();

      final lineasJson = <Map<String, dynamic>>[];
      for (var i = 0; i < _lineas.length; i++) {
        final l = _lineas[i];
        final pr = l.pricing;
        var desc = UiText.sanitizeDbValue(_descCtrls[l.product.idProduct]?.text ?? '');
        if (desc.isEmpty) desc = l.product.descripcion;
        lineasJson.add({
          'orden': i + 1,
          'cantidad': _apiDecimal(l.quantity, 2),
          'articulo': l.product.codigo.isEmpty ? 'SIN-CODIGO' : l.product.codigo,
          'descripcion': desc,
          'precio_unitario_sin_iva': _apiDecimal(pr.unitSinIva, 6),
          'precio_total_linea_sin_iva': _apiDecimal(pr.totalSinIva, 2),
          'iva_pct': _apiDecimal(pr.ivaPct, 3),
          'precio_total_linea_con_iva': _apiDecimal(pr.totalConIva, 2),
          'iva_fallback': pr.ivaFallback,
        });
      }

      final numeroPedido = refValida
          ? UiText.sanitizeDbValue(_referencia)
          : 'MANUAL-${DateTime.now().millisecondsSinceEpoch}';

      final res = await _repo.guardar({
        'referencia': refValida ? UiText.sanitizeDbValue(_referencia) : '',
        'numero_pedido': numeroPedido,
        'nombre_cliente': _normalizeField(_nombreCtrl.text, 'Cliente'),
        'direccion_cliente': _normalizeField(_direccionCtrl.text, ''),
        'telefono': _normalizeField(_telefonoCtrl.text, ''),
        'email_cliente': email,
        'usuario_instalador': session.displayName(fallback: 'Instalador'),
        'equipo_instaladores': session.readEquipo(),
        'total_sin_iva': _apiDecimal(_totalSinIva, 2),
        'total_iva': _apiDecimal(_totalIva, 2),
        'total_con_iva': _apiDecimal(_totalConIva, 2),
        'firma_base64': base64Encode(pngBytes),
        'lineas_json': jsonEncode(lineasJson),
        'latitud': loc.latParam,
        'longitud': loc.lngParam,
      });
      if (!mounted) return;
      _msg(res.message);
      if (res.ok) _resetNuevo();
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo guardar el presupuesto');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _normalizeField(String raw, String fallback) {
    final value = UiText.sanitizeDbValue(raw);
    final lower = value.toLowerCase();
    if (value.isEmpty ||
        lower.contains('no disponible') ||
        lower.contains('sin seleccionar')) {
      return UiText.sanitizeDbValue(fallback);
    }
    return value;
  }

  String _apiDecimal(double v, int scale) =>
      roundHalfUp(v, scale).toStringAsFixed(scale);

  Future<void> _showEmailRequiredDialog() async {
    final ctrl = TextEditingController(text: _resolveEmailForSave());
    var retry = false;
    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Email del cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Sin referencia asignada debes indicar un email para continuar.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(hintText: 'cliente@dominio.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = UiText.sanitizeDbValue(ctrl.text);
              if (!isValidEmail(email)) {
                _msg('Introduce un email válido');
                return;
              }
              _setEmailForUi(email);
              retry = true;
              Navigator.pop(dctx);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (retry && mounted) _guardar();
  }

  void _resetNuevo() {
    setState(() {
      _lineas.clear();
      for (final c in _descCtrls.values) {
        c.dispose();
      }
      for (final c in _qtyCtrls.values) {
        c.dispose();
      }
      _descCtrls.clear();
      _qtyCtrls.clear();
      _qtyErrors.clear();
      _resultadosCatalogo = [];
      _catalogoMsg = '';
      _catalogoCtrl.clear();
      _sig.clear();
      _firmaActiva = false;
      _sig.disabled = true;
      // Limpia TODO el formulario (incluidos campos de cliente).
      _nombreCtrl.clear();
      _emailCtrl.clear();
      _telefonoCtrl.clear();
      _direccionCtrl.clear();
      _referencia = '';
      _referenciaLabel = 'Referencia sin seleccionar';
      _referenceHasEmail = false;
      _forceNoReference = false;
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
      _buscarMsg = res.ok
          ? (res.items.isEmpty ? 'Sin resultados para esta búsqueda' : '')
          : (res.message.isEmpty ? 'No se pudo cargar la búsqueda' : res.message);
      // Normaliza/resetea filtros de estado.
      final norm = <String>['TODOS'];
      for (final e in res.estados) {
        final up = UiText.sanitizeDbValue(e).toUpperCase();
        if (up.isNotEmpty && up != 'TODOS' && !norm.contains(up)) {
          norm.add(up);
        }
      }
      _estados = norm;
      if (!_estados.contains(_estado)) _estado = 'TODOS';
      _buscando = false;
    });
  }

  Future<void> _abrirDetalle(PresupuestoResumen p) async {
    await context.push('/presupuesto', extra: {'id': p.id});
    if (!mounted) return;
    // Recarga al volver del detalle.
    _buscar();
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          Expanded(child: _tabBtn('Nuevo presupuesto', 0)),
          const SizedBox(width: 8),
          Expanded(child: _tabBtn('Buscar', 1)),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tab = index);
        // Recarga SIEMPRE al entrar en la pestaña Buscar.
        if (index == 1) _buscar();
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? AppColors.white : AppColors.primary)),
      ),
    );
  }

  // ---------- Nuevo tab ----------

  Widget _nuevo() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        _card(
          'Datos del cliente',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_referenciaLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                  ),
                  TextButton(
                    onPressed: _showManualReferenceDialog,
                    child: const Text('Cambiar referencia'),
                  ),
                ],
              ),
              if (_cargandoContexto)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(_contextoMsg,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 8),
              _field('Nombre del cliente', _nombreCtrl),
              const SizedBox(height: 8),
              _field(
                _emailFieldLabel,
                _emailCtrl,
                keyboard: TextInputType.emailAddress,
                enabled: !_emailFieldLocked,
              ),
              if (_hasReferenceForBudget && !_referenceHasEmail)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Esta referencia no tiene email; el que indiques se usará solo para este envío.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              _field('Teléfono', _telefonoCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 8),
              _field('Dirección', _direccionCtrl, lines: 2),
            ],
          ),
        ),
        _card(
            'Catálogo',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  for (final p in _recomendados) _resultadoCatalogo(p),
              ],
            )),
        if (_lineas.isNotEmpty)
          _card(
              'Líneas del presupuesto',
              Column(
                children: [for (final l in _lineas) _lineaWidget(l)],
              )),
        _card(
            'Totales',
            Column(
              children: [
                _totalRow('Subtotal (sin IVA)', _totalSinIva),
                _totalRow('IVA', _totalIva),
                _totalRow('Total (con IVA)', _totalConIva, bold: true),
              ],
            )),
        _card(
            'Firma del cliente',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_firmaHint,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Opacity(
                  opacity: _firmaActiva ? 1 : 0.75,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.cardStroke),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IgnorePointer(
                      ignoring: !_firmaActiva,
                      child: Signature(
                        controller: _sig,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _toggleFirma,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _firmaActiva
                              ? const Color(0xFFFDECEC)
                              : const Color(0xFFE8F7EE),
                          foregroundColor: _firmaActiva
                              ? const Color(0xFFA42828)
                              : const Color(0xFF1B7A45),
                          side: BorderSide(
                              color: _firmaActiva
                                  ? const Color(0xFFE78A8A)
                                  : const Color(0xFF88C8A1)),
                        ),
                        child: Text(_firmaActiva
                            ? 'Desactivar campo firma'
                            : 'Activar campo firma'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _sig.clear()),
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar firma'),
                    ),
                  ],
                ),
              ],
            )),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
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

  bool get _emailFieldLocked => _hasReferenceForBudget && _referenceHasEmail;

  String get _emailFieldLabel {
    if (_emailFieldLocked) return 'Email de la referencia';
    if (_hasReferenceForBudget) return 'Email cliente (solo para este envío)';
    return 'Email cliente (obligatorio sin referencia)';
  }

  Widget _resultadoCatalogo(CatalogProduct p) {
    final usage = _usage[p.idProduct];
    var meta = 'IVA ${formatPercent(p.ivaPct)}';
    if (p.ivaFallback) meta += ' (estimado)';
    meta += ' · Recomendado';
    if (usage != null && usage.count > 0) meta += ' · usado ${usage.count} veces';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _addLine(p),
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

  Widget _lineaWidget(BudgetLine l) {
    final pr = l.pricing;
    final err = _qtyErrors[l.product.idProduct];
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
                child: Text(
                    l.product.codigo.isEmpty ? 'SIN CÓDIGO' : l.product.codigo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEE8A2D))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
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
              _qtyBtn(Icons.remove, () => _stepQty(l, false)),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _qtyCtrls[l.product.idProduct],
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
              Text(euros(pr.totalConIva),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
            ],
          ),
          Text(
              'P. unit: ${euros(pr.unitConIva)} (IVA incl.) · IVA ${formatPercent(pr.ivaPct)}${pr.ivaFallback ? ' (estimado)' : ''}',
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
                    label: Text(e == 'TODOS' ? 'Todos' : e),
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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            _buscarMsg.isEmpty
                                ? 'Sin resultados para esta búsqueda'
                                : _buscarMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                    )
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

  String _formatFecha(String raw) {
    final clean = UiText.sanitizeDbValue(raw);
    if (clean.isEmpty) return 'Sin fecha';
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
        .firstMatch(clean);
    if (m == null) return clean;
    try {
      final dt = DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      );
      return _fechaFmt.format(dt);
    } catch (_) {
      return clean;
    }
  }

  Widget _presupuestoItem(PresupuestoResumen p) {
    final cancelado = p.estado.toUpperCase() == 'CANCELADO';
    final cliente = p.cliente.isEmpty ? 'Cliente no disponible' : p.cliente;
    final tel = p.telefono.isEmpty ? 'Sin teléfono' : p.telefono;
    final equipo = p.equipo.isEmpty ? 'Sin equipo' : 'Eq. ${p.equipo}';
    final usuario = p.usuario.isEmpty ? 'Sin usuario' : p.usuario;
    final estado = p.estado.isEmpty ? 'N/D' : p.estado.toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _abrirDetalle(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardStroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '#${p.id} · Pedido ${p.numeroPedido.isEmpty ? '-' : p.numeroPedido}',
                          style: const TextStyle(
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
                      child: Text(estado,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(cliente,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '$tel · $equipo · $usuario · ${_formatFecha(p.fecha)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(
                    'Total: ${euros(p.importeConIva)}${p.mailEnviado ? ' · Mail OK' : ' · Mail pendiente'}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- helpers ----------

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard,
      int lines = 1,
      bool enabled = true,
      ValueChanged<String>? onChanged}) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        enabled: enabled,
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
