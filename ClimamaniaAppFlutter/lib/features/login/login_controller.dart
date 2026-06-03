import 'package:flutter/foundation.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/session_service.dart';

/// Controlador (tipo ViewModel) de la pantalla de Login.
class LoginController extends ChangeNotifier {
  final AuthRepository _auth;
  final SessionService _session;

  LoginController(this._auth, this._session);

  bool _loading = false;
  bool get isLoading => _loading;

  // Prefill desde "Recordar usuario".
  bool get initialRemember => _session.rememberUser;
  String get initialUsuario =>
      _session.rememberUser ? _session.rememberedUsername : '';
  String get initialPassword =>
      _session.rememberUser ? _session.rememberedPassword : '';

  Future<LoginResult> submit({
    required String usuario,
    required String password,
    required bool remember,
  }) async {
    _loading = true;
    notifyListeners();
    final result = await _auth.login(
      usuario.trim(),
      password.trim(),
      remember: remember,
    );
    _loading = false;
    notifyListeners();
    return result;
  }

  Future<void> clearRemembered() => _session.clearRemembered();
}
