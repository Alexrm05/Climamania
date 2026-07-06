import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_colors.dart';
import '../shell/detail_scaffold.dart';
import '../shell/nav_destinations.dart';

/// Reproductor de vídeo. Réplica de VideoPlayerActivity + content_video_player:
/// marco negro, "Cargando...", controles, y fallback a la siguiente URL si una
/// falla. Recibe una lista de URLs (o una sola).
class VideoPlayerScreen extends StatefulWidget {
  final List<String> urls;

  const VideoPlayerScreen({super.key, required this.urls});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  int _index = 0;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _playNext();
  }

  Future<void> _playNext() async {
    // Libera el controlador anterior (si lo hubiera).
    final old = _controller;
    _controller = null;
    await old?.dispose();

    if (_index >= widget.urls.length) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final url = widget.urls[_index];
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _loading = false;
      });
      await c.play();
    } catch (_) {
      await c.dispose();
      // Falla esta fuente: probar la siguiente.
      _index += 1;
      await _playNext();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      activeIndex: NavBranch.home,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                child: Center(child: _videoArea()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                child: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoArea() {
    if (_failed) {
      return const Text('No se pudo reproducir el vídeo',
          style: TextStyle(color: Colors.white, fontSize: 14));
    }
    final c = _controller;
    if (_loading || c == null || !c.value.isInitialized) {
      return const Text('Cargando...',
          style: TextStyle(color: Colors.white, fontSize: 14));
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(c),
          _Controls(controller: c),
        ],
      ),
    );
  }
}

/// Controles mínimos: play/pausa al tocar + barra de progreso.
class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  const _Controls({required this.controller});

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
                () => c.value.isPlaying ? c.pause() : c.play()),
            child: Center(
              child: AnimatedOpacity(
                opacity: c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.play_circle_fill,
                    size: 64, color: Colors.white70),
              ),
            ),
          ),
        ),
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          colors: const VideoProgressColors(playedColor: AppColors.primary),
        ),
      ],
    );
  }
}
