import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/busy_overlay.dart';
import '../../data/repositories/incidencia_repository.dart';
import '../../data/repositories/visita_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'widgets/gestion_enviar_body.dart';

/// Finalizar o cancelar una visita/incidencia. Réplica de CerrarGestionActivity.
class CerrarGestionScreen extends StatefulWidget {
  final String tipo; // 'visita' | 'incidencia'
  final String id;
  final String cliente;
  final String direccion;
  final String poblacion;

  const CerrarGestionScreen({
    super.key,
    required this.tipo,
    required this.id,
    this.cliente = '',
    this.direccion = '',
    this.poblacion = '',
  });

  @override
  State<CerrarGestionScreen> createState() => _CerrarGestionScreenState();
}

class _CerrarGestionScreenState extends State<CerrarGestionScreen> {
  final _motivoCtrl = TextEditingController();
  final _resumenCtrl = TextEditingController();
  bool _busy = false;

  bool get _esIncidencia => widget.tipo == 'incidencia';
  String get _caso => _esIncidencia ? 'incidencia' : 'visita';

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _resumenCtrl.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _enviar(String accion) async {
    if (accion == 'cancelar' && _motivoCtrl.text.trim().isEmpty) {
      _msg('Indica el motivo de la cancelación');
      return;
    }
    if (accion == 'finalizar' &&
        _esIncidencia &&
        _resumenCtrl.text.trim().isEmpty) {
      _msg('Describe cómo se ha resuelto la incidencia');
      return;
    }
    FocusScope.of(context).unfocus(); // cerrar el teclado al enviar
    setState(() => _busy = true);
    final session = context.read<SessionService>();
    final rol = session.rol;
    final usuario = session.usuarioForRequests;
    final equipo = session.readEquipo();
    final autor = session.displayName(fallback: 'Instalador');
    final motivo = _motivoCtrl.text.trim();
    final resumen = _resumenCtrl.text.trim();
    final incidenciaRepo = context.read<IncidenciaRepository>();
    final visitaRepo = context.read<VisitaRepository>();

    final (bool, String) res = _esIncidencia
        ? await incidenciaRepo.cerrar(
            idIncidencia: widget.id,
            rol: rol,
            usuario: usuario,
            equipo: equipo,
            autor: autor,
            accion: accion,
            motivo: motivo,
            resumen: resumen,
          )
        : await visitaRepo.cerrar(
            idVisita: widget.id,
            rol: rol,
            usuario: usuario,
            equipo: equipo,
            autor: autor,
            accion: accion,
            motivo: motivo,
            resumen: resumen,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    _msg(res.$2);
    if (res.$1) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final direccion = [widget.direccion, widget.poblacion]
        .where((e) => e.isNotEmpty)
        .join(', ');
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(title: Text('Finalizar $_caso')),
      body: BusyOverlay(
        busy: _busy,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.cliente.isNotEmpty || widget.direccion.isNotEmpty) ...[
              GestionHeaderCard(
                  cliente: widget.cliente,
                  direccion: direccion,
                  esIncidencia: _esIncidencia),
              const SizedBox(height: AppSpacing.md),
            ],
            // Finalizar
            _card(
              context,
              icon: Icons.task_alt,
              tone: AppColors.successFg,
              tint: AppColors.successTint,
              title: 'Finalizar $_caso',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('La $_caso se marcará como resuelta.',
                      style:
                          t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  if (_esIncidencia) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Resumen de la actuación', style: t.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    _field(_resumenCtrl,
                        'Describe brevemente cómo se ha resuelto...'),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _submit('Finalizar $_caso', AppColors.successFg,
                      () => _enviar('finalizar')),
                ],
              ),
            ),
            // Cancelar
            _card(
              context,
              icon: Icons.cancel_outlined,
              tone: AppColors.errorFg,
              tint: AppColors.errorTint,
              title: 'Cancelar $_caso',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Es obligatorio indicar el motivo de la cancelación.',
                      style:
                          t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  _field(_motivoCtrl, 'Motivo de la cancelación...'),
                  const SizedBox(height: AppSpacing.md),
                  _submit('Cancelar $_caso', AppColors.errorFg,
                      () => _enviar('cancelar'),
                      outlined: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submit(String label, Color color, VoidCallback onTap,
      {bool outlined = false}) {
    final content = SizedBox(
      height: 48,
      child: Center(
        child: Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: outlined ? color : AppColors.white)),
      ),
    );
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: Material(
          color: color.withValues(alpha: 0.06),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.brPill,
            side: BorderSide(color: color.withValues(alpha: 0.55)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _busy ? null : onTap,
            customBorder:
                RoundedRectangleBorder(borderRadius: AppRadius.brPill),
            child: content,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: AppRadius.brPill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: _busy ? null : onTap,
            borderRadius: AppRadius.brPill,
            child: content),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return Container(
      decoration: AppDecorations.editText,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        minLines: 2,
        maxLines: 5,
        decoration: AppDecorations.bareInput(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _card(BuildContext context,
      {required IconData icon,
      required Color tone,
      required Color tint,
      required String title,
      required Widget child}) {
    final t = Theme.of(context).textTheme;
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
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: tint, borderRadius: AppRadius.brMd),
                      child: Icon(icon, color: tone, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(title, style: t.titleMedium)),
                  ],
                ),
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
