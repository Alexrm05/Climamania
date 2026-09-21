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
-- ClimaInstal_ParteMateriales_Relacionados: materiales que aparecen por
-- defecto en todos los partes (los habituales), con su unidad y cantidad
-- prevista. Los mantiene la oficina. Con "+" el técnico añade cualquier otro
-- de la categoría 711 de PrestaShop.
--
-- La ubicación al guardar se registra en ClimaInstal_ControlUbicacionesEventos
-- con tipo_evento = 'PARTE_MATERIALES' (tabla ya existente).

CREATE TABLE IF NOT EXISTS ClimaInstal_ParteMateriales (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    pedido VARCHAR(64) NOT NULL,
    articulo VARCHAR(64) NOT NULL,
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
    articulo VARCHAR(64) NOT NULL,
    descripcion VARCHAR(255) NOT NULL DEFAULT '',
    unidad VARCHAR(10) NOT NULL DEFAULT 'ud',
    cantidad_prevista DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    orden INT UNSIGNED NOT NULL DEFAULT 100,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_articulo (articulo),
    KEY idx_activo_orden (activo, orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Materiales por defecto del parte de trabajo. Los códigos de `articulo` son
-- provisionales: sustituir por la referencia real de PrestaShop (categoría
-- 711) para que el precio y el catálogo cuadren. `cantidad_prevista` a 0
-- hasta que la oficina fije la previsión habitual de cada uno.
INSERT IGNORE INTO ClimaInstal_ParteMateriales_Relacionados
    (articulo, descripcion, unidad, cantidad_prevista, orden) VALUES
    ('TUBFRIG14',  'Tubería frigorífica 1/4"',                                   'm',    0, 10),
    ('TUBFRIG38',  'Tubería frigorífica 3/8"',                                   'm',    0, 20),
    ('AISLCOQ',    'Aislamiento coquilla',                                       'm',    0, 30),
    ('CABLE4X15',  'Cable manguera 4x1,5',                                       'm',    0, 40),
    ('TUBDESAG',   'Tubo desagüe',                                               'm',    0, 50),
    ('CANAL6040',  'Canaleta 60x40 / tapas / ángulos',                           'm/ud', 0, 60),
    ('SOPORTE',    'Soporte pared / suelo',                                      'ud',   0, 70),
    ('BOMBACOND',  'Bomba de condensados',                                       'ud',   0, 80),
    ('FUNGIBLE',   'Material fungible (nitrógeno, soldadura, silicona, tacos…)', '-',    0, 90);
