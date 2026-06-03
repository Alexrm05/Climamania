import 'package:flutter/foundation.dart';

/// Señal global de "recargar" disparada por el botón de refrescar de la barra
/// superior. Las pantallas que lo soportan (Inicio) la escuchan y recargan.
/// Reproduce el comportamiento del botón de recarga global de `BaseActivity`.
class RefreshSignal extends ChangeNotifier {
  int _tick = 0;
  int get tick => _tick;

  void fire() {
    _tick++;
    notifyListeners();
  }
}
