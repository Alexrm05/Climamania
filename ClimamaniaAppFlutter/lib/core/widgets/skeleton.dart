import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';

/// Caja "esqueleto" con brillo animado para estados de carga.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadiusGeometry? radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  static const _base = Color(0xFFEAE3DA); // gris cálido
  static const _highlight = Color(0xFFF7F3ED);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.radius ?? AppRadius.brSm;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: const [_base, _highlight, _base],
              stops: const [0.1, 0.5, 0.9],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(_c.value * 2 - 1),
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double slide; // -1 .. 1
  const _SlideGradient(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}
