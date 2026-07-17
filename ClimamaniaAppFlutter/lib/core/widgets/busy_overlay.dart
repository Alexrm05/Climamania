import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Superpone un velo con indicador de carga sobre [child] cuando [busy] es
/// true. Reemplaza los `Color(0x66000000)` sueltos.
class BusyOverlay extends StatelessWidget {
  final bool busy;
  final Widget child;

  const BusyOverlay({super.key, required this.busy, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (busy)
          const Positioned.fill(
            // AbsorbPointer bloquea la interacción con lo que hay debajo
            // mientras se está procesando.
            child: AbsorbPointer(
              child: ColoredBox(
                color: AppColors.scrim,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}
