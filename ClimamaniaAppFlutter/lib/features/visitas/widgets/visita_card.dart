import 'package:flutter/material.dart';

import '../../../core/fecha.dart';
import '../../../core/priority.dart';
import '../../../core/widgets/meta_line.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/gestion_item.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';

/// Tarjeta de visita/incidencia (misma familia visual que la tarjeta de
/// instalación de Inicio). Réplica funcional de item_visita_pendiente.
class VisitaCard extends StatelessWidget {
  final GestionItem visita;
  final String estadoLabel; // "Visita pendiente" / "Incidencia pendiente"
  final String? codigo; // título; por defecto "Visita #id"
  final bool showActions;
  final bool esIncidencia;
  final VoidCallback onTap;
  final VoidCallback? onMaps;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const VisitaCard({
    super.key,
    required this.visita,
    required this.estadoLabel,
    required this.onTap,
    this.codigo,
    this.showActions = true,
    this.esIncidencia = false,
    this.onMaps,
    this.onCall,
    this.onMessage,
  });

  static String fechaCorta(String raw) => Fecha.parse(raw);

  /// Normaliza nombres que llegan en mayúsculas/minúsculas inconsistentes
  /// ("angel martinez" / "ABDUL SARWAR") a Capitalización de Título.
  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  IconData get _typeIcon =>
      esIncidencia ? Icons.report_problem_rounded : Icons.event_available_rounded;

  Color _tileTint(String p) => switch (p) {
        'Alta' => AppColors.errorTint,
        'Media' => AppColors.warningTint,
        _ => AppColors.surfaceWarm,
      };

  Color _tileFg(String p) => switch (p) {
        'Alta' => AppColors.errorFg,
        'Media' => AppColors.warningFg,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final prio = Prioridad.parse(visita.prioridad);
    final t = Theme.of(context).textTheme;
    final dir = [
      if (visita.direccion.isNotEmpty) visita.direccion,
      if (visita.poblacion.isNotEmpty) visita.poblacion,
    ].join(', ');
    final meta = <String>[
      if (visita.equipoId.isNotEmpty) 'Equipo ${visita.equipoId}',
      if (visita.solicitante.isNotEmpty) 'Solicita ${visita.solicitante}',
      if (visita.fechaSolicitud.isNotEmpty) fechaCorta(visita.fechaSolicitud),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _PressScale(
        onTap: onTap,
        child: Container(
          decoration: AppDecorations.whiteCard,
          child: ClipRRect(
            borderRadius: AppRadius.brLg,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera: estado + Nº
                  Row(
                    children: [
                      StatusBadge(
                        estadoLabel,
                        tone:
                            esIncidencia ? BadgeTone.danger : BadgeTone.brand,
                        icon: _typeIcon,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: AppDecorations.chipLight,
                        child: Text(codigo ?? 'Visita #${visita.id}',
                            style: t.labelMedium
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Identidad: azulejo (teñido por prioridad) + cliente + badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tileTint(prio),
                          borderRadius: AppRadius.brMd,
                          border: Border.all(
                              color: _tileFg(prio).withValues(alpha: 0.22),
                              width: 1.5),
                        ),
                        child: Icon(_typeIcon, color: _tileFg(prio), size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              visita.cliente.isNotEmpty
                                  ? _titleCase(visita.cliente)
                                  : estadoLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium,
                            ),
                            if (prio != 'Sin prioridad') ...[
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: PriorityBadge(prio),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                      height: 1,
                      width: double.infinity,
                      color: AppColors.border),
                  const SizedBox(height: AppSpacing.md),
                  // Dirección (pin neutro)
                  if (dir.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: AppColors.surfaceWarm,
                              borderRadius: AppRadius.brMd),
                          child: const Center(
                            child: Icon(Icons.place,
                                size: 20, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(dir,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleSmall
                                  ?.copyWith(color: AppColors.textPrimary)),
                        ),
                      ],
                    ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: MetaLine(meta),
                    ),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                            child: _action(
                                context, Icons.place, 'Maps', onMaps,
                                primary: true)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: _action(
                                context, Icons.call, 'Llamar', onCall,
                                primary: false)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: _action(
                                context, Icons.chat, 'Mensaje', onMessage,
                                primary: false)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      VoidCallback? onTap,
      {required bool primary}) {
    final t = Theme.of(context).textTheme;
    final Color fg = primary ? AppColors.white : AppColors.warningFg;
    final content = SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelLarge?.copyWith(color: fg)),
          ),
        ],
      ),
    );

    if (primary) {
      return Material(
        color: AppColors.primary,
        borderRadius: AppRadius.brPill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap, borderRadius: AppRadius.brPill, child: content),
      );
    }
    return Material(
      color: AppColors.footerActiveBg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brPill,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        child: content,
      ),
    );
  }
}

/// Micro-interacción: leve escala al pulsar (respeta "reducir movimiento").
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({required this.child, this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: reduce ? null : (_) => setState(() => _pressed = true),
      onTapUp: reduce ? null : (_) => setState(() => _pressed = false),
      onTapCancel: reduce ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: Duration(milliseconds: reduce ? 0 : 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
