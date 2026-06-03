import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import 'widgets/app_drawer.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/bottom_nav_bar.dart';

/// Shell persistente: barra superior + contenido (rama activa) + barra inferior,
/// con menú lateral. Reproduce `BaseActivity` de Android.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      drawer: AppDrawer(navigationShell: navigationShell),
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(),
            Container(height: 1, color: AppColors.primaryLight),
            Expanded(child: navigationShell),
            Container(height: 1, color: AppColors.footerBarStroke),
            BottomNavBar(navigationShell: navigationShell),
          ],
        ),
      ),
    );
  }
}
