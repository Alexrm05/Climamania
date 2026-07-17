import 'package:flutter/widgets.dart';

/// Sombras coherentes para elevación. Reemplaza las sombras ad-hoc dispersas.
class AppShadows {
  AppShadows._();

  /// Tarjetas y elementos de lista (sombra suave).
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Elementos elevados (FAB, botones pulsados, diálogos).
  static const List<BoxShadow> raised = [
    BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 16,
        spreadRadius: -2,
        offset: Offset(0, 6)),
  ];

  /// Superficies flotantes (bottom sheets, menús).
  static const List<BoxShadow> overlay = [
    BoxShadow(
        color: Color(0x29000000),
        blurRadius: 24,
        spreadRadius: -4,
        offset: Offset(0, 10)),
  ];
}
