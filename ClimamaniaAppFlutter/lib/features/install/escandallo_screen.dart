import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/ui_text.dart';
import '../../data/models/parte_materiales.dart';
import '../../data/models/pedido.dart';
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
  static final _diaCorto = DateFormat('dd/MM');

  final _pedidoCtrl = TextEditingController();
  final _descCtrls = <MaterialLinea, TextEditingController>{};

  Pedido? _pedido;
  ParteMateriales? _parte;
  bool _cargando = false;
  bool _guardando = false;

  /// Días trabajados: una instalación puede ocupar varias jornadas.
  final List<Jornada> _jornadas = [];
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
        _jornadas.clear();
        if (parte != null) {
          _jornadas.addAll(parte.jornadas);
          // Con parte guardado se edita ese; si no, arrancan los de defecto.
          _lineas.addAll(parte.existe ? parte.lineas : parte.defecto);
        }
        if (_jornadas.isEmpty) {
          _jornadas.add(Jornada(fecha: DateTime.now()));
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

  Future<void> _elegirHora(Jornada j, bool llegada) async {
    final actual = _parse(llegada ? j.horaInicio : j.horaFinal) ?? TimeOfDay.now();
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
        j.horaInicio = _fmt(t);
      } else {
        j.horaFinal = _fmt(t);
      }
    });
  }

  Future<void> _elegirFecha(Jornada j) async {
    final d = await showDatePicker(
      context: context,
      initialDate: j.fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Día de trabajo',
    );
    if (d == null || !mounted) return;
    setState(() => j.fecha = DateTime(d.year, d.month, d.day));
  }

  /// Nueva jornada: el día siguiente al último registrado, sin horas.
  void _anadirJornada() {
    final ultima = _jornadas.isEmpty ? DateTime.now() : _jornadas.last.fecha;
    setState(() => _jornadas
        .add(Jornada(fecha: ultima.add(const Duration(days: 1)))));
  }

  void _quitarJornada(Jornada j) {
    setState(() {
      _jornadas.remove(j);
      if (_jornadas.isEmpty) _jornadas.add(Jornada(fecha: DateTime.now()));
    });
  }

  /// Minutos de todas las jornadas completas.
  int get _minutosTotal => _jornadas.fold(0, (a, j) => a + (j.minutos ?? 0));

  /// Jornadas con fecha y las dos horas válidas.
  List<Jornada> get _jornadasCompletas =>
      _jornadas.where((j) => j.completa).toList();

  // ---------------------------------------------------------------------------
  // Líneas
  // ---------------------------------------------------------------------------

  void _anadirMaterial(MaterialCatalogo m) {
    final existente =
        _lineas.where((l) => l.articulo == m.articulo).firstOrNull;
    setState(() {
      if (existente != null) {
        existente.cantidad += 1;
      } else {
        _lineas.add(m.comoLinea());
      }
    });
  }

  void _quitar(MaterialLinea l) {
    setState(() {
      _lineas.remove(l);
      _descCtrls.remove(l)?.dispose();
    });
  }

  /// Pide la cantidad exacta por teclado, con decimales. La cantidad va en
  /// la unidad del catálogo (metros, kilos, unidades): la conversión a
  /// envases la hace GOTEL con su factor, aquí no se toca.
  Future<void> _escribirCantidad(MaterialLinea l) async {
    final ctrl = TextEditingController(
        text: l.cantidad > 0 ? formatoCantidad(l.cantidad) : '');
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.articulo.isEmpty ? 'Cantidad' : 'Cantidad · ${l.articulo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.descripcion,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: l.unidad,
                hintText: '0',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(cantidadDesdeTexto(v)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(cantidadDesdeTexto(ctrl.text)),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (valor == null || !mounted) return;
    setState(() => l.cantidad = valor);
  }

  Future<void> _abrirBuscador() async {
    final material = await showModalBottomSheet<MaterialCatalogo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _BuscadorMateriales(),
    );
    if (material != null) _anadirMaterial(material);
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (_pedido == null) return;
    final jornadas = _jornadasCompletas;
    if (jornadas.isEmpty) {
      _msg(_jornadas.any((j) => j.horaInicio.isEmpty || j.horaFinal.isEmpty)
          ? 'Indica la hora de llegada y de salida de cada jornada'
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
        jornadas: jornadas,
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
                _bloqueJornadas(t),
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

  /// Horas del parte: una fila por día trabajado. La instalación puede
  /// ocupar varias jornadas y el tiempo total es la suma de todas.
  Widget _bloqueJornadas(TextTheme t) {
    final varias = _jornadas.length > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 128,
                child: Text(varias ? 'Jornadas' : 'Hora llegada / salida',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
              Expanded(
                child: Text(
                  _minutosTotal == 0
                      ? ''
                      : varias
                          ? '${formatoHoras(_minutosTotal)} · ${_jornadasCompletas.length} jornadas'
                          : formatoHoras(_minutosTotal),
                  style: t.bodySmall?.copyWith(
                      color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          for (final j in _jornadas) _filaJornada(t, j),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _anadirJornada,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir otro día'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaJornada(TextTheme t, Jornada j) {
    final min = j.minutos;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: _chip(_diaCorto.format(j.fecha), () => _elegirFecha(j),
                resaltado: false),
          ),
          const SizedBox(width: 6),
          _horaChip(j.horaInicio, () => _elegirHora(j, true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('—'),
          ),
          _horaChip(j.horaFinal, () => _elegirHora(j, false)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              min == null ? '' : formatoHoras(min),
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          if (_jornadas.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.errorFg),
              tooltip: 'Quitar este día',
              onPressed: () => _quitarJornada(j),
            ),
        ],
      ),
    );
  }

  Widget _horaChip(String valor, VoidCallback onTap) =>
      _chip(valor.isEmpty ? '__:__' : valor, onTap, resaltado: valor.isEmpty);

  /// Botón-etiqueta editable. [resaltado] lo marca en rojo cuando falta.
  Widget _chip(String texto, VoidCallback onTap, {required bool resaltado}) {
    return Material(
      color: resaltado ? AppColors.errorTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brSm,
        side: BorderSide(
            color: resaltado ? AppColors.errorFg : AppColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(texto,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: resaltado ? AppColors.errorFg : null)),
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
                  alTocar: () => _escribirCantidad(l),
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
  /// [alTocar] permite teclear la cantidad exacta: hay materiales que se
  /// miden en metros o kilos y no avanzan de uno en uno.
  Widget _stepper({
    required double valor,
    required ValueChanged<double> onChanged,
    bool compacto = false,
    VoidCallback? alTocar,
  }) {
    final Widget texto = Text(formatoCantidad(valor),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: compacto ? 14 : 16,
            fontWeight: FontWeight.bold,
            decoration: alTocar == null ? null : TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
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
        SizedBox(
          width: 30,
          child: alTocar == null
              ? texto
              : InkWell(
                  onTap: alTocar,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: texto),
                ),
        ),
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
  List<MaterialCatalogo> _masUsados = [];
  List<MaterialCatalogo> _resultados = [];
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
    final r = await context.read<MaterialesRepository>().buscarMateriales('');
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
    final r =
        await context.read<MaterialesRepository>().buscarMateriales(q.trim());
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

  Widget _item(MaterialCatalogo m) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(m),
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
                    Text(m.articulo.isEmpty ? 'SIN REF.' : m.articulo,
                        style: t.titleSmall?.copyWith(color: AppColors.primary)),
                    Text(m.descripcion, style: t.bodyMedium),
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
