import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../refresh_signal.dart';

/// Barra superior blanca (80dp) del shell: hamburguesa + logo centrado +
/// botón de recarga. Réplica de la cabecera de `activity_base.xml`.
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 2,
      child: SizedBox(
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Logo centrado
            Center(
              child: Image.asset(
                'assets/images/climamania_logo.png',
                width: 160,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
            // Hamburguesa (abre el drawer)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.iconHeader),
                  iconSize: 32,
                  tooltip: 'Abrir menú',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            // Recargar
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.sync, color: AppColors.iconHeader),
                  iconSize: 28,
                  tooltip: 'Recargar',
                  onPressed: () => context.read<RefreshSignal>().fire(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
