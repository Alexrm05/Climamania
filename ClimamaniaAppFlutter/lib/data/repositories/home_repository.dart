import '../../core/app_config.dart';
import '../../core/ui_text.dart';
import '../api/api_client.dart';
import '../models/evento.dart';
import '../models/pending_count.dart';

/// Respuesta de `get_events.php` ya normalizada.
class EventsResponse {
  final bool success;
  final String message;
  final List<Evento> eventos;

  const EventsResponse({
    required this.success,
    required this.message,
    required this.eventos,
  });
}

class HomeRepository {
  final ApiClient _api;

  HomeRepository(this._api);

  Future<EventsResponse> getEvents({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    final json = await _api.getJson(
      AppConfig.getEvents,
      query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
    );

    final eventos = <Evento>[];
    final rawList = json['eventos'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          eventos.add(Evento.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return EventsResponse(
      success: json['success'] == true,
      message: UiText.sanitizeDbValue(json['message']?.toString()),
      eventos: eventos,
    );
  }

  Future<PendingCount> getVisitasPendientes({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    final json = await _api.getJson(
      AppConfig.getVisitasPendientes,
      query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
      noCache: true,
    );
    return PendingCount.fromJson(json);
  }

  Future<PendingCount> getIncidenciasPendientes({
    required String rol,
    required String equipo,
    required String usuario,
  }) async {
    final json = await _api.getJson(
      AppConfig.getIncidenciasPendientes,
      query: {'rol': rol, 'equipo': equipo, 'usuario': usuario},
      noCache: true,
    );
    return PendingCount.fromJson(json);
  }
}
