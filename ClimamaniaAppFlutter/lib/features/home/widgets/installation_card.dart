import 'package:flutter/material.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../home_controller.dart';

/// Tarjeta de "Instalación en curso" / "Próxima instalación" (resumen de Inicio).
/// Estilo moderno: monograma del cliente teñido por estado, nombre como
/// titular, acciones en píldora y micro-interacción de pulsación.
class InstallationCard extends StatelessWidget {
  final bool isEnCurso;
  final CardState state;
  final VoidCallback onMaps;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback? onTap;

  const InstallationCard({
    super.key,
    required this.isEnCurso,
    required this.state,
    required this.onMaps,
    required this.onCall,
    required this.onWhatsapp,
    this.onTap,
  });

  String get _defaultTitle =>
      isEnCurso ? 'Instalación en curso' : 'Próxima instalación';

  /// Color de acento neutro mientras carga/vacía; de estado con datos.
  Color get _accentColor {
    if (state.isLoading || !state.hasData) return AppColors.border;
    return isEnCurso ? AppColors.successFg : AppColors.primary;
  }

  /// Color de estado "comprometido": solo se usa dentro de _data/_addressBlock,
  /// así el monograma nunca insinúa un color de estado al cargar/vacía.
  Color get _stateFg => isEnCurso ? AppColors.successFg : AppColors.primary;
  Color get _tint => isEnCurso ? AppColors.successTint : AppColors.footerActiveBg;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.whiteCard,
        child: ClipRRect(
          borderRadius: AppRadius.brLg,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                if (state.isLoading)
                  _loading()
                else if (state.hasData)
                  _data(context, state.data!)
                else
                  _empty(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ref = state.data?.referencia ?? '';
    final badge = isEnCurso
        ? const StatusBadge('En curso',
            tone: BadgeTone.success, icon: Icons.home_rounded)
        : const StatusBadge('Próxima',
            tone: BadgeTone.brand, icon: Icons.event);

    return Row(
      children: [
        badge,
        const Spacer(),
        if (state.hasData && ref.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: AppDecorations.chipLight,
            child: Text('Nº $ref',
                style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _data(BuildContext context, InstallationData d) {
    final t = Theme.of(context).textTheme;
    final title = d.cliente.isNotEmpty ? d.cliente : _defaultTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        // Fila de identidad: monograma + nombre + hora.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tint,
                borderRadius: AppRadius.brMd,
                border: Border.all(
                    color: _stateFg.withValues(alpha: 0.22), width: 1.5),
              ),
              child: Icon(Icons.hvac, color: _stateFg, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.headlineSmall),
                  if (d.cuando.isNotEmpty || d.equipo.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (d.cuando.isNotEmpty)
                          _meta(context, Icons.schedule, d.cuando),
                        if (d.equipo.isNotEmpty)
                          _meta(context, Icons.groups_outlined,
                              'Equipo ${d.equipo}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(height: 1, width: double.infinity, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        _addressBlock(context, d),
      ],
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(text,
            style: t.titleSmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _addressBlock(BuildContext context, InstallationData d) {
    final t = Theme.of(context).textTheme;
    final dir = d.direccionLimpia;
    final tel = d.telefono;
    // Bloque plano (sin panel anidado): DÓNDE -> HACER -> IR.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // DÓNDE — dirección (fila plana, la acción vive en el botón Maps)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: _tint, borderRadius: AppRadius.brMd),
              child: Center(
                child: Icon(Icons.place, size: 20, color: _accentColor),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dir.isEmpty && tel.isEmpty)
                    Text('Dirección no disponible',
                        style: t.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic))
                  else ...[
                    if (dir.isNotEmpty)
                      Text(dir,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall
                              ?.copyWith(color: AppColors.textPrimary)),
                    if (tel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(tel, style: t.bodySmall),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // HACER — acciones
        Row(
          children: [
            Expanded(
                child: _action(context, Icons.place, 'Maps', onMaps,
                    primary: true)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: _action(context, Icons.call, 'Llamar', onCall,
                    primary: false)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: _action(context, Icons.chat, 'Mensaje', onWhatsapp,
                    primary: false)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(height: 1, width: double.infinity, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        // IR — a la ficha del pedido (la tarjeta entera navega)
        Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 16, color: _accentColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Ver ficha del pedido',
                  style:
                      t.titleSmall?.copyWith(color: AppColors.textSecondary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ],
    );
  }

  /// Botón de acción en píldora. Jerarquía 1 sólido (Maps) + 2 tonales.
  Widget _action(BuildContext context, IconData icon, String label,
      VoidCallback onTap,
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

  Widget _loading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: AppRadius.brMd),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 200, height: 22),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 130, height: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(height: 1, width: double.infinity, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        // dirección
        Row(
          children: [
            SkeletonBox(width: 36, height: 36, radius: AppRadius.brMd),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // barra de acciones
        Row(
          children: [
            Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: 44, radius: AppRadius.brPill)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: 44, radius: AppRadius.brPill)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: SkeletonBox(
                    width: double.infinity, height: 44, radius: AppRadius.brPill)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const SkeletonBox(width: 180, height: 14),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final raw = state.message ?? '';
    var clean = raw.replaceFirst(
        RegExp(r'^(Instalación en curso|Próxima instalación):\s*'), '');
    if (clean.isEmpty) {
      clean = isEnCurso
          ? 'Ninguna instalación en curso ahora mismo.'
          : 'Sin próximas instalaciones programadas.';
    } else {
      clean = clean[0].toUpperCase() + clean.substring(1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(isEnCurso ? Icons.home_outlined : Icons.event_busy_outlined,
                size: 20, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(clean,
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Micro-interacción: leve escala al pulsar la tarjeta. Respeta "reducir
/// movimiento". Envuelve solo el gesto para que [InstallationCard] siga siendo
/// StatelessWidget.
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
