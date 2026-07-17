import 'package:flutter/material.dart';

import '../../core/fecha.dart';
import '../../core/ui_text.dart';
import '../../data/models/evento.dart';
import '../../data/models/gestion_item.dart';
import '../../data/repositories/search_repository.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../calendar/event_styles.dart';

enum SearchKind { evento, visita, incidencia }

/// Una fila de resultado ya formateada para pintar.
class SearchResult {
  final String title;
  final String subtitle;
  final String address;
  final String meta;
  final Color accent;
  final Color metaColor;
  final SearchKind kind;
  final bool canOpen;
  final String detailTitle;
  final String navRef;
  final String navCliente;
  final String navId; // id de visita/incidencia

  const SearchResult({
    required this.title,
    required this.subtitle,
    required this.address,
    required this.meta,
    required this.accent,
    required this.metaColor,
    required this.kind,
    required this.canOpen,
    required this.detailTitle,
    this.navRef = '',
    this.navCliente = '',
    this.navId = '',
  });
}

class EventSearchController extends ChangeNotifier {
  final SearchRepository _repo;
  final SessionService _session;

  EventSearchController(this._repo, this._session);

  bool loading = false;
  bool _disposed = false;
  String statusText =
      'Introduce un dato y pulsa buscar para consultar eventos, visitas e incidencias.';

  List<SearchResult> eventos = [];
  List<SearchResult> visitas = [];
  List<SearchResult> incidencias = [];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> search(String queryRaw) async {
    final query = queryRaw.trim();
    if (query.isEmpty) return;

    loading = true;
    statusText = 'Buscando eventos, visitas e incidencias...';
    eventos = [];
    visitas = [];
    incidencias = [];
    _notify();

    final rol = _session.rol;
    final equipo = _session.readEquipo();
    final usuario = _session.usuarioForRequests;
    final q = query.toLowerCase();

    // Lanzamos las 3 fuentes en paralelo.
    final fEventos = _repo.getEventos(rol: rol, equipo: equipo, usuario: usuario);
    final fVisitas = _repo.getVisitas(rol: rol, equipo: equipo, usuario: usuario);
    final fIncid =
        _repo.getIncidencias(rol: rol, equipo: equipo, usuario: usuario);

    final (okE, eventosRaw) = await fEventos;
    final (okV, visitasRaw) = await fVisitas;
    final (okI, incidRaw) = await fIncid;

    final hasError = !okE || !okV || !okI;

    eventos = eventosRaw
        .where((e) => _eventSearchText(e).contains(q))
        .map(_buildEventoResult)
        .toList();
    visitas = visitasRaw
        .where((v) => v.searchText.contains(q))
        .map((v) => _buildGestionResult(v, SearchKind.visita))
        .toList();
    incidencias = incidRaw
        .where((i) => i.searchText.contains(q))
        .map((i) => _buildGestionResult(i, SearchKind.incidencia))
        .toList();

    final total = eventos.length + visitas.length + incidencias.length;
    if (hasError) {
      statusText = total == 0
          ? 'No se pudieron cargar todos los resultados de búsqueda'
          : '$total resultados encontrados (parciales)';
    } else if (total == 0) {
      statusText = 'No se encontraron resultados para "$query"';
    } else if (total == 1) {
      statusText = '1 resultado encontrado';
    } else {
      statusText = '$total resultados encontrados';
    }

    loading = false;
    _notify();
  }

  // --- Construcción de resultados ---

  String _eventSearchText(Evento e) => [
        e.referencia,
        e.nombreCliente,
        e.direccion,
        e.telefono,
        e.whatsapp,
        e.equipoInstaladores,
        e.estado,
        e.detalles,
        e.comentarios,
        e.emailEquipo,
        e.titulo,
      ].join(' ').toLowerCase();

  SearchResult _buildEventoResult(Evento e) {
    final ref = e.referencia;
    final cliente = e.nombreCliente;
    var title = ref;
    if (cliente.isNotEmpty) title = title.isEmpty ? cliente : '$ref · $cliente';
    if (title.isEmpty) title = 'Sin título';

    final fechaHora = _buildFechaHora(e.start, e.end);
    final estado = _buildEstadoLabel(e.estado);
    final subtitle = [
      'Evento',
      if (fechaHora.isNotEmpty) fechaHora,
      if (estado.isNotEmpty) estado,
    ].join(' · ');

    final equipo = e.equipoInstaladores;
    return SearchResult(
      title: title,
      subtitle: subtitle,
      address: _buildContactLine(
          EventStyles.formatDireccion(e.direccion), e.telefono, e.whatsapp, ''),
      meta: equipo.isNotEmpty ? 'Equipo $equipo' : 'Equipo no asignado',
      metaColor: equipo.isNotEmpty
          ? EventStyles.forEquipo(equipo)
          : AppColors.textMuted,
      accent: EventStyles.forEvento(e),
      kind: SearchKind.evento,
      canOpen: EventStyles.isPedidoValido(ref),
      detailTitle: 'Detalle de instalación',
      navRef: ref,
      navCliente: cliente,
    );
  }

  SearchResult _buildGestionResult(GestionItem g, SearchKind kind) {
    final esVisita = kind == SearchKind.visita;
    final tipo = esVisita ? 'Visita' : 'Incidencia';

    String title;
    if (esVisita) {
      title = 'Visita';
      if (g.id.isNotEmpty && g.id != 'null') title += ' #${g.id}';
    } else {
      title = g.referencia.isNotEmpty
          ? g.referencia
          : (g.id.isNotEmpty && g.id != 'null'
              ? 'Incidencia #${g.id}'
              : 'Incidencia');
    }
    if (g.cliente.isNotEmpty) title += ' · ${g.cliente}';

    final estadoVisual = _buildGestionStatusLabel(g.estado);
    final fechaVisual = estadoVisual == 'Pendiente'
        ? _formatServerDate(g.fechaSolicitud)
        : (g.fechaResolucion.isNotEmpty
            ? _formatServerDate(g.fechaResolucion)
            : _formatServerDate(g.fechaSolicitud));
    final subtitle = fechaVisual.isEmpty
        ? '$tipo · $estadoVisual'
        : '$tipo · $estadoVisual · $fechaVisual';

    final color = esVisita ? AppColors.infoFg : AppColors.warningFg;

    return SearchResult(
      title: title,
      subtitle: subtitle,
      address: _buildContactLine(
          _buildDireccion(g.direccion, g.poblacion), g.telefono, '', g.email),
      meta: _buildMetaLine(tipo, g.prioridad, g.equipoId, g.solicitante),
      metaColor: color,
      accent: color,
      kind: kind,
      canOpen: g.id.isNotEmpty && g.id != 'null' && g.id != '0',
      detailTitle: esVisita ? 'Detalle de visita' : 'Detalle de incidencia',
      navId: g.id,
    );
  }

  // --- Helpers de formato (port de SearchEventsActivity) ---

  String _buildFechaHora(String startStr, String endStr) {
    final start = UiText.sanitizeDbValue(startStr);
    if (start.isEmpty) return '';
    final s = DateTime.tryParse(start.replaceFirst(' ', 'T'));
    if (s == null) return start;
    final end = UiText.sanitizeDbValue(endStr);
    final e = end.isEmpty ? null : DateTime.tryParse(end.replaceFirst(' ', 'T'));
    final fecha = Fecha.dma(s);
    final inicio = Fecha.hora(s);
    final rango = e != null ? '$inicio - ${Fecha.hora(e)}' : inicio;
    return '$fecha · $rango';
  }

  String _buildEstadoLabel(String estadoRaw) {
    final clean = UiText.sanitizeDbValue(estadoRaw);
    if (clean.isEmpty) return '';
    return clean.toLowerCase().contains('finalizado')
        ? 'Finalizado'
        : 'Sin finalizar';
  }

  String _buildGestionStatusLabel(String estadoRaw) {
    final estado = UiText.sanitizeDbValue(estadoRaw).trim();
    if (estado == '1' || estado.toLowerCase() == 'pendiente') return 'Pendiente';
    return 'Realizada';
  }

  String _buildDireccion(String direccion, String poblacion) {
    final dir = UiText.sanitizeDbValue(direccion);
    final pob = UiText.sanitizeDbValue(poblacion);
    if (dir.isEmpty) return pob;
    if (pob.isEmpty) return dir;
    return '$dir - $pob';
  }

  String _formatServerDate(String rawDate) => Fecha.parse(rawDate);

  String _buildContactLine(
      String direccion, String telefono, String whatsapp, String email) {
    final dir = UiText.sanitizeDbValue(direccion);
    final tel = UiText.sanitizeDbValue(telefono);
    final wa = UiText.sanitizeDbValue(whatsapp);
    final mail = UiText.sanitizeDbValue(email);
    final lines = <String>[
      if (dir.isNotEmpty) 'Dirección: $dir',
      if (tel.isNotEmpty) 'Teléfono: $tel',
      if (wa.isNotEmpty) 'WhatsApp: $wa',
      if (mail.isNotEmpty) 'Email: $mail',
    ];
    return lines.isEmpty ? 'Datos de contacto no disponibles' : lines.join('\n');
  }

  String _buildMetaLine(
      String tipo, String prioridad, String equipoId, String solicitante) {
    final meta = StringBuffer(tipo);
    final pri = UiText.sanitizeDbValue(prioridad);
    final eq = UiText.sanitizeDbValue(equipoId);
    final sol = UiText.sanitizeDbValue(solicitante);
    if (pri.isNotEmpty) meta.write(' · Prioridad $pri');
    if (eq.isNotEmpty && eq != 'null') meta.write(' · Equipo $eq');
    if (sol.isNotEmpty) meta.write(' · Solicita $sol');
    return meta.toString();
  }
}
