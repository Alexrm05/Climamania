# Manual de uso completo de la app ClimaMania

## 1. Objetivo de este manual

Este documento explica el uso completo de la app ClimaMania tal y como está implementada actualmente. La idea es que cualquier usuario pueda recorrer toda la aplicación de principio a fin, entender qué hace cada pantalla y saber qué acciones puede realizar en cada una.

Incluye:

- acceso y cierre de sesión
- navegación general
- calendario y detalle de eventos
- ficha completa de pedidos
- flujo completo de instalación
- gestión de fotografías, documentos y vídeos
- visitas
- incidencias
- adicionales y presupuestos
- buscador general
- valoraciones
- web integrada
- BOE y conforme del cliente

Cuando una funcionalidad depende de que exista información previa, de permisos o del estado del caso, se indica expresamente.

---

## 2. Estructura general de la app

La app tiene una estructura común en muchas pantallas:

- barra superior con:
  - menú lateral
  - logotipo
  - botón de refresco
- contenido central de la pantalla
- navegación inferior con:
  - `Calendario`
  - `Inicio`
  - `Valoraciones`
  - `Adicionales`
  - `Web`

Además, existe un menú lateral con accesos a:

- `Inicio`
- `Calendario`
- `Buscar eventos`
- `Adicionales`
- `Web`
- `Cerrar sesión`

En varias pantallas también funciona el gesto de refrescar hacia abajo o el botón superior de refresco.

---

## 3. Inicio de sesión

### 3.1 Pantalla de login

La app comienza en la pantalla de acceso.

Funciones disponibles:

- introducir `usuario`
- introducir `contraseña`
- marcar o desmarcar `Recordar usuario y contraseña`
- mostrar u ocultar la contraseña con el icono del ojo
- borrar credenciales guardadas
- iniciar sesión

### 3.2 Comportamiento del login

Al iniciar sesión correctamente, la app guarda:

- usuario
- nombre
- apellidos
- email
- rol
- equipo de instaladores
- estado de sesión iniciada

Si ya existe una sesión válida, la app puede entrar automáticamente sin pedir credenciales de nuevo.

### 3.3 Cerrar sesión

Desde el menú lateral puede pulsarse `Cerrar sesión`.

Al cerrar sesión:

- se limpia la sesión actual
- la app vuelve a la pantalla de login

---

## 4. Navegación principal

### 4.1 Menú inferior

El menú inferior permite moverse rápidamente entre los módulos principales:

- `Calendario`: agenda de eventos e instalaciones
- `Inicio`: resumen operativo principal
- `Valoraciones`: pantalla con QR de valoración
- `Adicionales`: presupuestos y adicionales
- `Web`: navegación web integrada

### 4.2 Menú lateral

El menú lateral añade accesos directos a:

- pantalla de inicio
- calendario
- buscador general de eventos, visitas e incidencias
- módulo de adicionales
- web
- cierre de sesión

### 4.3 Refresco

Muchas pantallas pueden actualizarse con:

- el botón de refresco superior
- el gesto de deslizar para refrescar, si la pantalla lo soporta

---

## 5. Pantalla de inicio

La pantalla `Inicio` funciona como panel rápido del instalador.

### 5.1 Qué muestra

Muestra información operativa resumida, como:

- saludo con nombre del usuario
- instalación en curso, si existe
- próxima instalación, si existe
- accesos rápidos a llamadas, mapa y WhatsApp según los datos del pedido

### 5.2 Acciones disponibles

Desde esta pantalla se puede:

- abrir la instalación en curso
- abrir la próxima instalación
- llamar al cliente
- abrir la ubicación en mapas
- abrir conversación de WhatsApp
- abrir el listado de visitas pendientes
- abrir el listado de incidencias pendientes
- lanzar una búsqueda global escribiendo texto o un número

Además, la pantalla sirve como resumen rápido de trabajo del día, porque concentra los accesos más frecuentes sin necesidad de entrar primero en el calendario.

### 5.3 Qué busca la búsqueda rápida del inicio

La búsqueda rápida abre el buscador general y permite localizar:

- eventos
- visitas
- incidencias

---

## 6. Calendario

La pantalla `Calendario` muestra la agenda semanal de trabajo.

### 6.1 Navegación temporal

Se puede:

- ir a la semana anterior
- ir a la semana siguiente
- volver a la semana actual con `Hoy`
- deslizar lateralmente sobre el calendario para cambiar de semana

### 6.2 Filtros

El calendario permite trabajar con filtros:

- filtro por equipo
- filtro por estado

El comportamiento del filtro de equipo depende del rol:

- usuarios administradores pueden filtrar manualmente
- usuarios no administradores ven su equipo asignado

### 6.3 Qué se ve en el calendario

En cada celda horaria pueden verse:

- eventos individuales
- grupos de eventos si coinciden en franja

Cada tarjeta muestra información resumida del evento y puede cambiar de color según el equipo.

### 6.4 Acciones desde el calendario

Se puede:

- pulsar un evento individual para abrir su detalle
- pulsar un grupo de eventos para elegir cuál abrir

---

## 7. Buscador general

La pantalla `Buscar eventos` permite buscar de forma centralizada.

### 7.1 Qué busca

Busca en tres grupos:

- `Eventos`
- `Visitas`
- `Incidencias`

### 7.2 Qué encuentra

Puede encontrar:

- eventos del calendario
- visitas realizadas
- visitas pendientes, cuando estén disponibles en la fuente de búsqueda
- incidencias realizadas
- incidencias pendientes, cuando estén disponibles en la fuente de búsqueda

### 7.3 Qué se muestra en cada resultado

Según el tipo, el resultado puede mostrar:

- referencia o id
- cliente
- fecha
- dirección
- teléfono
- estado
- equipo
- prioridad

### 7.4 Qué ocurre al pulsar un resultado

Dependiendo del tipo:

- un evento abre su detalle
- una visita abre su detalle
- una incidencia abre su detalle

---

## 8. Detalle de evento

El detalle de evento es una pantalla operativa rápida asociada a una instalación o cita del calendario.

### 8.1 Información visible

Puede mostrar:

- referencia
- cliente
- dirección
- estado del evento
- observaciones

### 8.2 Botones y accesos posibles

Desde aquí puede haber acceso a:

- `Ver datos instalación`
- `Fotos cliente`
- `Fotos previas`
- `Fotos incidencias`
- `Fotos acabada`
- `Fotos conforme`
- `Documento BOE`
- `Añadir comentarios`
- `Finalizar instalación`
- `Consultar otra`
- `Ir a calendario`

### 8.3 Comentarios del instalador

El instalador puede añadir comentarios que quedan asociados al pedido/evento.

### 8.4 Finalización directa

Existe un flujo de finalización asociado al evento, aunque el flujo principal y más completo de trabajo se apoya en la ficha del pedido y en la pantalla `Realizar instalación`.

---

## 9. Ficha completa del pedido

La ficha completa del pedido es la pantalla detallada de una instalación concreta.

### 9.1 Información que muestra

Puede mostrar:

- referencia del pedido
- cliente
- dirección de instalación
- teléfono
- WhatsApp
- equipo o equipos
- observaciones del pedido
- comentarios del instalador
- datos del evento
- accesos a fotografías del cliente

### 9.2 Acciones directas

Desde esta pantalla se puede:

- llamar al cliente
- abrir WhatsApp
- abrir la dirección en mapas
- guardar comentarios del instalador
- abrir la pantalla `Realizar instalación`

### 9.3 Visitas previas

La ficha incluye un bloque `Visitas previas`.

Comportamiento:

- si no se detecta ninguna visita previa válida, aparece:
  - `NO HA HABIDO NINGUNA VISITA`
- si sí existe una visita previa válida, no aparece esa frase
- en ese caso aparece solo un botón verde:
  - `VER DETALLES DE LA VISITA`

#### Criterio actual para detectar visita previa

La app considera visita previa cuando:

- la visita está finalizada
- coincide el teléfono móvil del pedido
- además existe coincidencia significativa de dirección entre la visita y la instalación

### 9.4 Incidencias previas

También puede aparecer un bloque con incidencias previas asociadas a la referencia.

Desde ahí se puede abrir el detalle de incidencias previas detectadas para esa instalación.

---

## 10. Pantalla `Realizar instalación`

Esta es la pantalla operativa principal durante una instalación.

Está organizada por bloques.

### 10.0 Cabecera de la instalación

En la parte superior se muestran los datos básicos del trabajo en curso:

- referencia
- cliente
- mensaje de apoyo para recordar que hay que completar fotos, comentarios y cierre

### 10.0 bis `Notas privadas`

La pantalla incluye un bloque específico de `Notas privadas`.

Sirve para:

- escribir anotaciones del instalador
- guardarlas solo para uso interno
- conservarlas solo para ese usuario en ese dispositivo

Estas notas:

- no forman parte del documento del cliente
- no sustituyen a los comentarios enviados al pedido
- sirven como recordatorio interno de trabajo

El bloque tiene:

- caja de texto multilínea
- botón `Guardar comentario`

### 10.1 Bloque `Durante la instalación`

El bloque de fotos y documentos está dividido realmente en fases.

#### Antes de la instalación

Incluye:

- `Fotos previas`
- `Incidencias`

`Fotos previas` se usa para dejar constancia del estado inicial antes de empezar el trabajo.

`Incidencias` se usa para subir imágenes de problemas detectados durante el servicio o condiciones relevantes de la instalación.

#### Durante la instalación

Incluye:

- `Fotos acabada`
- `Conforme`

`Fotos acabada` sirve para documentar el resultado final de la instalación.

`Conforme` permite consultar o subir el material relacionado con la conformidad del cliente.

#### Documento BOE

Además aparece el botón:

- `Documento BOE`

Este botón permite consultar la documentación BOE asociada a la instalación cuando exista o cuando el flujo la requiera.

### 10.2 Bloque `Comentarios`

Contiene:

- texto explicativo
- botón `Añadir comentarios`

Permite guardar notas del instalador asociadas a la instalación.

### 10.3 Bloque `Conforme cliente`

Contiene:

- descripción del flujo
- botón `Firma conforme cliente`

Este bloque inicia el flujo documental del cliente:

- decisión sobre BOE
- revisión de equipos BOE si aplica
- firma del conforme
- generación de PDFs
- envío por email de la documentación

### 10.4 Bloque `Cierre`

Contiene:

- descripción
- botón `Finalizar instalación`

Este bloque sirve para cerrar técnicamente la instalación mediante la pantalla final de cierre.

### 10.5 Botón `Volver`

Permite salir de la pantalla y volver a la anterior.

### 10.6 Comentarios locales

La pantalla conserva comentarios del instalador y recarga información del pedido cuando corresponde.

### 10.7 Documentación que puede consultarse desde aquí

Desde esta pantalla pueden abrirse:

- fotos previas
- fotos de incidencia
- fotos de instalación acabada
- fotos del conforme
- BOE generado

Y, cuando el flujo ya ha avanzado, esta pantalla se convierte en el punto central desde el que el instalador comprueba si la documentación ha quedado completa antes de cerrar la instalación.

---

## 11. Gestión de fotos, documentos y vídeos

La app usa una pantalla común para listar y abrir archivos relacionados con una instalación.

### 11.1 Categorías que puede mostrar

Según el contexto, puede mostrar:

- fotos del cliente
- fotos previas
- fotos de incidencias
- fotos de instalación acabada
- fotos del conforme
- documento BOE

### 11.2 Qué tipos de archivo soporta

La app soporta visualización de:

- imágenes: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic`, `.heif`
- vídeos: `.mp4`, `.mov`, `.m4v`, `.3gp`, `.webm`, `.avi`, `.mkv`
- documentos: especialmente `.pdf`

### 11.3 Cómo se muestran

- las imágenes se muestran como tarjetas con miniatura
- los documentos aparecen como archivos con botón `Abrir`
- los vídeos aparecen como archivos con botón `Ver video`

### 11.4 Subida de archivos

En las categorías que lo permiten, aparece el botón `Subir`.

Opciones de subida:

- `Cámara (foto)`
- `Galería (foto)`
- `Galería (video)`

### 11.5 Comportamiento de la subida

La app:

- comprime imágenes cuando hace falta
- mantiene vídeos sin compresión destructiva
- identifica tipo MIME
- sube el archivo al servidor
- recarga automáticamente el listado cuando la subida termina bien

### 11.6 Apertura de archivos

La app puede:

- abrir imágenes en navegador/visor web
- abrir vídeos en el reproductor interno
- abrir PDFs en visor web o webview, según el caso

---

## 12. Reproductor de vídeo

La app tiene una pantalla específica para vídeo.

### 12.1 Qué hace

Permite reproducir vídeos asociados a visitas, incidencias o archivos del pedido.

### 12.2 Comportamiento

- prueba varias URLs si hay varias disponibles
- muestra estado de carga
- si una fuente falla, intenta la siguiente
- tiene botón `Volver`

---

## 13. Flujo de cierre técnico de instalación

La pantalla `Finalizar instalación` se usa para cerrar el trabajo técnico.

### 13.1 Qué comprueba o recoge

Recoge:

- fotos previas disponibles o no
- fotos de instalación acabada disponibles o no
- fotos de conforme disponibles o no
- importe cobrado en metálico
- importe cobrado por VISA
- si hubo extras
- satisfacción percibida del cliente
- observaciones finales

### 13.2 Elementos de la pantalla

Normalmente incluye:

- bloque de control de fotos
- bloque de extras
- valoración por estrellas
- observaciones finales
- botón `Finalizar instalación`
- botón `Volver`

### 13.3 Qué ocurre al finalizar

Al finalizar:

- se captura la ubicación
- se envía el cierre al backend
- la instalación queda marcada como finalizada según la lógica del servidor

---

## 14. Flujo completo del conforme del cliente

Este es el flujo documental principal asociado al final de la instalación.

### 14.1 Paso 1: decisión de BOE

La pantalla `ConformeClienteBoeDecisionActivity` pregunta si la instalación requiere BOE.

Opciones:

- no requiere BOE
- sí requiere BOE

Esta decisión determina el flujo posterior.

### 14.2 Paso 2: revisión de equipos para BOE

Si la instalación requiere BOE, se abre la pantalla de revisión de equipos.

### 14.3 Pantalla de revisión BOE

En `ConformeClienteSeriesBoeActivity` se puede:

- ver los equipos ya guardados
- ver código
- ver número de serie
- añadir equipo
- eliminar equipo
- guardar y continuar
- volver

### 14.4 Reglas de revisión BOE

Los equipos del BOE salen de una revisión guardada, no del origen bruto.

Eso permite:

- corregir series
- quitar equipos que no correspondan
- añadir los que falten

### 14.5 Paso 3: pantalla de conformidad del cliente

En `ConformeClienteConformidadActivity` se realiza la conformidad final.

#### Información que aparece

- texto legal de conformidad
- observaciones
- datos del firmante

#### Qué puede hacer el usuario

- escribir observaciones
- elegir quién firma:
  - `Cliente / titular del pedido`
  - `Representante autorizado del cliente`
- firmar en el panel manuscrito
- limpiar la firma
- aceptar
- volver

### 14.6 Comportamiento del firmante

La app contempla dos tipos de firmante:

- cliente o titular del pedido
- representante autorizado del cliente

Según lo seleccionado:

- cambia el texto que se usa en el PDF final
- se adapta el bloque correspondiente del firmante

### 14.7 Generación del PDF de conformidad

Al aceptar:

- se valida la firma
- se captura ubicación
- se genera el PDF de conformidad en backend
- se guarda en el sistema documental
- queda listo para su envío por email

### 14.8 Generación del PDF BOE

Si `requiere_boe = true`:

- se genera también el PDF BOE
- se genera como documento único
- incluye todas las máquinas/equipos revisados
- cada equipo incluye:
  - Parte A
  - Parte B

### 14.9 Envío por email

Una vez generada la documentación:

- siempre se envía el conforme firmado
- si aplica, también se envía el BOE

Destinatarios:

- cliente
- correos internos configurados

### 14.10 Consulta posterior de la documentación

Después de generarse, los documentos pueden abrirse desde la propia instalación:

- `Conforme`
- `Documento BOE`

---

## 15. Detalle del PDF de conformidad

Aunque el usuario no genera el PDF manualmente, es importante entender qué refleja.

El PDF del conforme incluye:

- datos del cliente
- datos de la empresa instaladora
- dirección de instalación
- declaraciones de conformidad
- observaciones
- ubicación y fecha/hora de firma
- sello/firma de empresa
- firma manuscrita del cliente o representante

Si no se escriben observaciones:

- el recuadro de observaciones queda en blanco

Si firma como cliente:

- el PDF muestra `Cliente / titular del pedido`

Si firma como representante:

- el PDF muestra `Representante autorizado del cliente`
- y se añade el texto de representación correspondiente

---

## 16. Detalle del PDF BOE

El PDF BOE:

- solo se genera si la instalación lo requiere
- se compone en backend
- usa la revisión de equipos guardada
- genera un único documento final

### 16.1 Estructura

Incluye por cada máquina:

- Parte A
- Parte B

### 16.2 Fondo del BOE

El fondo del BOE se toma de la plantilla configurada por usuario en la base de datos del sistema.

### 16.3 Datos incluidos

Incluye:

- comprador
- instalación
- equipo
- marca
- modelo
- número de serie
- gas
- firmas correspondientes

---

## 17. Módulo de visitas pendientes

La pantalla de visitas pendientes lista las visitas que todavía requieren gestión.

### 17.1 Qué muestra cada visita

Puede mostrar:

- id de visita
- cliente
- dirección
- teléfono
- fecha
- prioridad
- equipo

### 17.2 Acciones rápidas

Desde el listado pueden existir accesos a:

- llamar
- abrir ubicación
- abrir WhatsApp o mensajería, según el dato disponible

### 17.3 Apertura del detalle

Al pulsar una visita se abre su detalle.

---

## 18. Detalle de visita

La pantalla de detalle de visita muestra toda la información de una visita concreta.

### 18.1 Qué muestra

- cliente
- dirección
- teléfono
- prioridad
- equipo
- fecha de solicitud
- usuario que la solicita

### 18.2 Historial o muro

La visita tiene un bloque de `Historial` o muro con mensajes asociados.

### 18.3 Ficheros y fotos

Muestra los archivos subidos a la visita:

- imágenes
- vídeos
- documentos

### 18.4 Acciones

Botones disponibles:

- `Gestionar visita`
- `Volver`

El botón de gestión abre la pantalla operativa para actuar sobre la visita.

---

## 19. Gestión de visita

En la pantalla de gestión de visita se decide qué hacer con ella.

### 19.1 Acciones disponibles

- enviar comentarios escritos al muro
- subir fotos o vídeos
- cambiar prioridad
- finalizar o cancelar la visita
- volver

### 19.2 Comentarios escritos

Abre un cuadro de texto para redactar y enviar un comentario al historial de la visita.

### 19.3 Subir fotos o vídeos

Permite:

- tomar foto con cámara
- elegir foto de galería
- elegir vídeo de galería
- en algunos casos, capturar vídeo según permisos y flujo

### 19.4 Cambiar prioridad

Puede cambiarse entre:

- Alta
- Media
- Baja

### 19.5 Finalizar o cancelar visita

Abre la pantalla común de cierre para completar el cierre o cancelación.

---

## 20. Cierre de visita

El cierre de visita se hace desde la pantalla común `CerrarGestionActivity`.

### 20.1 Qué permite

Para visitas permite:

- finalizar visita
- cancelar visita

### 20.2 Datos requeridos

En cancelación:

- motivo obligatorio

En finalización:

- información de cierre según el caso

### 20.3 Resultado

Tras cerrar correctamente:

- la pantalla vuelve
- el detalle se actualiza
- la visita deja de estar pendiente según el flujo del backend

---

## 21. Visitas previas

La pantalla `VisitasPreviasActivity` lista las visitas previas relacionadas con una instalación.

### 21.1 Cómo se llega

Se accede desde la ficha del pedido mediante el botón:

- `VER DETALLES DE LA VISITA`

### 21.2 Qué permite

Permite:

- ver el listado de visitas previas detectadas
- abrir el detalle de una visita concreta

---

## 22. Módulo de incidencias pendientes

La pantalla de incidencias pendientes es equivalente al módulo de visitas, pero para incidencias.

### 22.1 Qué muestra cada incidencia

- id de incidencia
- cliente
- dirección
- teléfono
- prioridad
- fecha
- equipo

### 22.2 Acciones rápidas

Puede incluir:

- llamar
- abrir mapas
- mensajería

### 22.3 Apertura del detalle

Pulsando una incidencia se abre su detalle.

---

## 23. Detalle de incidencia

La pantalla de detalle de incidencia es equivalente a la de visita, pero especializada en incidencias.

### 23.1 Qué muestra

- cliente
- dirección
- teléfono
- prioridad
- equipo
- fecha de solicitud
- usuario que la solicita

### 23.2 Historial

Muestra el historial o muro de la incidencia.

### 23.3 Ficheros y fotos

Muestra archivos asociados:

- imágenes
- vídeos
- documentos

### 23.4 Acciones

- `Gestionar incidencia`
- `Volver`

---

## 24. Gestión de incidencia

La pantalla de gestión de incidencia permite actuar sobre una incidencia concreta.

### 24.1 Acciones disponibles

- enviar comentarios escritos
- subir fotos o vídeos
- cambiar prioridad
- finalizar o cancelar incidencia
- volver

### 24.2 Comentarios

Se añaden al historial o muro de la incidencia.

### 24.3 Fotos y vídeos

Permite subir pruebas gráficas o visuales del problema o su resolución.

### 24.4 Cambiar prioridad

Opciones:

- Alta
- Media
- Baja

### 24.5 Finalizar o cancelar incidencia

Abre la pantalla común de cierre.

---

## 25. Cierre de incidencia

Desde la pantalla común de cierre, en incidencias puede hacerse:

- finalización de incidencia
- cancelación de incidencia

### 25.1 Datos habituales

Puede requerir:

- texto de resolución
- motivo de cancelación

### 25.2 Resultado

Tras completarse:

- la incidencia se actualiza
- deja de figurar como pendiente si corresponde

---

## 26. Incidencias previas

La app tiene una pantalla para consultar incidencias previas relacionadas con una referencia.

### 26.1 Cómo se llega

Desde la ficha del pedido, cuando hay incidencias previas disponibles.

### 26.2 Qué permite

- ver el listado de incidencias previas
- abrir el detalle de cualquiera de ellas

---

## 27. Módulo de adicionales y presupuestos

El módulo `Adicionales` cubre todo el trabajo de presupuestos adicionales del instalador.

Tiene dos grandes áreas:

- crear presupuesto nuevo
- buscar presupuestos existentes

---

## 28. Crear un presupuesto nuevo

### 28.1 Contexto del presupuesto

El presupuesto puede ir asociado a una referencia concreta, y la app puede tomar contexto de la instalación actual si existe.

También puede trabajarse sin referencia en algunos casos.

### 28.2 Qué puede hacer el instalador

En el modo de presupuesto nuevo puede:

- buscar artículos del catálogo de adicionales
- añadir líneas
- modificar cantidad
- modificar precio
- eliminar líneas
- ver subtotal, IVA y total
- introducir o revisar el email del cliente
- recoger la firma del cliente
- limpiar firma
- guardar/enviar el presupuesto

### 28.3 Catálogo

La app consulta un catálogo de adicionales y permite construir el presupuesto a partir de artículos definidos.

### 28.4 Firma del cliente

Para cerrar el presupuesto:

- se firma en la app
- la firma queda asociada al presupuesto

### 28.5 Ubicación

En el guardado del presupuesto puede capturarse la ubicación del instalador para trazabilidad.

### 28.6 Resultado

El presupuesto se guarda en backend y puede generar PDF/documentación asociada.

---

## 29. Buscar presupuestos

La pestaña de búsqueda permite localizar presupuestos ya creados.

### 29.1 Qué se puede hacer

- buscar por texto
- filtrar por estado
- navegar por resultados
- abrir el detalle de un presupuesto

### 29.2 Estados

Los presupuestos pueden encontrarse en distintos estados, como:

- aceptado
- cancelado
- otros estados según backend

---

## 30. Detalle de presupuesto

La pantalla de detalle del presupuesto muestra toda la información guardada.

### 30.1 Qué muestra

- cliente
- dirección
- teléfono
- email del cliente
- estado
- referencias internas
- líneas del presupuesto
- importes
- firma
- PDF del presupuesto

### 30.2 Acciones

Puede incluir:

- `Abrir PDF`
- `Ver firma`
- `Cancelar presupuesto`
- `Volver`

Si el presupuesto es editable y el flujo lo permite, también puede haber acción para guardar cambios.

### 30.3 Cancelación de presupuesto

La cancelación ya no aparece en listados.

Ahora el flujo correcto es:

- entrar en el detalle del presupuesto
- bajar hasta la zona inferior
- pulsar `Cancelar presupuesto`
- confirmar la acción en el diálogo de confirmación

### 30.4 Dónde está el botón de cancelar

Está únicamente en el detalle del presupuesto, en la parte inferior de la pantalla, entre el contenido del detalle y el botón `Volver`.

---

## 31. Valoraciones

La pantalla `Valoraciones` está enfocada a facilitar la valoración del servicio por parte del cliente.

### 31.1 Qué muestra

- cabecera de valoraciones
- QR oficial
- instrucciones de uso
- pasos rápidos
- botón `Volver`

### 31.2 Uso

El usuario puede enseñar esa pantalla al cliente para que escanee el código QR con su cámara o lector QR y complete su valoración.

---

## 32. Web integrada

La sección `Web` abre un navegador interno dentro de la app.

### 32.1 Qué carga por defecto

Si no se le pasa una URL concreta, abre:

- `https://www.climamania.com`

### 32.2 Qué soporta

- navegación web normal
- visualización de documentos PDF mediante visor integrado en Google Drive

### 32.3 Uso práctico

Se usa para:

- abrir enlaces web
- mostrar PDFs o documentos cuando se envían a esta pantalla

---

## 33. Soporte de formatos de imagen y vídeo

La app soporta visualización y gestión de varios formatos.

### 33.1 Imágenes

Formatos reconocidos:

- JPG
- JPEG
- PNG
- GIF
- WEBP
- HEIC
- HEIF

### 33.2 Vídeos

Formatos reconocidos:

- MP4
- MOV
- M4V
- 3GP
- WEBM
- AVI
- MKV

### 33.3 PDF

Los PDFs se abren como documento y también se usan en varios flujos:

- presupuestos
- conforme cliente
- BOE

---

## 34. Refrescos y recargas

En distintas pantallas la app permite actualizar datos.

### 34.1 Métodos de refresco

- botón superior de refresco
- gesto pull-to-refresh
- recarga automática después de guardar, enviar o subir contenido

### 34.2 Casos comunes de recarga automática

La app suele recargar tras:

- subir un archivo
- enviar un comentario
- guardar un presupuesto
- cambiar una prioridad
- cerrar una visita
- cerrar una incidencia
- generar documentación

---

## 35. Permisos que puede pedir la app

Según el uso, la app puede solicitar:

- permiso de cámara
- acceso a archivos o contenido multimedia
- ubicación

### 35.1 Para qué usa la cámara

- tomar fotos
- capturar material para visitas e incidencias
- subir imágenes a determinadas secciones

### 35.2 Para qué usa la ubicación

- trazabilidad de ciertos eventos
- finalización de instalación
- firma de conformidad
- presupuestos adicionales

---

## 36. Comportamientos condicionados por el estado

Hay botones o bloques que no siempre aparecen.

### 36.1 BOE

El bloque o el flujo BOE solo tiene sentido si la instalación requiere BOE.

### 36.2 Visitas previas

El bloque cambia según haya o no coincidencias válidas:

- sin coincidencia: mensaje `NO HA HABIDO NINGUNA VISITA`
- con coincidencia: botón `VER DETALLES DE LA VISITA`

### 36.3 Presupuestos

La opción `Cancelar presupuesto` solo aparece donde corresponde y según el estado del presupuesto.

### 36.4 Subida de archivos

El botón `Subir` solo aparece en categorías habilitadas para carga.

---

## 37. Flujo recomendado de trabajo de instalación

Una forma práctica de usar la app durante una instalación es esta:

1. Entrar por `Calendario` o `Inicio`.
2. Abrir la ficha completa del pedido.
3. Revisar:
   - dirección
   - teléfono
   - WhatsApp
   - visitas previas
   - incidencias previas
4. Entrar en `Realizar instalación`.
5. Gestionar durante la instalación:
   - fotos
   - incidencias
   - comentarios
6. Si procede, completar:
   - BOE
   - conforme del cliente
7. Generar documentación y enviar por email.
8. Finalizar la instalación desde el bloque `Cierre`.

---

## 38. Flujo recomendado para visitas

1. Abrir `Visitas pendientes`.
2. Entrar al detalle.
3. Revisar:
   - cliente
   - dirección
   - teléfono
   - prioridad
   - historial
4. Entrar en `Gestionar visita`.
5. Según necesidad:
   - enviar comentario
   - subir fotos o vídeos
   - cambiar prioridad
   - finalizar o cancelar

---

## 39. Flujo recomendado para incidencias

1. Abrir `Incidencias pendientes`.
2. Entrar al detalle.
3. Revisar:
   - cliente
   - dirección
   - teléfono
   - prioridad
   - historial
4. Entrar en `Gestionar incidencia`.
5. Según necesidad:
   - enviar comentario
   - subir fotos o vídeos
   - cambiar prioridad
   - finalizar o cancelar

---

## 40. Flujo recomendado para presupuestos adicionales

1. Entrar en `Adicionales`.
2. Crear presupuesto nuevo o buscar uno existente.
3. Si es nuevo:
   - añadir líneas
   - revisar cantidades y precios
   - comprobar email del cliente
   - recoger firma
   - guardar/enviar
4. Si ya existe:
   - abrir detalle
   - abrir PDF
   - revisar firma
   - cancelar si fuera necesario

---

## 41. Resumen de pantallas disponibles

La app incluye estas áreas funcionales visibles para el usuario:

- Login
- Inicio
- Calendario
- Buscar eventos
- Detalle de evento
- Ficha completa del pedido
- Realizar instalación
- Finalizar instalación
- Decisión de BOE
- Revisión de equipos BOE
- Firma conforme cliente
- Listado de fotos/documentos
- Reproductor de vídeo
- Visitas pendientes
- Detalle de visita
- Gestión de visita
- Visitas previas
- Incidencias pendientes
- Detalle de incidencia
- Gestión de incidencia
- Incidencias previas
- Adicionales
- Detalle de presupuesto
- Valoraciones
- Web integrada

---

## 42. Resumen de funcionalidades incluidas

La app permite actualmente:

- iniciar y cerrar sesión
- recordar credenciales
- mostrar u ocultar contraseña
- borrar credenciales guardadas
- navegar por menú lateral y menú inferior
- ver resumen operativo en inicio
- abrir próxima instalación o instalación en curso
- llamar, mapear y abrir WhatsApp
- buscar eventos, visitas e incidencias
- ver calendario semanal
- cambiar de semana
- volver a la semana actual
- filtrar por equipo
- filtrar por estado
- abrir detalle de eventos
- ver ficha completa del pedido
- guardar comentarios del instalador
- revisar visitas previas
- revisar incidencias previas
- abrir la pantalla de instalación
- consultar fotos y documentos por categorías
- subir fotos y vídeos donde aplica
- visualizar imágenes, PDFs y vídeos
- gestionar visitas
- gestionar incidencias
- cambiar prioridades
- cerrar o cancelar visitas
- cerrar o cancelar incidencias
- crear presupuestos adicionales
- firmar presupuestos
- abrir PDF de presupuesto
- cancelar presupuestos desde su detalle
- decidir si una instalación requiere BOE
- revisar equipos BOE
- generar BOE
- firmar el conforme del cliente
- generar el PDF de conformidad
- enviar documentación por email
- finalizar la instalación con trazabilidad
- mostrar QR de valoraciones
- abrir contenido web y PDFs en webview

---

## 43. Observaciones finales

Este manual describe la app según la funcionalidad actualmente implementada en código.

El siguiente paso recomendable es convertir este documento en un PDF de manual de usuario, con:

- portada
- índice
- capturas
- secciones por módulo
- versión
- fecha

Así quedará listo para entregar a usuarios internos o externos.
