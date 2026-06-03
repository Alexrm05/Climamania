import '../../core/ui_text.dart';

/// Datos del usuario devueltos por `login.php` y persistidos en sesión.
class UserSession {
  final String usuario;
  final String nombre;
  final String apellidos;
  final String email;
  final String rol;
  final String equipoInstaladores;

  const UserSession({
    required this.usuario,
    required this.nombre,
    required this.apellidos,
    required this.email,
    required this.rol,
    required this.equipoInstaladores,
  });

  factory UserSession.fromJson(Map<String, dynamic> j) {
    String s(String key) => UiText.sanitizeDbValue(j[key]?.toString());

    // equipoInstaladores puede venir como String o como int.
    var equipo = s('equipoInstaladores');
    if (equipo.isEmpty) {
      final raw = j['equipoInstaladores'];
      if (raw is num) equipo = raw.toInt().toString();
    }

    return UserSession(
      usuario: s('usuario'),
      nombre: s('nombre'),
      apellidos: s('apellidos'),
      email: s('email'),
      rol: s('rol'),
      equipoInstaladores: equipo.trim(),
    );
  }
}
