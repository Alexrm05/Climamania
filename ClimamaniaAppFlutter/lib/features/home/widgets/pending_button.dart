import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';

enum PendingVariant { green, red }

/// Botón de "pendientes" (visitas en verde, incidencias en rojo).
/// Réplica de btnVisitasPendientes / btnIncidenciasPendientes (activity_main).
class PendingButton extends StatelessWidget {
  final PendingVariant variant;
  final String text;
  final VoidCallback onTap;

  const PendingButton({
    super.key,
    required this.variant,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGreen = variant == PendingVariant.green;
    final bg = isGreen ? AppColors.pendingGreenBg : AppColors.pendingRedBg;
    final fg = isGreen ? AppColors.pendingGreenText : AppColors.pendingRedText;
    final iconColor =
        isGreen ? AppColors.pendingGreenIcon : AppColors.pendingRedIcon;
    final stroke =
        isGreen ? AppColors.pendingGreenStroke : AppColors.pendingRedStroke;
    final icon = isGreen ? Icons.today : Icons.warning_amber_rounded;

    return Material(
      color: bg,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: stroke, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
