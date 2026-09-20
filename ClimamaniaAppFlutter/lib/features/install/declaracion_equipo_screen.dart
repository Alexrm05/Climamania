import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../data/models/pedido.dart';
import '../../data/models/retirada_equipo.dart';
import '../../data/repositories/install_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Firma de la "Declaración del cliente sobre equipo desinstalado".
///
/// Se abre desde el apartado de retirada cuando el cliente NO permite retirar
/// el equipo completo. El cliente lee el texto, se comprueban sus datos y
/// firma; el servidor genera el PDF y lo vincula al pedido. Devuelve `true`
/// por [Navigator.pop] cuando el documento ha quedado generado.
class DeclaracionEquipoScreen extends StatefulWidget {
  final String referencia;

  /// Claves de [ComponenteConservado] marcadas en el apartado.
  final List<String> elementos;
  final String otrosDetalle;

  const DeclaracionEquipoScreen({
    super.key,
    required this.referencia,
    required this.elementos,
    this.otrosDetalle = '',
  });

  @override
  State<DeclaracionEquipoScreen> createState() =>
      _DeclaracionEquipoScreenState();
}

class _DeclaracionEquipoScreenState extends State<DeclaracionEquipoScreen> {
  ConformidadCliente? _cliente;
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  late final SignatureController _sig;
  bool _leido = false;
  bool _processing = false;

  String get _token =>
      '${widget.referencia}_DECLEQ_${DateTime.now().millisecondsSinceEpoch}';
  String? _submissionToken;

  @override
  void initState() {
    super.initState();
    _sig = SignatureController(
      penStrokeWidth: 2.4,
      penColor: AppColors.primary,
      exportBackgroundColor: Colors.white,
    );
    _cargarCliente();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _sig.dispose();
    super.dispose();
  }

  /// Datos del titular del pedido para rellenar nombre y DNI. Se pueden
  /// editar por si firma otra persona del domicilio.
  Future<void> _cargarCliente() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      final c = res.pedido?.conformidad;
      if (mounted && c != null) {
        setState(() {
          _cliente = c;
          if (_nombreCtrl.text.isEmpty) {
            _nombreCtrl.text = '${c.nombre} ${c.apellidos}'.trim();
          }
          if (_dniCtrl.text.isEmpty) _dniCtrl.text = c.dni;
        });
      }
    } catch (_) {}
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  List<String> get _lineasElementos {
    final etiquetas = {
      for (final c in ComponenteConservado.todos) c.clave: c.etiqueta
    };
    return [
      for (final clave in widget.elementos)
        if (clave == ComponenteConservado.otros.clave &&
            widget.otrosDetalle.trim().isNotEmpty)
          '${etiquetas[clave]}: ${widget.otrosDetalle.trim()}'
        else
          etiquetas[clave] ?? clave,
    ];
  }

  Future<void> _firmar() async {
    FocusScope.of(context).unfocus();
    if (_nombreCtrl.text.trim().isEmpty || _dniCtrl.text.trim().isEmpty) {
      _msg('Indica el nombre y el DNI/NIF de quien firma');
      return;
    }
    if (!_leido) {
      _msg('El cliente debe confirmar que ha leído la declaración');
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
      final loc = await locationService.capture();
      _submissionToken ??= _token;

      final res = await install.generarDeclaracionEquipoPdf({
        'referencia': widget.referencia,
        'elementos': jsonEncode(widget.elementos),
        'otros_detalle': widget.otrosDetalle.trim(),
        'firmante_nombre': _nombreCtrl.text.trim(),
        'firmante_dni': _dniCtrl.text.trim(),
        'firma_base64_png': base64Encode(pngBytes),
        'latitud': loc.latParam,
        'longitud': loc.lngParam,
        'usuario': session.displayName(fallback: 'Instalador'),
        'submission_token': _submissionToken!,
      });
      if (!res.ok) {
        _msg(res.message.isEmpty
            ? 'No se pudo generar la declaración'
            : res.message);
        return;
      }
      _submissionToken = res.token;
      if (!mounted) return;
      _msg('Declaración firmada y guardada');
      context.pop(true);
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo completar la declaración');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Declaración del cliente')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _aviso(t),
                _card(
                  'Datos del cliente',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dato('Dirección', _cliente?.direccion ?? ''),
                      _dato(
                          'Población',
                          '${_cliente?.cp ?? ''} ${_cliente?.poblacion ?? ''}'
                              .trim()),
                      _dato('Pedido', widget.referencia),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Firma en nombre del cliente:',
                          style: t.bodySmall
                              ?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      _field('Nombre y apellidos', _nombreCtrl),
                      const SizedBox(height: 8),
                      _field('DNI/NIF', _dniCtrl),
                    ],
                  ),
                ),
                _card(
                  'Elementos que conserva el cliente',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final linea in _lineasElementos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_box,
                                  size: 18, color: AppColors.successFg),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(linea,
                                      style: t.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _card(
                  'Declaración',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, p) in _parrafos.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Text(p, style: t.bodySmall),
                      ],
                    ],
                  ),
                ),
                _card(
                  'Firma del cliente',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: _leido,
                        onChanged: (v) => setState(() => _leido = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'He leído la declaración y confirmo que la decisión de conservar los elementos indicados es mía.',
                          style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Firma manuscrita electrónica:',
                          style: t.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.brMd),
                            foregroundColor: AppColors.primaryDark,
                          ),
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar firma'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'La firma queda registrada con fecha, hora y posición GPS, y el documento se vincula al pedido.',
                        style:
                            t.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _processing ? null : _firmar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.confirm,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brPill)),
                  child: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : const Text('Aceptar y firmar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mismo texto que imprime el PDF, para que el cliente lea lo que firma.
  static const _parrafos = [
    'El cliente manifiesta expresamente que, por decisión propia, ha solicitado que CLIMAMANIA SALES SPAIN S.L. no retire total o parcialmente el equipo de climatización objeto del servicio de desmontaje, y solicita conservar bajo su responsabilidad los elementos indicados.',
    'El cliente declara haber sido informado de que el servicio contratado contempla la retirada del equipo completo para su posterior gestión y reciclaje y que la conservación total o parcial del mismo se realiza por petición expresa del propio cliente.',
    'Asimismo, el cliente queda expresamente informado de que los equipos de climatización pueden contener gases fluorados y otros elementos sujetos a requisitos específicos de manipulación, recuperación y gestión, y que cualquier intervención sobre el circuito frigorífico deberá ser realizada por personal debidamente certificado/habilitado conforme a la normativa vigente.',
    'El cliente se compromete a no manipular, desmontar, cortar, abrir o intervenir el circuito frigorífico por sus propios medios ni permitir que lo haga personal que no disponga de la correspondiente certificación/habilitación.',
    'CLIMAMANIA SALES SPAIN S.L. no se responsabilizará de las manipulaciones, desmontajes, reutilizaciones o gestión posterior que puedan realizarse sobre los componentes que, por petición expresa del cliente, permanezcan en su poder.',
    'Con su firma, el cliente confirma que la decisión de conservar los elementos anteriormente indicados ha sido adoptada expresamente por él y que dichos elementos han quedado efectivamente en su poder en el domicilio indicado.',
  ];

  Widget _aviso(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningTint,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.warningFg, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warningFg, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'EQUIPO NO RETIRADO COMPLETAMENTE — este documento debe leerlo y firmarlo el cliente.',
                style: t.titleSmall?.copyWith(
                    color: AppColors.warningFg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(String label, String value) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text('$label:',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: t.bodySmall)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.words,
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
}
