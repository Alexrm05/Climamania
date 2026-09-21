import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../../data/models/catalogo.dart';
import '../../data/models/parte_materiales.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/adicionales_repository.dart';
import '../../data/repositories/materiales_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Parte de trabajo (escandallo): material consumido y horas en el domicilio.
///
/// Si llega con [referencia] (desde "Realizar instalación") carga el pedido
/// directamente; si no, pide el número de pedido. Si el parte ya existe se
/// muestra relleno para verlo o editarlo. La tabla arranca con los
/// materiales por defecto y con "+" se añaden otros de la categoría 711 de
/// PrestaShop. Al guardar registra la ubicación sin intervención del usuario.
/// Devuelve `true` al guardar.
class EscandalloScreen extends StatefulWidget {
  final String referencia;

  const EscandalloScreen({super.key, this.referencia = ''});

  @override
  State<EscandalloScreen> createState() => _EscandalloScreenState();
}

class _EscandalloScreenState extends State<EscandalloScreen> {
  final _pedidoCtrl = TextEditingController();
  final _descCtrls = <MaterialLinea, TextEditingController>{};

  Pedido? _pedido;
  ParteMateriales? _parte;
  bool _cargando = false;
  bool _guardando = false;

  String _horaInicio = '';
  String _horaFinal = '';
  final List<MaterialLinea> _lineas = [];

  @override
  void initState() {
    super.initState();
    if (widget.referencia.isNotEmpty) {
      _pedidoCtrl.text = widget.referencia;
      _cargar();
    }
  }

  @override
  void dispose() {
    _pedidoCtrl.dispose();
    for (final c in _descCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  TextEditingController _descCtrl(MaterialLinea l) =>
      _descCtrls.putIfAbsent(l, () => TextEditingController(text: l.descripcion));

  bool get _yaExistia => _parte?.existe ?? false;

  // ---------------------------------------------------------------------------
  // Carga
  // ---------------------------------------------------------------------------

  Future<void> _cargar() async {
    FocusScope.of(context).unfocus();
    final ref = _pedidoCtrl.text.trim();
    if (ref.isEmpty) {
      _msg('Indica el número de pedido');
      return;
    }
    setState(() => _cargando = true);
    final pedidoRepo = context.read<PedidoRepository>();
    final matRepo = context.read<MaterialesRepository>();
    try {
      final res = await pedidoRepo.getPedido(ref);
      if (res.pedido == null) {
        _msg(res.message.isEmpty ? 'Pedido no encontrado' : res.message);
        return;
      }
      // Referencias del pedido: con ellas el servidor elige los materiales
      // por defecto (por tipo de instalación) y la cantidad prevista.
      final padres = [
        for (final l in res.pedido!.detallePedido)
          if (l.referencia.trim().isNotEmpty)
            '${l.referencia.trim()}:${l.cantidad.trim().isEmpty ? '1' : l.cantidad.trim()}',
      ];
      final parte = await matRepo.getParte(ref, padres: padres);
      if (!mounted) return;
      setState(() {
        _pedido = res.pedido;
        _parte = parte;
        _lineas.clear();
        for (final c in _descCtrls.values) {
          c.dispose();
        }
        _descCtrls.clear();
        if (parte != null) {
          _horaInicio = parte.horaInicio;
          _horaFinal = parte.horaFinal;
          // Con parte guardado se edita ese; si no, arrancan los de defecto.
          _lineas.addAll(parte.existe ? parte.lineas : parte.defecto);
        }
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Horas
  // ---------------------------------------------------------------------------

  TimeOfDay? _parse(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
    if (m == null) return null;
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirHora(bool llegada) async {
    final actual = _parse(llegada ? _horaInicio : _horaFinal) ?? TimeOfDay.now();
    final t = await showTimePicker(
      context: context,
      initialTime: actual,
      helpText: llegada ? 'Hora de llegada al domicilio' : 'Hora de salida del domicilio',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !mounted) return;
    setState(() {
      if (llegada) {
        _horaInicio = _fmt(t);
      } else {
        _horaFinal = _fmt(t);
      }
    });
  }

  int? get _minutos => minutosEntre(_horaInicio, _horaFinal);

  // ---------------------------------------------------------------------------
  // Líneas
  // ---------------------------------------------------------------------------

  void _anadirProducto(CatalogProduct p) {
    final existente = _lineas.where((l) => l.articulo == p.codigo).firstOrNull;
    setState(() {
      if (existente != null) {
        existente.cantidad += 1;
      } else {
        _lineas.add(MaterialLinea(
          articulo: p.codigo,
          descripcion: p.descripcion,
          cantidad: 1,
          precioUnitarioSinIva: p.precioBaseSinIva,
        ));
      }
    });
  }

  void _quitar(MaterialLinea l) {
    setState(() {
      _lineas.remove(l);
      _descCtrls.remove(l)?.dispose();
    });
  }

  Future<void> _abrirBuscador() async {
    final producto = await showModalBottomSheet<CatalogProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _BuscadorMateriales(),
    );
    if (producto != null) _anadirProducto(producto);
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_pedido == null) return;
    if (_minutos == null) {
      _msg(_horaInicio.isEmpty || _horaFinal.isEmpty
          ? 'Indica la hora de llegada y de salida del domicilio'
          : 'La hora de salida debe ser posterior a la de llegada');
      return;
    }
    final relevantes = _lineas.where((l) => l.relevante).toList();
    if (relevantes.where((l) => l.cantidad > 0).isEmpty) {
      _msg('Indica la cantidad real de al menos un material');
      return;
    }
    setState(() => _guardando = true);
    final session = context.read<SessionService>();
    final matRepo = context.read<MaterialesRepository>();
    final locationService = context.read<LocationService>();
    try {
      // Ubicación silenciosa: si falla (permiso, GPS), se guarda sin ella.
      var lat = '';
      var lng = '';
      try {
        final loc = await locationService.capture();
        lat = loc.latParam;
        lng = loc.lngParam;
      } catch (_) {}

      final res = await matRepo.guardar(
        referencia: _pedido!.referencia,
        usuario: session.usuarioForRequests,
        equipo: session.readEquipo(),
        horaInicio: _horaInicio,
        horaFinal: _horaFinal,
        lineas: relevantes,
        latitud: lat,
        longitud: lng,
      );
      if (!mounted) return;
      if (!res.ok) {
        _msg(res.message.isEmpty ? 'No se pudo guardar el parte' : res.message);
        return;
      }
      _msg(res.message.isEmpty ? 'Parte de trabajo guardado' : res.message);
      context.pop(true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Parte de trabajo')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (widget.referencia.isEmpty) _cardBuscarPedido(),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_pedido != null) ...[
                  _cardDatosGenerales(t),
                  _cardMaterial(t),
                ],
              ],
            ),
          ),
          if (_pedido != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    style: AppDecorations.greenButton,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(_yaExistia ? 'Actualizar parte' : 'Guardar parte'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cardBuscarPedido() {
    return _card(
      'Pedido',
      Row(
        children: [
          Expanded(
            child: Container(
              decoration: AppDecorations.editText,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _pedidoCtrl,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _cargar(),
                decoration: AppDecorations.bareInput(
                    labelText: 'Número de pedido',
                    contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _cargando ? null : _cargar,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd)),
              child: const Text('Cargar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDatosGenerales(TextTheme t) {
    final p = _pedido!;
    final parte = _parte;
    final fecha = (parte?.existe ?? false) && parte!.fechaCreacion.isNotEmpty
        ? _fechaCorta(parte.fechaCreacion)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());
    final session = context.read<SessionService>();
    final tecnicos = [
      if ((parte?.existe ?? false) && parte!.equipo.isNotEmpty)
        parte.equipo
      else if (session.readEquipo().isNotEmpty)
        session.readEquipo(),
      (parte?.existe ?? false) && parte!.usuario.isNotEmpty
          ? parte.usuario
          : session.displayName(),
    ].join(' · ');
    final contacto = p.entrega ?? p.facturacion;
    // PrestaShop trae fijo y móvil; si coinciden, uno solo.
    final telefonos = (contacto?.telefono ?? '')
        .split(RegExp(r'\s+'))
        .where((x) => x.isNotEmpty)
        .toSet()
        .join(' / ');
    final contactoTxt = contacto == null
        ? ''
        : [contacto.nombre, telefonos]
            .where((s) => s.trim().isNotEmpty)
            .join(' · ');
    final min = _minutos;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                Text('PARTE DE TRABAJO Nº ${p.referencia}',
                    style: t.titleMedium?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
                if (_yaExistia)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Registrado: puedes verlo o modificarlo.',
                        style: t.bodySmall?.copyWith(color: AppColors.successFg)),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text('Datos generales', style: t.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                _dato('Fecha', fecha),
                _dato('Nº pedido / presupuesto', p.referencia),
                _dato('Técnico/s', tecnicos),
                _filaHoras(t, min),
                _dato('Cliente', p.cliente),
                _dato('Dirección de la instalación',
                    UiText.limpiarDireccion(p.direccionInstalacion)),
                _dato('Persona de contacto / teléfono', contactoTxt),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fechaCorta(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd/MM/yyyy').format(d);
  }

  Widget _dato(String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label,
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value.trim().isEmpty ? '—' : value,
                style: t.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _filaHoras(TextTheme t, int? min) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 128,
            child: Text('Hora llegada / salida',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          _horaChip(_horaInicio, () => _elegirHora(true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('—'),
          ),
          _horaChip(_horaFinal, () => _elegirHora(false)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              min == null ? '' : formatoHoras(min),
              style: t.bodySmall?.copyWith(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w700),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _horaChip(String valor, VoidCallback onTap) {
    final vacio = valor.isEmpty;
    return Material(
      color: vacio ? AppColors.errorTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brSm,
        side: BorderSide(color: vacio ? AppColors.errorFg : AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(vacio ? '__:__' : valor,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: vacio ? AppColors.errorFg : null)),
        ),
      ),
    );
  }

  Widget _cardMaterial(TextTheme t) {
    return _card(
      'Material consumido',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabeceraColumnas(t),
          const Divider(height: 1, color: AppColors.border),
          if (_lineas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('Sin materiales. Añade los que has gastado con el botón +.',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ),
          for (final l in _lineas) _lineaWidget(l),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _abrirBuscador,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Añadir material'),
          ),
        ],
      ),
    );
  }

  Widget _cabeceraColumnas(TextTheme t) {
    final s = t.labelSmall?.copyWith(color: AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text('Ref. / Descripción', style: s)),
          SizedBox(width: 36, child: Text('Ud.', style: s)),
          SizedBox(width: 52, child: Text('Prev.', style: s, textAlign: TextAlign.center)),
          SizedBox(width: 96, child: Text('Real', style: s, textAlign: TextAlign.center)),
          SizedBox(width: 44, child: Text('Desv.', style: s, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _lineaWidget(MaterialLinea l) {
    final t = Theme.of(context).textTheme;
    final sinUso = l.cantidad <= 0;
    final desv = l.desviacion;
    final desvColor = desv > 0
        ? AppColors.errorFg
        : desv < 0
            ? AppColors.infoFg
            : AppColors.textMuted;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: sinUso ? AppColors.surface : AppColors.surfaceWarm,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.articulo.isEmpty ? 'SIN REF.' : l.articulo,
                    style: t.titleSmall?.copyWith(color: AppColors.primary)),
              ),
              if (l.articuloPadre.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.infoTint, borderRadius: AppRadius.brSm),
                  child: Text(
                      l.articuloPadre == '*' ? 'común' : l.articuloPadre,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.infoFg)),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.errorFg),
                onPressed: () => _quitar(l),
              ),
            ],
          ),
          TextField(
            controller: _descCtrl(l),
            minLines: 1,
            maxLines: 2,
            style: t.bodyMedium,
            onChanged: (v) => l.descripcion = v,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Descripción',
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 36,
                child: Text(l.unidad, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
              SizedBox(
                width: 52,
                child: _stepper(
                  valor: l.cantidadPrevista,
                  compacto: true,
                  onChanged: (v) => setState(() => l.cantidadPrevista = v),
                ),
              ),
              SizedBox(
                width: 96,
                child: _stepper(
                  valor: l.cantidad,
                  onChanged: (v) => setState(() => l.cantidad = v),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(formatoDesviacion(desv),
                    textAlign: TextAlign.right,
                    style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: desvColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cantidad con -/+ . En modo compacto muestra el valor y ajusta con toque
  /// largo / corto (la previsión la fija normalmente la oficina).
  Widget _stepper({
    required double valor,
    required ValueChanged<double> onChanged,
    bool compacto = false,
  }) {
    final texto = Text(formatoCantidad(valor),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: compacto ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: valor <= 0 ? AppColors.textMuted : null));
    if (compacto) {
      return InkWell(
        onTap: () => onChanged(valor + 1),
        onLongPress: () => onChanged((valor - 1).clamp(0, 9999)),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6), child: texto),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _qtyBtn(Icons.remove, () => onChanged((valor - 1).clamp(0, 9999))),
        SizedBox(width: 30, child: texto),
        _qtyBtn(Icons.add, () => onChanged(valor + 1)),
      ],
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
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
}

/// Buscador de materiales (categoría 711) en hoja inferior: más usados al
/// abrir y resultados según se escribe. Devuelve el producto elegido.
class _BuscadorMateriales extends StatefulWidget {
  const _BuscadorMateriales();

  @override
  State<_BuscadorMateriales> createState() => _BuscadorMaterialesState();
}

class _BuscadorMaterialesState extends State<_BuscadorMateriales> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<CatalogProduct> _masUsados = [];
  List<CatalogProduct> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _cargarMasUsados();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMasUsados() async {
    final r = await context
        .read<AdicionalesRepository>()
        .getMasUsados(categoria: AppConfig.categoriaMateriales);
    if (mounted) setState(() => _masUsados = r);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(q));
  }

  Future<void> _buscar(String q) async {
    if (q.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    final r = await context
        .read<AdicionalesRepository>()
        .getCatalogo(q.trim(), categoria: AppConfig.categoriaMateriales);
    if (mounted) {
      setState(() {
        _resultados = r;
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mostrarMasUsados = _ctrl.text.trim().length < 2;
    final lista = mostrarMasUsados ? _masUsados : _resultados;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Añadir material', style: t.titleMedium),
                const SizedBox(height: 8),
                Container(
                  decoration: AppDecorations.editText,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onChanged: (v) {
                      setState(() {});
                      _onChanged(v);
                    },
                    decoration: AppDecorations.bareInput(
                      hintText: 'Buscar por referencia o descripción',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mostrarMasUsados
                      ? 'Más usados'
                      : _buscando
                          ? 'Buscando…'
                          : '${_resultados.length} resultados',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? Center(
                    child: Text(
                      mostrarMasUsados
                          ? 'Escribe para buscar en el catálogo'
                          : _buscando
                              ? ''
                              : 'Sin resultados',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: lista.length,
                    itemBuilder: (_, i) => _item(lista[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(CatalogProduct p) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(p),
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
                    Text(p.codigo.isEmpty ? 'SIN REF.' : p.codigo,
                        style: t.titleSmall?.copyWith(color: AppColors.primary)),
                    Text(p.descripcion, style: t.bodyMedium),
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
}
