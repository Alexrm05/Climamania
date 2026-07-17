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
    return ListView(
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
        const SizedBox(height: AppSpacing.md),
        _primaryButton('Continuar', _continuarDecision),
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

  Widget _firmaView() {
    final esRep = _tipoFirmante == 'representante_autorizado';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          '¿Quién firma?',
          RadioGroup<String>(
            groupValue: _tipoFirmante,
            onChanged: (v) => setState(() => _tipoFirmante = v ?? ''),
            child: Column(
              children: [
                const RadioListTile<String>(
                  value: 'cliente_titular',
                  title: Text('Cliente / titular del pedido'),
                ),
                const RadioListTile<String>(
                  value: 'representante_autorizado',
                  title: Text('Representante autorizado del cliente'),
                ),
                if (esRep) ...[
                  const SizedBox(height: 8),
                  _field('Nombre', _repNombreCtrl),
                  const SizedBox(height: 8),
                  _field('Apellidos', _repApellidosCtrl),
                  const SizedBox(height: 8),
                  _field('DNI', _repDniCtrl),
                ],
              ],
            ),
          ),
        ),
        _card('Observaciones (opcional)', Container(
          decoration: AppDecorations.editText,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _obsCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: AppDecorations.bareInput(
                contentPadding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        )),
        _card('Firma', Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: AppSpacing.xs),
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
        const SizedBox(height: AppSpacing.xs),
        _primaryButton('Aceptar y firmar', _processing ? null : _aceptar,
            loading: _processing),
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
