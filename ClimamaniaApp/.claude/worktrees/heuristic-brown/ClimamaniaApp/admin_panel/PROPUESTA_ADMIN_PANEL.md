Propuesta: Admin Panel de Escritorio (ClimaMania)

- Resumen ejecutivo
  - Se propone una app de escritorio para administrar el backend actual de ClimaMania.
  - Objetivo: centralizar cambios operativos y reducir tareas manuales.
  - Alcance inicial: Windows; base reutilizable para macOS y Android.

- Objetivos
  - Control total sobre datos criticos (usuarios, eventos, comentarios, fotos).
  - Parametrizar configuraciones hoy hardcodeadas (emails, API keys).
  - Trazabilidad con auditoria de cambios.

- Que hara la app (funcionalidades)
  - Usuarios y roles
    - Altas, bajas, cambios de rol y reseteo de contraseña.
  - Configuracion global
    - Gestion de correos de notificacion por finalizacion.
    - Rotacion de API keys y secretos.
  - Eventos e instalaciones
    - Ver, editar, reasignar equipo y cambiar estado.
  - Finalizaciones
    - Ver historico, revertir estado y reintentar notificaciones.
  - Comentarios
    - Ver, editar y eliminar comentarios de instaladores.
  - Fotografias
    - Listar por referencia/clave, eliminar y re-etiquetar.
  - Pedidos (Prestashop)
    - Vista detallada en modo lectura.

- Tecnologia propuesta
  - App de escritorio: .NET MAUI.
  - Backend admin: PHP + MySQL con endpoints /admin/*.
  - Autenticacion: login admin con token (no reutiliza API key publica).

- Beneficios
  - Menos dependencias de cambios directos en servidor.
  - Reduccion de errores por cambios manuales.
  - Trazabilidad y control de acceso por roles.
  - Preparado para ampliarse a macOS/Android sin rehacer todo.

- Entregables
  - App de escritorio (Windows) con login y panel principal.
  - Backend admin con endpoints protegidos.
  - Tablas nuevas: Admin_Users, Admin_Settings, Admin_Audit.
  - Documentacion tecnica y manual de uso.

- Fases
  - Fase 1: login admin + settings (emails, API keys).
  - Fase 2: gestion de eventos, comentarios y fotos.
  - Fase 3: hardening, auditoria y despliegue.
  - Fase 4: soporte macOS/Android.

- Riesgos y mitigacion
  - Cambios en datos sensibles -> auditoria obligatoria.
  - Seguridad de credenciales -> mover a variables de entorno.
  - Dependencia de endpoints actuales -> crear endpoints admin separados.

- Proximos pasos
  - Validar alcance con negocio.
  - Aprobar stack y plan de fases.
  - Iniciar implementacion de backend admin y login.
