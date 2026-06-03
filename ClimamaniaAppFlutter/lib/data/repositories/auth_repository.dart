import 'package:dio/dio.dart';
import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../../services/session_service.dart';
import '../api/api_client.dart';
import '../models/user_session.dart';

/// Resultado de un intento de login.
class LoginResult {
  final bool success;
  final UserSession? user;
  final String? error;

  const LoginResult.ok(this.user)
      : success = true,
        error = null;
  const LoginResult.fail(this.error)
      : success = false,
        user = null;
}

class AuthRepository {
  final ApiClient _api;
  final SessionService _session;

  AuthRepository(this._api, this._session);

  /// Llama a `login.php` (mismos parámetros que la app Android) y, si tiene
  /// éxito, persiste la sesión.
  Future<LoginResult> login(
    String usuario,
    String password, {
    required bool remember,
  }) async {
    try {
      final json = await _api.postForm(AppConfig.loginPhp, {
        'usuario': usuario,
        // Enviamos ambos nombres de campo por compatibilidad (igual que Java).
        'password': password,
        'contrasenya': password,
      });

      if (json['success'] == true) {
        final user = UserSession.fromJson(json);
        await _session.saveLogin(
          user,
          remember: remember,
          usuarioInput: usuario,
          passwordInput: password,
        );
        return LoginResult.ok(user);
      }

      final msg = UiText.sanitizeDbValue(json['message']?.toString());
      return LoginResult.fail(
        msg.isEmpty ? 'Usuario o contraseña incorrectos' : msg,
      );
    } on DioException catch (e) {
      return LoginResult.fail(_connectionError(e));
    } on FormatException {
      return const LoginResult.fail('Error del servidor: respuesta inválida');
    } catch (e) {
      return LoginResult.fail('Error de conexión: $e');
    }
  }

  String _connectionError(DioException e) {
    final status = e.response?.statusCode;
    if (status != null) {
      return 'Error de conexión (HTTP $status)';
    }
    return 'Error de conexión: ${e.message ?? e.toString()}';
  }
}
