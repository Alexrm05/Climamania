import 'package:flutter/foundation.dart';

/// Historial de pestañas del shell (Calendario · Inicio · Valoraciones ·
/// Adicionales · Web). Permite que la flecha de "volver" de la barra superior
/// y el botón físico de Android regresen a la pestaña anterior que se estaba
/// viendo, en lugar de salir de la app.
class TabHistory extends ChangeNotifier {
  static const _maxLength = 20;
  final List<int> _stack = [];

  bool get canGoBack => _stack.isNotEmpty;

  /// Registra la pestaña [from] de la que salimos al cambiar a otra.
  /// Se llama justo antes de conmutar de rama en la barra inferior.
  void record(int from) {
    if (_stack.isNotEmpty && _stack.last == from) return;
    _stack.add(from);
    if (_stack.length > _maxLength) _stack.removeAt(0);
    notifyListeners();
  }

  /// Devuelve la pestaña anterior y la retira del historial (o null si vacío).
  int? goBack() {
    if (_stack.isEmpty) return null;
    final prev = _stack.removeLast();
    notifyListeners();
    return prev;
  }

  void clear() {
    if (_stack.isEmpty) return;
    _stack.clear();
    notifyListeners();
  }
}
