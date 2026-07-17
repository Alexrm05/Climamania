import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../tab_history.dart';

/// Item de la barra inferior. El icono puede ser un PNG corporativo (con tinte)
/// o un icono Material.
class _NavItem {
  final String label;
  final String? asset;
  final IconData? icon;
  const _NavItem(this.label, {this.asset, this.icon});
}

/// Barra inferior de 5 pestañas:
/// Calendario · Adicionales · Inicio · Valoraciones · Web.
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  static const _items = <_NavItem>[
    _NavItem('Calendario', asset: 'assets/images/ic_calendar.png'),
    _NavItem('Adicionales', icon: Icons.add_box_outlined),
    _NavItem('Inicio', asset: 'assets/images/ic_home.png'),
    _NavItem('Valoraciones', icon: Icons.star_border),
    _NavItem('Web', asset: 'assets/images/ic_web.png'),
  ];

  void _onTap(BuildContext context, int index) {
    final current = navigationShell.currentIndex;
    // Registra la pestaña actual en el historial antes de cambiar, para que la
    // flecha de "volver" pueda regresar a ella.
    if (index != current) {
      context.read<TabHistory>().record(current);
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == current,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: AppDecorations.footerBar,
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _FooterItem(
                item: _items[i],
                active: navigationShell.currentIndex == i,
                onTap: () => _onTap(context, i),
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _FooterItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.footerInactive;

    Widget iconWidget;
    if (item.asset != null) {
      iconWidget = Image.asset(
        item.asset!,
        width: 24,
        height: 24,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    } else {
      iconWidget = Icon(item.icon, size: 24, color: color);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration:
            active ? AppDecorations.footerItemActive : const BoxDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
