import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'nav_destinations.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/bottom_nav_bar.dart';

/// Andamiaje para las pantallas de detalle empujadas sobre el shell. Reproduce
/// `BaseActivity` de Android: barra superior (menú + logo + recargar), contenido
/// y barra inferior de 5 pestañas + drawer. La pestaña [activeIndex] queda
/// resaltada (p. ej. el detalle de presupuesto resalta "Adicionales").
///
/// [onReload] recarga el contenido de la propia pantalla desde el botón de la
/// barra superior; si es null se dispara la señal global de recarga.
class DetailScaffold extends StatelessWidget {
  final Widget child;
  final int activeIndex;
  final VoidCallback? onReload;

  const DetailScaffold({
    super.key,
    required this.child,
    this.activeIndex = NavBranch.home,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(onReload: onReload),
            Container(height: 1, color: AppColors.primaryLight),
            Expanded(child: child),
            Container(height: 1, color: AppColors.footerBarStroke),
            DetailBottomBar(activeIndex: activeIndex),
          ],
        ),
      ),
    );
  }
}
