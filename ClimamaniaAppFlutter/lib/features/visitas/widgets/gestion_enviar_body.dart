import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_spacing.dart';

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Cabecera compartida (cliente + dirección) para las pantallas de gestión.
class GestionHeaderCard extends StatelessWidget {
  final String cliente;
  final String direccion;
  final bool esIncidencia;

  const GestionHeaderCard({
    super.key,
    required this.cliente,
    required this.direccion,
    required this.esIncidencia,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: AppDecorations.whiteCard,
      child: ClipRRect(
        borderRadius: AppRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.footerActiveBg,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      width: 1.5),
                ),
                child: Icon(
                    esIncidencia
                        ? Icons.report_problem_rounded
                        : Icons.event_available_rounded,
                    color: AppColors.primary,
                    size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cliente.isNotEmpty)
                      Text(_titleCase(cliente),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium),
                    if (direccion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(direccion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acción del menú de gestión.
class GestionEnviarAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const GestionEnviarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle = '',
    this.danger = false,
  });
}

/// Cuerpo compartido del menú "Gestionar visita/incidencia": cabecera + una
/// cuadrícula 2×2 de acciones (la de "danger" en rojo, como la tarjeta de
/// Incidencias de la home).
class GestionEnviarBody extends StatelessWidget {
  final String cliente;
  final String direccion;
  final bool esIncidencia;
  final List<GestionEnviarAction> actions;

  const GestionEnviarBody({
    super.key,
    required this.cliente,
    required this.direccion,
    required this.esIncidencia,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasHeader = cliente.isNotEmpty || direccion.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (hasHeader) ...[
          GestionHeaderCard(
              cliente: cliente,
              direccion: direccion,
              esIncidencia: esIncidencia),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('¿Qué quieres hacer?', style: t.titleMedium),
        const SizedBox(height: AppSpacing.md),
        // Cuadrícula 2×2 de acciones.
        for (int i = 0; i < actions.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ActionTile(action: actions[i])),
                const SizedBox(width: AppSpacing.md),
                if (i + 1 < actions.length)
                  Expanded(child: _ActionTile(action: actions[i + 1]))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final GestionEnviarAction action;
  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bool danger = action.danger;
    // La tarjeta "danger" replica el estilo de la tarjeta Incidencias de la
    // home: fondo tinte rojo, chip rojo sólido con icono blanco.
    final Color bg = danger ? AppColors.errorTint : AppColors.surface;
    final Color chip = danger ? AppColors.errorFg : AppColors.footerActiveBg;
    final Color chipIcon = danger ? AppColors.white : AppColors.primary;
    final Color titleColor =
        danger ? AppColors.errorFg : AppColors.textPrimary;
    final Color borderColor =
        danger ? AppColors.errorFg.withValues(alpha: 0.22) : AppColors.border;

    return Material(
      color: bg,
      borderRadius: AppRadius.brLg,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: AppRadius.brLg,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.brLg,
            border: Border.all(color: borderColor),
            boxShadow: AppShadows.card,
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: chip, borderRadius: AppRadius.brMd),
                child: Icon(action.icon, color: chipIcon, size: 22),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(color: titleColor)),
              if (action.subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                        color: danger
                            ? AppColors.errorFg.withValues(alpha: 0.75)
                            : AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
