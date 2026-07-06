import 'package:flutter/material.dart';

/// Imagen de red que prueba una lista de URLs candidatas en orden y se queda
/// con la primera que carga. Réplica de `loadImagePreview`/`buildPhotoCandidates`
/// de Android (get_foto.php → clminstal.es → app.clminstal.es → variantes http).
///
/// Notifica la URL que finalmente cargó vía [onResolved], para poder abrirla
/// luego (visor/descarga) con la misma dirección.
class PhotoNetworkImage extends StatefulWidget {
  final List<String> candidates;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ValueChanged<String>? onResolved;

  const PhotoNetworkImage({
    super.key,
    required this.candidates,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.onResolved,
  });

  @override
  State<PhotoNetworkImage> createState() => _PhotoNetworkImageState();
}

class _PhotoNetworkImageState extends State<PhotoNetworkImage> {
  int _index = 0;

  @override
  void didUpdateWidget(PhotoNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates != widget.candidates) _index = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty || _index >= widget.candidates.length) {
      return _fallback();
    }
    final url = widget.candidates[_index];
    return Image.network(
      url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          // Cargó con éxito: recordamos la URL resuelta.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onResolved?.call(url);
          });
          return child;
        }
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stack) {
        // Falla esta candidata: probamos la siguiente en el próximo frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _index < widget.candidates.length) {
            setState(() => _index++);
          }
        });
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    final exhausted = _index >= widget.candidates.length;
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: Icon(
        exhausted ? Icons.broken_image_outlined : Icons.image_outlined,
        color: const Color(0xFF9E9E9E),
        size: 28,
      ),
    );
  }
}
