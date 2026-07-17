import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../refresh_signal.dart';

/// Barra superior del shell (56dp): hamburguesa (o flecha de volver) + logo
/// centrado + botón de recarga. Fondo blanco con hairline inferior.
class AppTopBar extends StatelessWidget {
  /// Si true, el botón izquierdo es una flecha de "volver" a la pestaña
  /// anterior; si false, es el menú hamburguesa que abre el drawer.
  final bool canGoBack;
  final VoidCallback? onBack;

  const AppTopBar({super.key, this.canGoBack = false, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Image.asset(
                'assets/images/climamania_logo.png',
                width: 132,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: canGoBack
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textPrimary),
                        iconSize: 24,
                        tooltip: 'Volver',
                        onPressed: onBack,
                      )
                    : IconButton(
                        icon: const Icon(Icons.menu,
                            color: AppColors.textPrimary),
                        iconSize: 24,
                        tooltip: 'Abrir menú',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.sync, color: AppColors.textPrimary),
                  iconSize: 22,
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
