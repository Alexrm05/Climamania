Admin panel: plan y alcance

- Objetivo: crear un panel de administracion de escritorio con soporte inicial en Windows y base reutilizable para macOS y Android.
- Enfoque: app de escritorio Windows primero, backend admin en PHP junto al API existente.

- Estructura del nuevo proyecto (dentro de CLIMAMANIA):
  - /admin_panel/
    - /frontend-desktop/ (app de escritorio)
    - /backend-admin/ (endpoints PHP de administracion)
    - /docs/ (documentacion tecnica y decisiones)

- Stack propuesto:
  - Frontend: .NET MAUI (app de escritorio; Windows ahora, macOS/Android despues).
  - Backend: PHP + MySQL, nuevos endpoints /admin/\*.
  - Autenticacion: login admin con token (no reutilizar API key publica).
  - Nota: no es app web ni panel web embebido.

- Funcionalidades MVP (sugeridas por el codigo actual):
  - Usuarios admin: altas, bajas, roles, reset de password.
  - Configuracion global:
    - Emails de notificacion para finalizacion.
    - Rotacion de API keys/secretos.
  - Eventos/instalaciones: ver, editar, reasignar equipo, cambio de estado.
  - Finalizaciones: ver historico, revertir, reintentar notificacion.
  - Comentarios: ver, editar, eliminar.
  - Fotografias: listar por referencia/clave, eliminar, re-etiquetar.
  - Pedidos (Prestashop): vista detallada (solo lectura).

- Cambios recomendados en backend:
  - Tabla Admin_Users (usuario, hash, rol, activo).
  - Tabla Admin_Settings (emails, plantillas, flags de sistema).
  - Tabla Admin_Audit (accion, usuario, fecha, datos previos).
  - Endpoints:
    - POST /admin/login
    - GET/PUT /admin/settings
    - GET/POST/PUT/DELETE /admin/users
    - GET/POST/PUT/DELETE /admin/events
    - GET/POST/DELETE /admin/comments
    - GET/DELETE /admin/photos
    - GET /admin/orders

- Reglas de seguridad:
  - No credenciales hardcodeadas; usar variables de entorno.
  - Tokens expiran y se revocan.
  - Registrar cambios relevantes en Admin_Audit.

- Fases de entrega:
  - Fase 1: backend admin + login + settings (emails, API keys).
  - Fase 2: gestion de eventos, comentarios y fotos.
  - Fase 3: hardening, auditoria y despliegue.
  - Fase 4: migracion a macOS/Android.

- Proximos pasos:
  - Crear carpeta /admin_panel/.
  - Definir modelo de datos admin (tablas nuevas).
  - Implementar endpoints base de admin.
  - Crear app Windows con pantallas: Login, Dashboard, Settings, Eventos.
