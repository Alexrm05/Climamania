import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/models/pedido.dart';
import '../../data/repositories/install_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

enum _Step { decision, series, firma }

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

  bool _requiereBoe = false;
  bool _revisionGuardada = false;

  // Series BOE
  List<BoeLinea> _lineas = [];
  bool _loadingSeries = false;
  bool _savingSeries = false;
  String _source = '';

  // Conformidad
  ConformidadCliente? _conformidad;
  String _tipoFirmante = ''; // 'cliente_titular' | 'representante_autorizado'
  final _repNombreCtrl = TextEditingController();
  final _repApellidosCtrl = TextEditingController();
  final _repDniCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  late final SignatureController _sig;
  bool _processing = false;

  String get _token =>
      '${widget.referencia}_${DateTime.now().millisecondsSinceEpoch}';
  String? _submissionToken;

  @override
  void initState() {
    super.initState();
    _sig = SignatureController(
      penStrokeWidth: 2.4,
      penColor: AppColors.primary,
      exportBackgroundColor: Colors.white,
    );
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
    _sig.dispose();
    super.dispose();
  }

  Future<void> _cargarConformidad() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (mounted && res.pedido != null) {
        setState(() => _conformidad = res.pedido!.conformidad);
      }
    } catch (_) {}
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // --- Paso decisión ---
  void _continuarDecision() {
    if (_requiereBoe) {
      setState(() => _step = _Step.series);
      _loadEquipos();
    } else {
      setState(() => _step = _Step.firma);
    }
  }

  // --- Paso series ---
  Future<void> _loadEquipos() async {
    setState(() => _loadingSeries = true);
    final res =
        await context.read<InstallRepository>().getBoeEquipos(widget.referencia);
    if (!mounted) return;
    setState(() {
      _lineas = res.lineas.isEmpty ? [BoeLinea()] : res.lineas;
      _source = res.source;
      _loadingSeries = false;
    });
  }

  Future<void> _guardarSeries() async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al guardar
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
    if (_tipoFirmante == 'cliente_titular') return true;
    if (_tipoFirmante == 'representante_autorizado') {
      return _repNombreCtrl.text.trim().isNotEmpty &&
          _repApellidosCtrl.text.trim().isNotEmpty &&
          _repDniCtrl.text.trim().isNotEmpty;
    }
    return false;
  }

  Future<void> _aceptar() async {
    FocusScope.of(context).unfocus(); // cerrar el teclado al aceptar
    if (!_firmanteValido) {
      _msg('Indica quién firma y completa sus datos');
      return;
    }
    if (_sig.isEmpty) {
      _msg('Falta la firma del cliente');
      return;
    }
    setState(() => _processing = true);
    final locationService = context.read<LocationService>();
    final session = context.read<SessionService>();
    final install = context.read<InstallRepository>();
    try {
      final pngBytes = await _sig.toPngBytes();
      if (pngBytes == null) {
        _msg('No se pudo procesar la firma');
        return;
      }
      final firmaBase64 = base64Encode(pngBytes);

      final loc = await locationService.capture();
      final usuario = session.displayName(fallback: 'Instalador');
      _submissionToken ??= _token;

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
        'requiere_boe': _requiereBoe ? 'true' : 'false',
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
      _submissionToken = conf.token;

      // 2) PDF BOE si aplica
      if (_requiereBoe && _revisionGuardada) {
        await install.generarBoePdf({
          'referencia': widget.referencia,
          'submission_token': _submissionToken!,
          'tipo_firmante': _tipoFirmante,
          'firmante_nombre': nombre,
          'firmante_apellidos': apellidos,
          'firmante_dni': dni,
          'firma_base64_png': firmaBase64,
          'usuario': usuario,
        });
      }

      // 3) Enviar documentación por email
      final (sent, sentMsg) = await install.enviarDocumentacion(
        referencia: widget.referencia,
        token: _submissionToken!,
        requiereBoe: _requiereBoe,
      );

      if (!mounted) return;
      _msg(sent ? sentMsg : 'Conforme firmado (envío de email pendiente)');
      context.pop();
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo completar el conforme');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(
        title: const Text('Conforme cliente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _Step.series) {
              setState(() => _step = _Step.decision);
            } else if (_step == _Step.firma && _requiereBoe) {
              setState(() => _step = _Step.series);
            } else if (_step == _Step.firma) {
              setState(() => _step = _Step.decision);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: switch (_step) {
        _Step.decision => _decisionView(),
        _Step.series => _seriesView(),
        _Step.firma => _firmaView(),
      },
    );
  }

  Widget _decisionView() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                '¿Requiere BOE?',
                RadioGroup<bool>(
                  groupValue: _requiereBoe,
                  onChanged: (v) => setState(() => _requiereBoe = v ?? false),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                          value: true, title: Text('Sí requiere BOE')),
                      RadioListTile<bool>(
                          value: false, title: Text('No requiere BOE')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _primaryButton('Continuar', _continuarDecision),
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
              if (_source.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                      'Origen: ${_source == 'revision' ? 'revisión guardada' : 'datos del pedido'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted)),
                ),
              for (var i = 0; i < _lineas.length; i++) _equipoRow(i),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => setState(() => _lineas.add(BoeLinea())),
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.brPill)),
                icon: const Icon(Icons.add),
                label: const Text('Añadir equipo'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _primaryButton('Guardar y continuar',
                _savingSeries ? null : _guardarSeries,
                loading: _savingSeries),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller:
                    TextEditingController(text: _lineas[i].codigo),
                onChanged: (v) => _lineas[i].codigo = v,
                decoration: const InputDecoration(
                    labelText: 'Código', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: TextField(
                controller:
                    TextEditingController(text: _lineas[i].numSerie),
                onChanged: (v) => _lineas[i].numSerie = v,
                decoration: const InputDecoration(
                    labelText: 'Nº serie', isDense: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.errorFg),
              onPressed: () => setState(() => _lineas.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }

  String _buildDocumentoTexto() {
    final c = _conformidad;
    final nombre =
        [c?.nombre ?? '', c?.apellidos ?? ''].where((e) => e.isNotEmpty).join(' ');
    final cpPob = [c?.cp ?? '', c?.poblacion ?? '']
        .where((e) => e.isNotEmpty)
        .join(' – ');
    final sb = StringBuffer();
    sb.writeln('D./Dña.: ${nombre.isNotEmpty ? nombre : '—'}');
    sb.writeln('DNI/NIF: ${c?.dni.isNotEmpty == true ? c!.dni : '—'}');
    sb.writeln('Dirección: ${c?.direccion.isNotEmpty == true ? c!.direccion : '—'}');
    sb.writeln('CP – Población: ${cpPob.isNotEmpty ? cpPob : '—'}');
    sb.writeln('Provincia: ${c?.provincia.isNotEmpty == true ? c!.provincia : '—'}');
    sb.writeln('Referencia del pedido: ${widget.referencia}');
    sb.writeln();
    sb.writeln('CLIMAMANIA SALES SPAIN S.L.');
    sb.writeln('CIF: B66040577');
    sb.writeln('C/ Electrónica 14');
    sb.writeln('08110 Montcada i Reixac (Barcelona)');
    sb.writeln('Tel.: 933 282 421');
    sb.writeln();
    sb.writeln(
        'Manifiesta mediante la firma del presente documento que CLIMAMANIA SALES SPAIN S.L. ha realizado la instalación en el domicilio situado en: '
        '${c?.direccionInstalacion.isNotEmpty == true ? c!.direccionInstalacion : '—'}');
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

  Widget _firmaView() {
    final esRep = _tipoFirmante == 'representante_autorizado';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                'Documento de conformidad',
                Text(
                  _buildDocumentoTexto(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _card('Observaciones', Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '(En este apartado podrán hacerse constar cualquier incidencia, trabajo pendiente o comentario por parte del instalador o del cliente.)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: AppDecorations.editText,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _obsCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: AppDecorations.bareInput(
                          hintText: 'Escribe las observaciones',
                          contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Firmado por:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  RadioGroup<String>(
                    groupValue: _tipoFirmante,
                    onChanged: (v) => setState(() => _tipoFirmante = v ?? ''),
                    child: Column(
                      children: [
                        const RadioListTile<String>(
                          value: 'cliente_titular',
                          title: Text('Cliente / titular del pedido'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const RadioListTile<String>(
                          value: 'representante_autorizado',
                          title: Text('Representante autorizado del cliente'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (esRep) ...[
                          const SizedBox(height: 8),
                          _field('Nombre', _repNombreCtrl),
                          const SizedBox(height: 8),
                          _field('Apellidos', _repApellidosCtrl),
                          const SizedBox(height: 8),
                          _field('DNI', _repDniCtrl),
                          const SizedBox(height: 10),
                          Text(
                            'En caso de firmar en representación del cliente: La persona firmante declara que actúa en nombre o con la autorización del cliente indicado en el presente documento, y que firma tras haber revisado la instalación y prestar su conformidad con los trabajos realizados.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )),
              _card('Firma', Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Y para que así conste, y en prueba de conformidad, se firma el presente documento mediante firma manuscrita electrónica en dispositivo digital, quedando registrada la fecha y hora de la firma.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Declaro haber leído el documento y estar conforme con su contenido antes de firmar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Firma manuscrita electrónica:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: AppRadius.brMd,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Signature(
                        controller: _sig, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _sig.clear()),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                        foregroundColor: AppColors.primaryDark,
                      ),
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar firma'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'D./Dña.: ________________________________',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DNI/NIF: ________________________________',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _primaryButton(
              'Aceptar y firmar',
              _processing ? null : _aceptar,
              loading: _processing,
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        decoration: AppDecorations.bareInput(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
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

  /// Botón principal (verde) en píldora, con spinner opcional.
  Widget _primaryButton(String label, VoidCallback? onTap,
      {bool loading = false, double height = 50}) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.confirm,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brPill)),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white))
            : Text(label),
      ),
    );
  }
}
