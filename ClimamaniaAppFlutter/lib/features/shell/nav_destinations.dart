import 'package:flutter/material.dart';

/// Destino de la barra inferior de 5 pestañas del shell.
/// Orden EXACTO de `activity_base.xml`: Calendario · Inicio · Valoraciones ·
/// Adicionales · Web.
class NavDestination {
  final String label;
  final String route;
  final String? asset;
  final IconData? icon;
  final double fontSize;
  const NavDestination(
    this.label,
    this.route, {
    this.asset,
    this.icon,
    this.fontSize = 11,
  });
}

const List<NavDestination> kNavDestinations = <NavDestination>[
  NavDestination('Calendario', '/calendar',
      asset: 'assets/images/ic_calendar.png'),
  NavDestination('Inicio', '/home', asset: 'assets/images/ic_home.png'),
  NavDestination('Valoraciones', '/ratings', icon: Icons.star),
  NavDestination('Adicionales', '/adicionales', icon: Icons.add_box, fontSize: 10),
  NavDestination('Web', '/web', asset: 'assets/images/ic_web.png'),
];

/// Índices de rama (deben coincidir con el orden de `kNavDestinations` y de las
/// ramas del `StatefulShellRoute`).
class NavBranch {
  static const int calendar = 0;
  static const int home = 1;
  static const int ratings = 2;
  static const int adicionales = 3;
  static const int web = 4;
}
