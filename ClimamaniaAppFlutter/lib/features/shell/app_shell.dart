import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import 'tab_history.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/bottom_nav_bar.dart';

/// Shell persistente: barra superior + contenido (rama activa) + barra inferior,
/// con menú lateral. Reproduce `BaseActivity` de Android.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  /// Vuelve a la pestaña anterior del historial. Devuelve true si navegó.
  bool _goBackTab(BuildContext context) {
    final prev = context.read<TabHistory>().goBack();
    if (prev == null) return false;
    navigationShell.goBranch(prev, initialLocation: false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = context.watch<TabHistory>().canGoBack;
    return PopScope(
      // Si hay pestañas en el historial, interceptamos el "atrás" del sistema
      // para volver a la anterior en vez de salir de la app.
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBackTab(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryLight,
        drawer: AppDrawer(navigationShell: navigationShell),
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                canGoBack: canGoBack,
                onBack: () => _goBackTab(context),
              ),
              Expanded(child: navigationShell),
              BottomNavBar(navigationShell: navigationShell),
            ],
          ),
        ),
      ),
    );
  }
}
