import '../../core/app_config.dart';
import '../api/api_client.dart';
import '../models/evento.dart';
import '../models/gestion_item.dart';

/// Fuentes de la búsqueda: eventos + visitas realizadas + incidencias realizadas.
/// Cada método devuelve (éxito, lista); en error devuelve (false, []) — el
/// controlador marca "resultados parciales" como en Android.
class SearchRepository {
  final ApiClient _api;

  SearchRepository(this._api);

  Future<(bool, List<Evento>)> getEventos({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getEvents,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) return (false, <Evento>[]);
      return (true, _parseList(json['eventos'], Evento.fromJson));
    } catch (_) {
      return (false, <Evento>[]);
    }
  }

  Future<(bool, List<GestionItem>)> getVisitas({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getVisitasRealizadas,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) return (false, <GestionItem>[]);
      return (true, _parseList(json['visitas'], GestionItem.fromVisita));
    } catch (_) {
      return (false, <GestionItem>[]);
    }
  }

  Future<(bool, List<GestionItem>)> getIncidencias({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    try {
      final json = await _api.getJson(
        AppConfig.getIncidenciasRealizadas,
        query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
        noCache: true,
      );
      if (json['success'] != true) return (false, <GestionItem>[]);
      return (true, _parseList(json['incidencias'], GestionItem.fromIncidencia));
    } catch (_) {
      return (false, <GestionItem>[]);
    }
  }

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final out = <T>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) out.add(fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }
}
