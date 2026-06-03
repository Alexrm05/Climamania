import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';

/// Item de la barra inferior. El icono puede ser un PNG corporativo (con tinte)
/// o un icono Material (Valoraciones/Adicionales, como en Android).
class _NavItem {
  final String label;
  final String? asset;
  final IconData? icon;
  final double fontSize;
  const _NavItem(this.label, {this.asset, this.icon, this.fontSize = 11});
}

/// Barra inferior de 5 pestañas. Réplica de la barra de `activity_base.xml`:
/// Calendario · Inicio · Valoraciones · Adicionales · Web.
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  static const _items = <_NavItem>[
    _NavItem('Calendario', asset: 'assets/images/ic_calendar.png'),
    _NavItem('Inicio', asset: 'assets/images/ic_home.png'),
    _NavItem('Valoraciones', icon: Icons.star),
    _NavItem('Adicionales', icon: Icons.add_box, fontSize: 10),
    _NavItem('Web', asset: 'assets/images/ic_web.png'),
  ];

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
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _FooterItem(
                item: _items[i],
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
        width: 22,
        height: 22,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    } else {
      iconWidget = Icon(item.icon, size: 22, color: color);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        scale: active ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          decoration:
              active ? AppDecorations.footerItemActive : const BoxDecoration(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(height: 4),
              // Una sola línea; se reduce si la etiqueta no cabe (p. ej. "Valoraciones").
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: item.fontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
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
