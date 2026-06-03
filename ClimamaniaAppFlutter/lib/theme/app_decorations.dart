import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Decoraciones reutilizables que reproducen los `shape drawables` de Android
/// (bg_login_card, bg_edittext, bg_detail_hero, etc.) para fidelidad 1:1.
class AppDecorations {
  AppDecorations._();

  /// bg_login_card: blanco, radio 12, borde 1dp #F1F1F1.
  static BoxDecoration loginCard = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.primaryLight, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  /// bg_edittext: blanco, radio 6, borde 1dp #F1F1F1.
  static BoxDecoration editText = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: AppColors.primaryLight, width: 1),
  );

  /// bg_detail_hero: degradado #FFF9F2 → #FFFFFF, borde 1dp #F2E6DA, radio 18.
  static BoxDecoration detailHero = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.heroStroke, width: 1),
  );

  /// MaterialCardView blanco: radio 18, borde 1dp #EFE2D6, elevación 3.
  static BoxDecoration whiteCard = BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.cardStroke, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  /// bg_address_highlight: #FFFDF9, borde 1dp #F2D9C2, radio 12.
  static BoxDecoration addressHighlight = BoxDecoration(
    color: AppColors.addressBg,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.addressStroke, width: 1),
  );

  /// bg_chip_light: #FFF8F1, borde 1dp #E7C6A6, pastilla.
  static BoxDecoration chipLight = BoxDecoration(
    color: AppColors.chipBg,
    borderRadius: BorderRadius.circular(50),
    border: Border.all(color: AppColors.chipStroke, width: 1),
  );

  /// bg_section_label_green: #E9F7EC, borde 1dp #4CAF50, pastilla.
  static BoxDecoration sectionLabelGreen = BoxDecoration(
    color: AppColors.sectionGreenBg,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: AppColors.sectionGreenStroke, width: 1),
  );

  /// bg_footer_bar: #FAFAFA, borde 1dp #E6E6E6, esquinas superiores 18.
  static BoxDecoration footerBar = const BoxDecoration(
    color: AppColors.footerBarBg,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(18),
      topRight: Radius.circular(18),
    ),
    border: Border(top: BorderSide(color: AppColors.footerBarStroke, width: 1)),
  );

  /// bg_footer_item_active: #FFF1E3, radio 18.
  static BoxDecoration footerItemActive = BoxDecoration(
    color: AppColors.footerActiveBg,
    borderRadius: BorderRadius.circular(18),
  );

  /// Estilo de botón naranja con radio configurable (Maps/Llamar/Mensaje, Buscar).
  static ButtonStyle orangeButton({double radius = 5, double fontSize = 12}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    );
  }
}
