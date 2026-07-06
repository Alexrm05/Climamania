import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_decorations.dart';
import '../nav_destinations.dart';
import 'nav_footer_item.dart';

/// Barra inferior de 5 pestañas del shell. Réplica de la barra de
/// `activity_base.xml`: Calendario · Inicio · Valoraciones · Adicionales · Web.
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: AppDecorations.footerBar,
      child: Row(
        children: [
          for (var i = 0; i < kNavDestinations.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: NavFooterItem(
                item: kNavDestinations[i],
                active: navigationShell.currentIndex == i,
                onTap: () => _onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra inferior para pantallas de detalle empujadas sobre el shell. Navega
/// por rama con `context.go` (Android recrea la activity al pulsar una pestaña,
/// sin conservar estado — este comportamiento lo replica).
class DetailBottomBar extends StatelessWidget {
  final int activeIndex;

  const DetailBottomBar({super.key, this.activeIndex = NavBranch.home});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: AppDecorations.footerBar,
      child: Row(
        children: [
          for (var i = 0; i < kNavDestinations.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: NavFooterItem(
                item: kNavDestinations[i],
                active: activeIndex == i,
                onTap: () => context.go(kNavDestinations[i].route),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
