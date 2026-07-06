import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import '../../core/ui_text.dart';
import '../../data/models/pedido.dart';
import '../../data/repositories/install_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

enum _Step { decision, series, firma }

/// Fuerza mayúsculas en la entrada (equivalente a textCapCharacters de Android).
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Datos de conformidad renderizables (réplica de ConformidadData de Android).
class _ConformidadData {
  String referencia = '';
  String clienteCabecera = '';
  String nombre = '';
  String apellidos = '';
  String dni = '';
  String direccion = '';
  String cp = '';
  String poblacion = '';
  String provincia = '';
  String direccionInstalacion = '';
}

/// Flujo "Firma conforme cliente" en una sola pantalla con pasos internos:
/// decisión BOE → (revisión de series) → firma + generación de PDF.
class ConformeScreen extends StatefulWidget {
  final String referencia;
  final String cliente;

  const ConformeScreen(
      {super.key, required this.referencia, this.cliente = ''});

  @override
  State<ConformeScreen> createState() => _ConformeScreenState();
}

class _ConformeScreenState extends State<ConformeScreen> {
  _Step _step = _Step.decision;

  // Decisión BOE: null hasta que el usuario elija (sin preselección).
  bool? _requiereBoe;
  bool _revisionGuardada = false;

  // Series BOE
  List<BoeLinea> _lineas = [];
  final List<TextEditingController> _codigoCtrls = [];
  final List<TextEditingController> _numSerieCtrls = [];
  bool _loadingSeries = false;
  bool _savingSeries = false;
  String _source = '';

  // Conformidad
  _ConformidadData? _conformidad;
  String _cliente = '';
  String _tipoFirmante = ''; // 'cliente_titular' | 'representante_autorizado'
  final _repNombreCtrl = TextEditingController();
  final _repApellidosCtrl = TextEditingController();
  final _repDniCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  late final SignatureController _sig;
  bool _processing = false;

  String? _submissionToken;

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    _sig = SignatureController(
      penStrokeWidth: 2.4,
      penColor: const Color(0xFF1565C0),
      exportBackgroundColor: Colors.white,
    );
    _sig.addListener(() {
      if (mounted) setState(() {});
    });
    // Dev: previsualizar directamente un paso concreto.
    if (const String.fromEnvironment('CONFORME_STEP') == 'firma') {
      _step = _Step.firma;
    }
    _cargarConformidad();
  }

  @override
  void dispose() {
    _repNombreCtrl.dispose();
    _repApellidosCtrl.dispose();
    _repDniCtrl.dispose();
    _obsCtrl.dispose();
    for (final c in _codigoCtrls) {
      c.dispose();
    }
    for (final c in _numSerieCtrls) {
      c.dispose();
    }
    _sig.dispose();
    super.dispose();
  }

  String _s(String? v) => UiText.sanitizeDbValue(v);

  String _buildClientFullName(String nombre, String apellidos) {
    final n = _s(nombre);
    final a = _s(apellidos);
    return _s('$n $a'.trim());
  }

  String _buildCpPoblacion(String cp, String poblacion) {
    final c = _s(cp);
    final p = _s(poblacion);
    if (c.isEmpty) return p;
    if (p.isEmpty) return c;
    return '$c - $p';
  }

  String _displayLine(String value) {
    final c = _s(value);
    return c.isEmpty ? '__________________________________' : c;
  }

  bool _hasRenderableConformidad(_ConformidadData? d) {
    if (d == null) return false;
    return _buildClientFullName(d.nombre, d.apellidos).isNotEmpty &&
        d.direccionInstalacion.isNotEmpty;
  }

  /// Construye los datos renderizables desde el Pedido, con fallback a
  /// facturación (réplica de parseConformidadData de Android).
  _ConformidadData _buildData(Pedido pedido) {
    final data = _ConformidadData();
    data.referencia =
        pedido.referencia.isNotEmpty ? pedido.referencia : widget.referencia;
    data.clienteCabecera =
        pedido.cliente.isNotEmpty ? pedido.cliente : _cliente;

    final c = pedido.conformidad;
    if (c != null) {
      data.nombre = c.nombre;
      data.apellidos = c.apellidos;
      data.dni = c.dni;
      data.direccion = c.direccion;
      data.cp = c.cp;
      data.poblacion = c.poblacion;
      data.provincia = c.provincia;
      data.direccionInstalacion = c.direccionInstalacion;
    }

    // Fallback a facturación si no hay nombre/apellidos.
    if (data.nombre.isEmpty && data.apellidos.isEmpty) {
      final fact = pedido.facturacion;
      if (fact != null) {
        if (fact.nombre.isNotEmpty) data.nombre = fact.nombre;
        data.direccion = fact.direccion;
        final poblacionFact = _s(fact.poblacion);
        if (poblacionFact.isNotEmpty) {
          final parts = poblacionFact.split('-');
          if (parts.isNotEmpty) data.cp = _s(parts[0]);
          if (parts.length > 1) data.poblacion = _s(parts.sublist(1).join('-'));
        }
      }
    }
    if (data.direccionInstalacion.isEmpty) {
      data.direccionInstalacion = pedido.direccionInstalacion;
    }
    if (data.clienteCabecera.isEmpty) {
      data.clienteCabecera = _buildClientFullName(data.nombre, data.apellidos);
    }
    if (data.referencia.isEmpty) data.referencia = widget.referencia;
    return data;
  }

  Future<void> _cargarConformidad() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (!mounted) return;
      if (!res.ok || res.pedido == null) {
        _msg(res.message.isEmpty
            ? 'No se pudo cargar la conformidad'
            : res.message);
        return;
      }
      final data = _buildData(res.pedido!);
      setState(() {
        _conformidad = data;
        if (data.clienteCabecera.isNotEmpty) _cliente = data.clienteCabecera;
      });
    } catch (_) {
      if (mounted) _msg('No se pudo cargar la conformidad');
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // --- Paso decisión ---
  void _continuarDecision() {
    if (_requiereBoe == null) {
      _msg('Debes indicar si requiere BOE');
      return;
    }
    if (_requiereBoe!) {
      setState(() => _step = _Step.series);
      _loadEquipos();
    } else {
      setState(() => _step = _Step.firma);
    }
  }

  // --- Paso series ---
  void _syncRowControllers() {
    while (_codigoCtrls.length < _lineas.length) {
      _codigoCtrls.add(TextEditingController());
      _numSerieCtrls.add(TextEditingController());
    }
    while (_codigoCtrls.length > _lineas.length) {
      _codigoCtrls.removeLast().dispose();
      _numSerieCtrls.removeLast().dispose();
    }
    for (var i = 0; i < _lineas.length; i++) {
      if (_codigoCtrls[i].text != _lineas[i].codigo) {
        _codigoCtrls[i].text = _lineas[i].codigo;
      }
      if (_numSerieCtrls[i].text != _lineas[i].numSerie) {
        _numSerieCtrls[i].text = _lineas[i].numSerie;
      }
    }
  }

  Future<void> _loadEquipos() async {
    setState(() => _loadingSeries = true);
    final res =
        await context.read<InstallRepository>().getBoeEquipos(widget.referencia);
    if (!mounted) return;
    if (!res.ok) {
      _msg('No se pudo cargar la revisión BOE');
    }
    setState(() {
      _lineas = res.lineas.isEmpty ? [BoeLinea()] : res.lineas;
      _source = res.source;
      _loadingSeries = false;
      _syncRowControllers();
    });
  }

  void _addLinea() {
    setState(() {
      _lineas.add(BoeLinea());
      _syncRowControllers();
    });
  }

  void _removeLinea(int i) {
    setState(() {
      _lineas.removeAt(i);
      _syncRowControllers();
    });
  }

  Future<void> _guardarSeries() async {
    setState(() => _savingSeries = true);
    final session = context.read<SessionService>();
    final (ok, msg) = await context.read<InstallRepository>().guardarBoeEquipos(
          referencia: widget.referencia,
          usuario: session.displayName(fallback: 'Instalador'),
          lineas: _lineas,
        );
    if (!mounted) return;
    setState(() => _savingSeries = false);
    if (ok) {
      setState(() {
        _revisionGuardada = true;
        _step = _Step.firma;
      });
    } else {
      _msg(msg);
    }
  }

  // --- Paso firma ---
  bool get _firmanteValido {
    if (!_hasRenderableConformidad(_conformidad)) return false;
    if (_tipoFirmante == 'cliente_titular') return true;
    if (_tipoFirmante == 'representante_autorizado') {
      return _repNombreCtrl.text.trim().isNotEmpty &&
          _repApellidosCtrl.text.trim().isNotEmpty &&
          _repDniCtrl.text.trim().isNotEmpty;
    }
    return false;
  }

  void _onTipoFirmanteChanged(String v) {
    setState(() {
      _tipoFirmante = v;
      _sig.clear();
    });
  }

  void _onRepFieldChanged() {
    setState(() {
      if (_tipoFirmante == 'representante_autorizado') _sig.clear();
    });
  }

  /// Exporta la firma con el tamaño COMPLETO del pad sobre fondo blanco, en
  /// lugar de recortar al bounding box.
  Future<Uint8List?> _exportFirma() async {
    // Dimensiones del pad tal y como se pinta (ancho responsivo, alto fijo 220).
    final int w = _padWidth.round();
    const int h = 220;
    // El paquete exige que width/height sean >= al bounding box real.
    try {
      return await _sig.toPngBytes(width: w, height: h);
    } catch (_) {
      // Si el trazo excede las dimensiones dadas, recae en el export normal.
      return _sig.toPngBytes();
    }
  }

  double _padWidth = 300;

  Future<void> _aceptar() async {
    if (!_firmanteValido) {
      if (!_hasRenderableConformidad(_conformidad)) {
        _msg('Todavía no se han cargado los datos de conformidad');
      } else if (_tipoFirmante.isEmpty) {
        _msg('Debes indicar quién firma');
      } else {
        _msg('Debes completar nombre, apellidos y DNI del representante');
      }
      return;
    }
    if (_sig.isEmpty) {
      _msg('Debes recoger la firma manuscrita');
      return;
    }
    setState(() => _processing = true);
    final locationService = context.read<LocationService>();
    final session = context.read<SessionService>();
    final install = context.read<InstallRepository>();
    try {
      final pngBytes = await _exportFirma();
      if (pngBytes == null) {
        _msg('No se pudo procesar la firma');
        return;
      }
      final firmaBase64 = base64Encode(pngBytes);

      final loc = await locationService.capture();
      final usuario = session.displayName(fallback: 'Instalador');
      _submissionToken ??= const Uuid().v4();

      final requiereBoe = _requiereBoe ?? false;
      final esTitular = _tipoFirmante == 'cliente_titular';
      final nombre = esTitular
          ? (_conformidad?.nombre ?? '')
          : _repNombreCtrl.text.trim();
      final apellidos = esTitular
          ? (_conformidad?.apellidos ?? '')
          : _repApellidosCtrl.text.trim();
      final dni =
          esTitular ? (_conformidad?.dni ?? '') : _repDniCtrl.text.trim();

      // 1) PDF de conformidad
      final conf = await install.generarConformePdf({
        'referencia': widget.referencia,
        'requiere_boe': requiereBoe ? 'true' : 'false',
        'revision_boe_guardada': _revisionGuardada ? 'true' : 'false',
        'observaciones_conformidad': _obsCtrl.text.trim(),
        'tipo_firmante': _tipoFirmante,
        'firmante_nombre': nombre,
        'firmante_apellidos': apellidos,
        'firmante_dni': dni,
        'firma_base64_png': firmaBase64,
        'latitud': loc.latParam,
        'longitud': loc.lngParam,
        'usuario': usuario,
        'submission_token': _submissionToken!,
      });
      if (!conf.ok) {
        _msg(conf.message.isEmpty ? 'No se pudo generar el PDF' : conf.message);
        return;
      }
      // Android bloquea el envío si el PDF de conformidad no se generó.
      if (conf.pdf.isEmpty) {
        _msg('Falta el documento de conformidad firmado');
        return;
      }
      _submissionToken = conf.token;

      // 2) PDF BOE si aplica. Si falla, avisar y NO enviar documentación.
      final generaBoe = requiereBoe && _revisionGuardada;
      if (generaBoe) {
        final boe = await install.generarBoePdf({
          'referencia': widget.referencia,
          'submission_token': _submissionToken!,
          'tipo_firmante': _tipoFirmante,
          'firmante_nombre': nombre,
          'firmante_apellidos': apellidos,
          'firmante_dni': dni,
          'firma_base64_png': firmaBase64,
          'usuario': usuario,
        });
        if (!boe.ok) {
          if (!mounted) return;
          await _dialogoError(
            'Error al generar el BOE',
            'PDF de conformidad generado.\n\n${boe.message.isEmpty ? 'No se pudo generar el PDF BOE' : boe.message}',
          );
          return;
        }
        // El BOE es obligatorio para esta instalación: no enviar sin él.
        if (boe.pdf.isEmpty) {
          if (!mounted) return;
          await _dialogoError(
            'Falta el documento BOE',
            'Falta el documento BOE obligatorio para esta instalación.',
          );
          return;
        }
      }

      // 3) Enviar documentación por email
      final envio = await install.enviarDocumentacion(
        referencia: widget.referencia,
        token: _submissionToken!,
        requiereBoe: requiereBoe,
      );

      if (!mounted) return;
      if (envio.ok) {
        _msg(envio.destinatarioCliente.isNotEmpty
            ? 'Documentación enviada a ${envio.destinatarioCliente}'
            : envio.message);
      } else {
        _msg(envio.message);
      }
      context.pop();
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo completar el conforme');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _dialogoError(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      onReload: _cargarConformidad,
      child: switch (_step) {
        _Step.decision => _decisionView(),
        _Step.series => _seriesView(),
        _Step.firma => _firmaView(),
      },
    );
  }

  Widget _cabecera(String subtitulo) {
    return Container(
      decoration: AppDecorations.detailHero,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 14),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Firma conforme cliente',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text(_displayLine(widget.referencia),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          if (_cliente.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_cliente,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary)),
            ),
          if (subtitulo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(subtitulo,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6D4C41))),
            ),
        ],
      ),
    );
  }

  Widget _decisionView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cabecera(''),
        _card(
          '¿La instalación requiere BOE?',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona una opción para continuar con el flujo correspondiente en la siguiente fase.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 8),
              RadioGroup<bool>(
                groupValue: _requiereBoe,
                onChanged: (v) => setState(() => _requiereBoe = v),
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                        value: true, title: Text('Sí requiere BOE')),
                    RadioListTile<bool>(
                        value: false, title: Text('No requiere BOE')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _requiereBoe == null ? null : _continuarDecision,
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }

  Widget _seriesView() {
    if (_loadingSeries) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cabecera(
                  'Revisa los equipos y números de serie antes de continuar.'),
              if (_source.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Fuente: ${_source == 'revision' ? 'revisión guardada' : 'base del pedido'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              if (_lineas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No hay equipos cargados todavía.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              for (var i = 0; i < _lineas.length; i++) _equipoRow(i),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addLinea,
                icon: const Icon(Icons.add),
                label: const Text('Añadir equipo'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _savingSeries ? null : _guardarSeries,
                child: _savingSeries
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : const Text('Guardar y continuar'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _equipoRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: AppDecorations.whiteCard,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _codigoCtrls[i],
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_UpperCaseTextFormatter()],
                onChanged: (v) => _lineas[i].codigo = v,
                decoration: const InputDecoration(
                    labelText: 'Código', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: TextField(
                controller: _numSerieCtrls[i],
                onChanged: (v) => _lineas[i].numSerie = v,
                decoration: const InputDecoration(
                    labelText: 'Número de serie', isDense: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB00020)),
              onPressed: () => _removeLinea(i),
            ),
          ],
        ),
      ),
    );
  }

  Widget _firmaView() {
    final esRep = _tipoFirmante == 'representante_autorizado';
    final firmaHabilitada = _firmanteValido;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cabecera(''),
        // Documento legal completo.
        _card(
          'Documento de conformidad',
          Text(
            _conformidad != null
                ? _buildDocumentText(_conformidad!)
                : 'Cargando documento...',
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: Color(0xFF243241)),
          ),
        ),
        _card(
          'Observaciones',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '(En este apartado podrán hacerse constar cualquier incidencia, trabajo pendiente o comentario por parte del instalador o del cliente.)',
                style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: AppDecorations.editText,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _obsCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      hintText: 'Escribe las observaciones',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ],
          ),
        ),
        _card(
          'Firmado por:',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: _tipoFirmante.isEmpty ? null : _tipoFirmante,
                onChanged: (v) => _onTipoFirmanteChanged(v ?? ''),
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      value: 'cliente_titular',
                      contentPadding: EdgeInsets.zero,
                      title: Text('Cliente / titular del pedido'),
                    ),
                    RadioListTile<String>(
                      value: 'representante_autorizado',
                      contentPadding: EdgeInsets.zero,
                      title: Text('Representante autorizado del cliente'),
                    ),
                  ],
                ),
              ),
              if (esRep) ...[
                const SizedBox(height: 8),
                _field('Nombre', _repNombreCtrl),
                const SizedBox(height: 8),
                _field('Apellidos', _repApellidosCtrl),
                const SizedBox(height: 8),
                _field('DNI', _repDniCtrl),
                const SizedBox(height: 10),
                const Text(
                  'En caso de firmar en representación del cliente: La persona firmante declara que actúa en nombre o con la autorización del cliente indicado en el presente documento, y que firma tras haber revisado la instalación y prestar su conformidad con los trabajos realizados.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
                ),
              ],
            ],
          ),
        ),
        _card(
          'Firma',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Y para que así conste, y en prueba de conformidad, se firma el presente documento mediante firma manuscrita electrónica en dispositivo digital, quedando registrada la fecha y hora de la firma.',
                style: TextStyle(fontSize: 14, color: Color(0xFF243241)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Declaro haber leído el documento y estar conforme con su contenido antes de firmar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(height: 14),
              const Text(
                'Firma manuscrita electrónica:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF243241)),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: firmaHabilitada ? 1 : 0.45,
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    _padWidth = constraints.maxWidth;
                    return Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardStroke),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IgnorePointer(
                        ignoring: !firmaHabilitada,
                        child: Signature(
                            controller: _sig,
                            backgroundColor: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: (firmaHabilitada && _sig.isNotEmpty)
                      ? () => setState(() => _sig.clear())
                      : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar firma'),
                ),
              ),
              const SizedBox(height: 6),
              Text('D./Dña.: ${_displayLine(_firmaPieNombre())}',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF243241))),
              const SizedBox(height: 6),
              Text('DNI/NIF: ${_displayLine(_firmaPieDni())}',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF243241))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed:
                (_processing || !firmaHabilitada || _sig.isEmpty)
                    ? null
                    : _aceptar,
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : const Text('Aceptar'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _processing ? null : () => context.pop(),
            child: const Text('Volver'),
          ),
        ),
      ],
    );
  }

  String _firmaPieNombre() {
    if (_tipoFirmante == 'representante_autorizado') {
      return _buildClientFullName(
          _repNombreCtrl.text.trim(), _repApellidosCtrl.text.trim());
    }
    if (_tipoFirmante == 'cliente_titular') {
      return _conformidad != null
          ? _buildClientFullName(_conformidad!.nombre, _conformidad!.apellidos)
          : '';
    }
    return '';
  }

  String _firmaPieDni() {
    if (_tipoFirmante == 'representante_autorizado') {
      return _repDniCtrl.text.trim();
    }
    if (_tipoFirmante == 'cliente_titular') {
      return _conformidad?.dni ?? '';
    }
    return '';
  }

  String _buildDocumentText(_ConformidadData d) {
    final sb = StringBuffer();
    sb.writeln(
        'D./Dña.: ${_displayLine(_buildClientFullName(d.nombre, d.apellidos))}');
    sb.writeln('DNI/NIF: ${_displayLine(d.dni)}');
    sb.writeln('Dirección: ${_displayLine(d.direccion)}');
    sb.writeln(
        'CP – Población: ${_displayLine(_buildCpPoblacion(d.cp, d.poblacion))}');
    sb.writeln('Provincia: ${_displayLine(d.provincia)}');
    sb.writeln('Referencia del pedido: ${_displayLine(d.referencia)}');
    sb.writeln();
    sb.writeln('CLIMAMANIA SALES SPAIN S.L.');
    sb.writeln('CIF: B66040577');
    sb.writeln('C/ Electrónica 14');
    sb.writeln('08110 Montcada i Reixac (Barcelona)');
    sb.writeln('Tel.: 933 282 421');
    sb.writeln();
    sb.write(
        'Manifiesta mediante la firma del presente documento que CLIMAMANIA SALES SPAIN S.L. ha realizado la instalación en el domicilio situado en: ');
    sb.writeln(_displayLine(d.direccionInstalacion));
    sb.writeln();
    sb.writeln('La persona firmante declara que:');
    sb.writeln(
        '• La instalación ha sido finalizada conforme al presupuesto o encargo previamente aceptado.');
    sb.writeln(
        '• Ha podido revisar la instalación en presencia del personal instalador, comprobando el estado de los equipos y materiales suministrados.');
    sb.writeln(
        '• La instalación se encuentra terminada y correctamente ejecutada, no quedando trabajos pendientes por parte de CLIMAMANIA SALES SPAIN S.L., salvo aquellos que, en su caso, queden reflejados expresamente en el apartado de observaciones.');
    sb.writeln(
        '• Se encuentra conforme con la ubicación de los equipos instalados, el trazado de las canalizaciones, perforaciones, soportes, canaletas y demás elementos necesarios para la instalación.');
    sb.writeln(
        '• Los equipos instalados se encuentran en correcto estado y funcionamiento, o preparados para su puesta en marcha según corresponda al tipo de instalación realizada.');
    sb.writeln();
    sb.writeln(
        'La persona firmante declara que ha revisado la instalación en presencia del instalador, no apreciando defectos visibles en el momento de la firma y prestando su conformidad con los trabajos realizados y el resultado final de la instalación.');
    sb.writeln();
    sb.writeln(
        'La firma del presente documento implica la aceptación de la instalación realizada, por lo que cualquier reclamación posterior deberá referirse exclusivamente a defectos ocultos o incidencias no apreciables en el momento de la revisión y firma, salvo las que se hagan constar expresamente en el apartado de observaciones.');
    sb.writeln();
    sb.write(
        'Asimismo, el cliente queda informado de que determinados equipos pueden requerir puesta en marcha, sellado de garantía o intervención del servicio técnico oficial del fabricante.');
    return sb.toString();
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => _onRepFieldChanged(),
        decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
}
