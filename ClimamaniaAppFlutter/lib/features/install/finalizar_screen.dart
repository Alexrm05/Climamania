import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/install_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

/// Formulario de finalización de la instalación. Réplica de FinalizarInstalacionActivity.
class FinalizarScreen extends StatefulWidget {
  final String referencia;

  const FinalizarScreen({super.key, required this.referencia});

  @override
  State<FinalizarScreen> createState() => _FinalizarScreenState();
}

class _FinalizarScreenState extends State<FinalizarScreen> {
  final _metalicoCtrl = TextEditingController();
  final _visaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  String _extras = ''; // '', 'si', 'no'
  int _satisfaccion = 0;
  bool _submitting = false;

  // Fotos requeridas que faltan.
  List<String> _faltan = [];
  bool _fotosCargadas = false;
  String _errorFotos = '';

  @override
  void initState() {
    super.initState();
    _cargarFotosFaltantes();
  }

  @override
  void dispose() {
    _metalicoCtrl.dispose();
    _visaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFotosFaltantes() async {
    try {
      final res =
          await context.read<PedidoRepository>().getPedido(widget.referencia);
      if (!mounted) return;
      if (!res.ok) {
        setState(() {
          _errorFotos = res.message.isEmpty
              ? 'No se pudo cargar el pedido'
              : res.message;
          _fotosCargadas = true;
        });
        return;
      }
      if (res.pedido == null) {
        setState(() {
          _errorFotos = 'Pedido sin datos';
          _fotosCargadas = true;
        });
        return;
      }
      final faltan = <String>[];
      final f = res.pedido!.fotografias;
      if (f.previas.isEmpty) faltan.add('Faltan fotos previas a la instalación');
      if (f.acabada.isEmpty) faltan.add('Faltan fotos instalación acabada');
      if (f.conforme.isEmpty) faltan.add('Faltan fotos conforme cliente');
      setState(() {
        _faltan = faltan;
        _errorFotos = '';
        _fotosCargadas = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorFotos = 'Error de conexión al cargar las fotos';
          _fotosCargadas = true;
        });
      }
    }
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _finalizar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar instalación'),
        content: const Text(
            '¿Confirmas que quieres finalizar esta instalación? Se registrará tu ubicación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    final locationService = context.read<LocationService>();
    final session = context.read<SessionService>();
    final install = context.read<InstallRepository>();
    try {
      final loc = await locationService.capture();
      // Réplica de getTextValue(edit, "0"): vacío → '0', coma → punto.
      String money(TextEditingController c) {
        final v = c.text.trim();
        return (v.isEmpty ? '0' : v).replaceAll(',', '.');
      }

      final payload = {
        'referencia': widget.referencia,
        'usuario': session.displayName(fallback: 'Instalador'),
        'cobroMetalico': money(_metalicoCtrl),
        'cobroVisa': money(_visaCtrl),
        'extras': _extras,
        // Android envía siempre el entero del rating (0 si no se valoró).
        'satisfaccion': '$_satisfaccion',
        'observaciones': _obsCtrl.text.trim(),
        'latitud': loc.latParam,
        'longitud': loc.lngParam,
      };
      final (ok, msg) = await install.finalizar(payload);
      if (!mounted) return;
      _msg(msg);
      if (ok) context.pop();
    } on LocationException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('No se pudo finalizar la instalación');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      onReload: _cargarFotosFaltantes,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Referencia ${widget.referencia}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                if (_fotosCargadas) _avisoFotos(),
          _card('Cobro', Column(
            children: [
              _money('Cobro en metálico (€)', _metalicoCtrl),
              const SizedBox(height: 10),
              _money('Cobro con tarjeta (€)', _visaCtrl),
            ],
          )),
          _card(
            '¿Se añadieron extras?',
            RadioGroup<String>(
              groupValue: _extras,
              onChanged: (v) => setState(() => _extras = v ?? ''),
              child: Row(
                children: [
                  _radio('Sí', 'si'),
                  const SizedBox(width: 16),
                  _radio('No', 'no'),
                ],
              ),
            ),
          ),
          _card('Satisfacción del cliente', _stars()),
          _card('Observaciones finales', Container(
            decoration: AppDecorations.editText,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _obsCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Observaciones...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
                )),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _finalizar,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.white))
                            : const Text('Finalizar ahora'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.primaryDark),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text('Volver'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoFotos() {
    // Estado de error explícito: si falló la carga, no mostrar verde.
    final hayError = _errorFotos.isNotEmpty;
    final completas = !hayError && _faltan.isEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completas ? const Color(0xFFEEF8F0) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: completas
                ? const Color(0xFF70AE7D)
                : const Color(0xFFE28C8C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hayError
            ? [
                Text(_errorFotos,
                    style: const TextStyle(
                        color: Color(0xFF7A2F2F),
                        fontWeight: FontWeight.bold)),
              ]
            : completas
                ? const [
                    Text('Fotografías completas',
                        style: TextStyle(
                            color: Color(0xFF2D613A),
                            fontWeight: FontWeight.bold))
                  ]
                : [
                    for (final f in _faltan)
                      Text('• $f',
                          style: const TextStyle(color: Color(0xFF7A2F2F))),
                  ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
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

  Widget _money(String label, TextEditingController ctrl) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _radio(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(value: value),
        Text(label),
      ],
    );
  }

  Widget _stars() {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => setState(() => _satisfaccion = i),
            icon: Icon(
              i <= _satisfaccion ? Icons.star : Icons.star_border,
              color: AppColors.primary,
              size: 32,
            ),
          ),
      ],
    );
  }
}
