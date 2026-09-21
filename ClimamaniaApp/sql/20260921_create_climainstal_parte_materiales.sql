-- Escandallo: parte de trabajo con el material consumido en cada instalación.
--
-- ClimaInstal_ParteMateriales: una fila por artículo y pedido. La app guarda
-- siempre el parte completo (borra y reinserta las filas del pedido,
-- conservando fecha_creacion). Las horas de llegada/salida del domicilio
-- (sin desplazamientos) se repiten en cada fila. La desviación es
-- cantidad - cantidad_prevista y se calcula al consultar.
-- precio_unitario_sin_iva: precio base de PrestaShop en el momento de
-- registrar, para valorar el material sin depender de precios futuros.
--
-- ClimaInstal_ParteMateriales_Relacionados: materiales por defecto de cada
-- tipo de instalación. articulo_padre es la referencia de PrestaShop del
-- artículo de instalación del pedido (INSTAL40, ...); al abrir el parte se
-- cruzan las líneas del pedido con los padres y se precargan sus materiales,
-- multiplicando cantidad_prevista por las unidades del padre en el pedido.
-- El padre '*' aplica a todos los pedidos (fungibles). Los mantiene la
-- oficina. Con "+" el técnico añade cualquier otro de la categoría 711.
--
-- La ubicación al guardar se registra en ClimaInstal_ControlUbicacionesEventos
-- con tipo_evento = 'PARTE_MATERIALES' (tabla ya existente).

CREATE TABLE IF NOT EXISTS ClimaInstal_ParteMateriales (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    pedido VARCHAR(64) NOT NULL,
    articulo VARCHAR(64) NOT NULL,
    articulo_padre VARCHAR(64) NULL COMMENT 'tipo de instalación del que salió el material',
    descripcion VARCHAR(255) NOT NULL DEFAULT '',
    unidad VARCHAR(10) NOT NULL DEFAULT 'ud',
    cantidad_prevista DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    cantidad DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT 'cantidad real consumida',
    hora_inicio TIME NULL,
    hora_final TIME NULL,
    precio_unitario_sin_iva DECIMAL(12,6) NOT NULL DEFAULT 0.000000,
    usuario VARCHAR(100) NULL,
    equipo_instaladores VARCHAR(100) NULL,
    fecha_creacion DATETIME NOT NULL,
    fecha_edicion DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_pedido (pedido),
    KEY idx_articulo (articulo),
    KEY idx_usuario_fecha (usuario, fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ClimaInstal_ParteMateriales_Relacionados (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    articulo_padre VARCHAR(64) NOT NULL DEFAULT '*',
    articulo VARCHAR(64) NOT NULL,
    descripcion VARCHAR(255) NOT NULL DEFAULT '',
    unidad VARCHAR(10) NOT NULL DEFAULT 'ud',
    cantidad_prevista DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    orden INT UNSIGNED NOT NULL DEFAULT 100,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_padre_articulo (articulo_padre, articulo),
    KEY idx_padre_activo_orden (articulo_padre, activo, orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Materiales por defecto: ver 20260922_alter_parte_materiales_articulo_padre.sql
-- (bloque de ejemplo para INSTAL40; repetir por cada tipo de instalación).
