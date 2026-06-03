import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: stroke, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
