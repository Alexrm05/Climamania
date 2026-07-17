import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Variantes visuales del botón unificado.
enum AppButtonVariant { primary, secondary, tonal, success, danger, ghost }

/// Tamaños: compacto (40), normal (48), grande (52).
enum AppButtonSize { compact, normal, large }

/// Botón único de la app: unifica colores, alturas y radios. Reemplaza los
/// botones coloreados sueltos (confirm/azul/rojo) y las alturas 38–52.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.normal,
    this.loading = false,
    this.expand = true,
  });

  double get _height => switch (size) {
        AppButtonSize.compact => 40,
        AppButtonSize.normal => 48,
        AppButtonSize.large => 52,
      };

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final disabled = onPressed == null || loading;

    // Colores por variante.
    late final Color bg;
    late final Color fg;
    final bool outlined = variant == AppButtonVariant.secondary;
    final bool ghost = variant == AppButtonVariant.ghost;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppColors.primary;
        fg = AppColors.white;
      case AppButtonVariant.success:
        bg = AppColors.successFg;
        fg = AppColors.white;
      case AppButtonVariant.danger:
        bg = AppColors.errorFg;
        fg = AppColors.white;
      case AppButtonVariant.tonal:
        bg = AppColors.footerActiveBg;
        fg = AppColors.primary;
      case AppButtonVariant.secondary:
        bg = Colors.transparent;
        fg = AppColors.textPrimary;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.primary;
    }

    Widget child;
    if (loading) {
      child = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );
    } else {
      child = Text(label, overflow: TextOverflow.ellipsis);
    }

    final shape = RoundedRectangleBorder(borderRadius: AppRadius.brSm);
    final ButtonStyle style;
    if (outlined) {
      style = OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: shape,
        textStyle: labelStyle,
        minimumSize: Size(0, _height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
    } else if (ghost) {
      style = TextButton.styleFrom(
        foregroundColor: fg,
        shape: shape,
        textStyle: labelStyle,
        minimumSize: Size(0, _height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
    } else {
      style = FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textMuted,
        shape: shape,
        textStyle: labelStyle,
        minimumSize: Size(0, _height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      );
    }

    final Widget button = outlined
        ? OutlinedButton(onPressed: disabled ? null : onPressed, style: style, child: child)
        : ghost
            ? TextButton(onPressed: disabled ? null : onPressed, style: style, child: child)
            : FilledButton(onPressed: disabled ? null : onPressed, style: style, child: child);

    return SizedBox(
      width: expand ? double.infinity : null,
      height: _height,
      child: button,
    );
  }
}
