import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../nav_destinations.dart';

/// Presentación de un item de la barra inferior (icono + etiqueta), compartida
/// entre el shell y las pantallas de detalle (`DetailScaffold`).
class NavFooterItem extends StatelessWidget {
  final NavDestination item;
  final bool active;
  final VoidCallback onTap;

  const NavFooterItem({
    super.key,
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
