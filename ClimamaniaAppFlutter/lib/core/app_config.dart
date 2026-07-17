/// Configuración central de la API. Única fuente de verdad para la URL base,
/// la api_key y las rutas de endpoints. Mismo backend que la app Android.
class AppConfig {
  AppConfig._();

  static const String baseUrl = 'https://app.clminstal.es/api/';
  static const String apiKey = 'TEST123';

  // Endpoints (Paso 1)
  static const String loginPhp = 'login.php';
  static const String getEvents = 'get_events.php';
  static const String getVisitasPendientes = 'get_visitas_pendientes.php';
  static const String getIncidenciasPendientes = 'get_incidencias_pendientes.php';

  // Búsqueda (Fase 2)
  static const String getVisitasRealizadas =
      'get_visitas_realizadas_busqueda.php';
  static const String getIncidenciasRealizadas =
      'get_incidencias_realizadas_busqueda.php';

  // Detalle del pedido (Fase 3)
  static const String getPedido = 'get_pedido.php';
  static const String addComentario = 'add_comentario.php';
  static const String eliminarComentario = 'eliminar_comentario.php';

  // Flujo de instalación (Fase 3)
  static const String uploadFoto = 'upload_foto.php';
  static const String eliminarFoto = 'eliminar_foto.php';
  static const String getFoto = 'get_foto.php';
  static const String finalizarInstalacion = 'finalizar_instalacion.php';
  static const String generarConformePdf = 'generar_conforme_cliente_pdf.php';
  static const String generarBoePdf = 'generar_boe_pdf.php';
  static const String getBoeEquipos = 'get_boe_equipos_revision.php';
  static const String guardarBoeEquipos = 'guardar_boe_equipos_revision.php';
  static const String enviarDocumentacion =
      'enviar_documentacion_instalacion.php';

  // Visitas (Fase 4)
  static const String getVisitasPendientesDetalle =
      'get_visitas_pendientes_detalle.php';
  static const String getVisitaDetalle = 'get_visita_detalle.php';
  static const String visitaEnviarComentarios = 'visita_enviar_comentarios.php';
  static const String visitaEnviarFotos = 'visita_enviar_fotos.php';
  static const String visitaCambiarPrioridad = 'visita_cambiar_prioridad.php';
  static const String visitaCerrar = 'visita_cerrar.php';

  // Incidencias (Fase 5)
  static const String getIncidenciasPendientesDetalle =
      'get_incidencias_pendientes_detalle.php';
  static const String getIncidenciaDetalle = 'get_incidencia_detalle.php';
  static const String incidenciaEnviarComentarios =
      'incidencia_enviar_comentarios.php';
  static const String incidenciaEnviarFotos = 'incidencia_enviar_fotos.php';
  static const String incidenciaCambiarPrioridad =
      'incidencia_cambiar_prioridad.php';
  static const String incidenciaCerrar = 'incidencia_cerrar.php';

  // Adicionales / Presupuestos (Fase 6)
  static const String getAdicionalesCatalogo = 'get_adicionales_catalogo.php';
  static const String guardarPresupuesto = 'guardar_presupuesto_instalador.php';
  static const String getAdicionalesMasUsados =
      'get_adicionales_mas_usados.php';
  static const String getPresupuestos = 'get_presupuestos_instalador.php';
  static const String getPresupuestoDetalle =
      'get_presupuesto_instalador_detalle.php';
  static const String actualizarPresupuesto =
      'actualizar_presupuesto_instalador.php';
  static const String cancelarPresupuesto =
      'cancelar_presupuesto_instalador.php';

  /// URL para mostrar una foto/documento por su ruta (get_foto.php?doc=...).
  static String fotoUrl(String doc) =>
      '${baseUrl}get_foto.php?api_key=$apiKey&doc=${Uri.encodeComponent(doc)}';

  // Web (fases posteriores)
  static const String installWebBase =
      'https://app.clminstal.es/gestion_instalacion.php?ref=';
}
