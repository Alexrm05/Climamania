import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/install_repository.dart';
import '../../data/repositories/pedido_repository.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_spacing.dart';

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
  // Escandallo (parte de materiales) sin registrar.
  bool _sinEscandallo = false;

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
      final faltan = <String>[];
      if (res.pedido != null) {
        final f = res.pedido!.fotografias;
        if (f.previas.isEmpty) faltan.add('Faltan fotos previas a la instalación');
        if (f.acabada.isEmpty) faltan.add('Faltan fotos de la instalación acabada');
        if (f.conforme.isEmpty) faltan.add('Faltan fotos conforme cliente');
      }
      setState(() {
        _faltan = faltan;
        _sinEscandallo =
            res.pedido != null && !(res.pedido!.parteMateriales?.hecho ?? false);
        _fotosCargadas = true;
      });
    } catch (_) {
      if (mounted) setState(() => _fotosCargadas = true);
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
              style: TextButton.styleFrom(foregroundColor: AppColors.errorFg),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: AppDecorations.greenButton,
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
      final payload = {
        'referencia': widget.referencia,
        'usuario': session.displayName(fallback: 'Instalador'),
        'cobroMetalico': _metalicoCtrl.text.trim().replaceAll(',', '.'),
        'cobroVisa': _visaCtrl.text.trim().replaceAll(',', '.'),
        'extras': _extras,
        'satisfaccion': _satisfaccion > 0 ? '$_satisfaccion' : '',
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
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: const Text('Finalizar instalación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppDecorations.chipLight,
              child: Text('Nº ${widget.referencia}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_fotosCargadas && _sinEscandallo) _avisoEscandallo(),
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
              decoration: AppDecorations.bareInput(
                hintText: 'Observaciones...',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          )),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => context.pop(),
                    style: AppDecorations.redButton.copyWith(
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 22)),
                    ),
                    child: const Text('Volver'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _finalizar,
                      style: AppDecorations.greenButton,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Finalizar ahora'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Escandallo sin registrar: más llamativo que el aviso de fotos (fondo
  /// rojo sólido) y con acceso directo para hacerlo desde aquí. No bloquea.
  Widget _avisoEscandallo() {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorFg,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: AppColors.white, size: 30),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('ESCANDALLO SIN REGISTRAR',
                    style: t.titleMedium?.copyWith(
                        color: AppColors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'No has registrado los materiales gastados ni las horas en el domicilio de esta instalación.',
            style: t.bodyMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final guardado = await context.push<bool>('/escandallo',
                    extra: {'referencia': widget.referencia});
                if (mounted && guardado == true) _cargarFotosFaltantes();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.errorFg,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
              ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Registrar escandallo ahora'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoFotos() {
    final completas = _faltan.isEmpty;
    final fg = completas ? AppColors.successFg : AppColors.errorFg;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: completas ? AppColors.successTint : AppColors.errorTint,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              completas
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: fg,
              size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: completas
                ? Text('Fotografías completas',
                    style: t.titleSmall?.copyWith(color: fg))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Faltan fotografías',
                          style: t.titleSmall?.copyWith(color: fg)),
                      const SizedBox(height: 2),
                      for (final f in _faltan)
                        Text('• $f',
                            style: t.bodySmall?.copyWith(color: fg)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

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
        decoration: AppDecorations.bareInput(
          labelText: label,
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
