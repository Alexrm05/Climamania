import 'package:shared_preferences/shared_preferences.dart';
import '../core/ui_text.dart';
import '../data/models/user_session.dart';

/// Espejo de `SharedPreferences("climamania_prefs")` de Android.
/// Mantiene las MISMAS claves para que el contrato con el backend no cambie.
class SessionService {
  final SharedPreferences _prefs;

  SessionService(this._prefs);

  // Claves (idénticas a las de la app Android)
  static const _kUsuario = 'usuario';
  static const _kNombre = 'nombre';
  static const _kApellidos = 'apellidos';
  static const _kEmail = 'email';
  static const _kRol = 'rol';
  static const _kEquipo = 'equipoInstaladores';
  static const _kLoggedIn = 'logged_in';
  static const _kRemember = 'remember_user';
  static const _kRememberedUser = 'remembered_username';
  static const _kRememberedPass = 'remembered_password';

  /// Auto-login: hay sesión si `logged_in` y `usuario` no vacío (igual que Java).
  bool get isLoggedIn {
    final logged = _prefs.getBool(_kLoggedIn) ?? false;
    final user = (_prefs.getString(_kUsuario) ?? '').trim();
    return logged && user.isNotEmpty;
  }

  String get usuario => _prefs.getString(_kUsuario) ?? '';
  String get nombre => _prefs.getString(_kNombre) ?? '';
  String get apellidos => _prefs.getString(_kApellidos) ?? '';
  String get email => _prefs.getString(_kEmail) ?? '';
  String get rol => UiText.sanitizeDbValue(_prefs.getString(_kRol));

  bool get rememberUser => _prefs.getBool(_kRemember) ?? false;
  String get rememberedUsername => _prefs.getString(_kRememberedUser) ?? '';
  String get rememberedPassword => _prefs.getString(_kRememberedPass) ?? '';

  /// Nombre a mostrar: nombre → usuario → [fallback].
  String displayName({String fallback = 'Instalador'}) {
    final n = UiText.sanitizeDbValue(nombre);
    if (n.isNotEmpty) return n;
    final u = UiText.sanitizeDbValue(usuario);
    if (u.isNotEmpty) return u;
    return fallback;
  }

  /// Iniciales para nombrar archivos subidos (k_iniciales o derivadas del nombre).
  String get iniciales {
    final stored = UiText.sanitizeDbValue(_prefs.getString('k_iniciales'));
    if (stored.isNotEmpty) {
      final up = stored.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return up.isEmpty ? 'APP' : up.substring(0, up.length > 6 ? 6 : up.length);
    }
    final n = UiText.sanitizeDbValue(nombre);
    if (n.isEmpty) return 'APP';
    final letters = n
        .split(RegExp(r'[^A-Za-zÀ-ÿ]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(3)
        .join()
        .toUpperCase();
    return letters.isEmpty ? 'APP' : letters;
  }

  /// usuario para peticiones; si está vacío usa el recordado (como Android).
  String get usuarioForRequests {
    final u = UiText.sanitizeDbValue(usuario);
    if (u.isNotEmpty) return u;
    return UiText.sanitizeDbValue(rememberedUsername);
  }

  /// Lee el equipo aceptando String (normal) o int (legado).
  String readEquipo() {
    final v = _prefs.getString(_kEquipo);
    if (v != null && v.trim().isNotEmpty) return v.trim();
    final i = _prefs.getInt(_kEquipo);
    return (i ?? 0).toString();
  }

  Future<void> saveLogin(
    UserSession user, {
    required bool remember,
    required String usuarioInput,
    required String passwordInput,
  }) async {
    await _prefs.setString(
      _kUsuario,
      user.usuario.isNotEmpty ? user.usuario : usuarioInput,
    );
    await _prefs.setString(_kNombre, user.nombre);
    await _prefs.setString(_kApellidos, user.apellidos);
    await _prefs.setString(_kEmail, user.email);
    await _prefs.setString(_kRol, user.rol);
    await _prefs.setString(_kEquipo, user.equipoInstaladores.trim());
    await _prefs.setBool(_kLoggedIn, true);

    if (remember) {
      await _prefs.setBool(_kRemember, true);
      await _prefs.setString(_kRememberedUser, usuarioInput);
      await _prefs.setString(_kRememberedPass, passwordInput);
    } else {
      await _prefs.setBool(_kRemember, false);
      await _prefs.remove(_kRememberedUser);
      await _prefs.remove(_kRememberedPass);
    }
  }

  /// Nota privada local por usuario+referencia (no se sube al servidor).
  String privateNote(String referencia) =>
      _prefs.getString('private_comment_${usuario}_$referencia') ?? '';

  Future<void> savePrivateNote(String referencia, String text) =>
      _prefs.setString('private_comment_${usuario}_$referencia', text);

  /// Limpia todo (cerrar sesión) y borra los datos recordados.
  Future<void> clear() async {
    await _prefs.clear();
  }

  /// Borra solo los datos recordados (botón "Limpiar" del login).
  Future<void> clearRemembered() async {
    await _prefs.setBool(_kRemember, false);
    await _prefs.remove(_kRememberedUser);
    await _prefs.remove(_kRememberedPass);
  }
}
