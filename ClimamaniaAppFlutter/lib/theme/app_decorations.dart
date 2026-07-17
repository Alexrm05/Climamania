import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';

/// Decoraciones reutilizables. Se conservan los nombres públicos para que los
/// call-sites existentes mejoren solos; los internos usan los tokens del
/// refresh (radios, sombras y colores secundarios cálidos).
class AppDecorations {
  AppDecorations._();

  /// Tarjeta de login: blanca, radio lg, borde sutil + sombra suave.
  static BoxDecoration loginCard = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.brLg,
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: AppShadows.card,
  );

  /// Campo de texto: blanco, radio sm, borde sutil.
  static BoxDecoration editText = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.brSm,
    border: Border.all(color: AppColors.border, width: 1),
  );

  /// `InputDecoration` para un [TextField] que va DENTRO de un
  /// `Container(editText)`: sin borde ni relleno propios (los aporta el
  /// contenedor), evitando el doble borde que añadiría el tema global.
  /// Fuente única para todos los campos de la app.
  static InputDecoration bareInput({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    BoxConstraints? prefixIconConstraints,
    BoxConstraints? suffixIconConstraints,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 10),
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixIconConstraints: prefixIconConstraints,
      suffixIconConstraints: suffixIconConstraints,
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: contentPadding,
    );
  }

  // --- Estilos de botón por semántica (verde=confirmar, rojo=cancelar/volver,
  //     naranja=buscar/cargar). Píldora, para reusar en toda la app. ---

  /// Confirmar / continuar / guardar / finalizar / aceptar (verde sólido).
  static final ButtonStyle greenButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.confirm,
    foregroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
  );

  /// Cancelar / volver atrás (rojo con tinte, estética de la tarjeta de
  /// Incidencias de la home). Se usa con [OutlinedButton].
  static final ButtonStyle redButton = OutlinedButton.styleFrom(
    backgroundColor: AppColors.errorTint,
    foregroundColor: AppColors.errorFg,
    side: BorderSide(color: AppColors.errorFg.withValues(alpha: 0.35)),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
  );

  /// Buscar / cargar datos (naranja de marca, sólido).
  static final ButtonStyle orangeButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
  );

  /// Hero: fondo plano cálido (sin degradado), radio lg, borde sutil.
  static BoxDecoration detailHero = BoxDecoration(
    color: AppColors.surfaceWarm,
    borderRadius: AppRadius.brLg,
    border: Border.all(color: AppColors.border, width: 1),
  );

  /// Tarjeta blanca: radio lg, borde muy sutil + sombra suave.
  static BoxDecoration whiteCard = BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.brLg,
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: AppShadows.card,
  );

  /// Resaltado de dirección: fondo cálido, borde sutil, radio md.
  static BoxDecoration addressHighlight = BoxDecoration(
    color: AppColors.surfaceWarm,
    borderRadius: AppRadius.brMd,
    border: Border.all(color: AppColors.border, width: 1),
  );

  /// Chip claro (meta): fondo cálido, pastilla.
  static BoxDecoration chipLight = BoxDecoration(
    color: AppColors.surfaceWarm,
    borderRadius: AppRadius.brPill,
    border: Border.all(color: AppColors.border, width: 1),
  );

  /// Etiqueta verde ("Instalación en curso"): tinte de éxito, pastilla.
  static BoxDecoration sectionLabelGreen = BoxDecoration(
    color: AppColors.successTint,
    borderRadius: AppRadius.brPill,
  );

  /// Barra inferior: fondo claro, hairline superior, esquinas superiores lg.
  static BoxDecoration footerBar = const BoxDecoration(
    color: AppColors.footerBarBg,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(AppRadius.lg),
      topRight: Radius.circular(AppRadius.lg),
    ),
    border: Border(top: BorderSide(color: AppColors.border, width: 1)),
  );

  /// Item activo de la barra inferior: tinte naranja, radio md.
  static BoxDecoration footerItemActive = BoxDecoration(
    color: AppColors.footerActiveBg,
    borderRadius: AppRadius.brMd,
  );

  /// Estilo de botón naranja (compat). Prefiere `AppButton` para nuevo código.
  static ButtonStyle orangeButton({double radius = AppRadius.sm, double fontSize = 13}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    );
  }
}
