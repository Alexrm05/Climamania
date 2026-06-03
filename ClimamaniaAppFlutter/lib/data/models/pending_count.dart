/// Respuesta de `get_visitas_pendientes.php` / `get_incidencias_pendientes.php`.
class PendingCount {
  final bool success;
  final int pendientes;

  const PendingCount({required this.success, required this.pendientes});

  factory PendingCount.fromJson(Map<String, dynamic> j) {
    final raw = j['pendientes'];
    final count = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    return PendingCount(success: j['success'] == true, pendientes: count);
  }
}
