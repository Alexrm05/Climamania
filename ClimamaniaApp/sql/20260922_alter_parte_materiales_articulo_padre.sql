-- Escandallo: los materiales por defecto dependen del tipo de instalación.
--
-- ClimaInstal_ParteMateriales_Relacionados.articulo_padre es la referencia
-- de PrestaShop del artículo de instalación del pedido (INSTAL40, ...). Al
-- abrir el parte, la app cruza las líneas del pedido con los padres y
-- precarga sus materiales, multiplicando cantidad_prevista por las unidades
-- del padre en el pedido. El padre '*' aplica a todos los pedidos (útil para
-- fungibles).
--
-- Ejecutar sobre la base de datos que ya tiene las tablas creadas con
-- 20260921_create_climainstal_parte_materiales.sql.

ALTER TABLE ClimaInstal_ParteMateriales_Relacionados
    ADD COLUMN articulo_padre VARCHAR(64) NOT NULL DEFAULT '*' AFTER id,
    DROP INDEX uq_articulo,
    ADD UNIQUE KEY uq_padre_articulo (articulo_padre, articulo),
    ADD KEY idx_padre_activo_orden (articulo_padre, activo, orden);

ALTER TABLE ClimaInstal_ParteMateriales
    ADD COLUMN articulo_padre VARCHAR(64) NULL AFTER articulo;

-- Materiales de ejemplo para el tipo de instalación INSTAL40. Repetir el
-- bloque por cada tipo (INSTAL50, ...), cambiando articulo_padre y las
-- cantidades previstas. Los códigos de `articulo` son provisionales:
-- sustituir por las referencias reales de la categoría 711 de PrestaShop.
INSERT IGNORE INTO ClimaInstal_ParteMateriales_Relacionados
    (articulo_padre, articulo, descripcion, unidad, cantidad_prevista, orden) VALUES
    ('INSTAL40', 'TUBFRIG14',  'Tubería frigorífica 1/4"',         'm',    4, 10),
    ('INSTAL40', 'TUBFRIG38',  'Tubería frigorífica 3/8"',         'm',    4, 20),
    ('INSTAL40', 'AISLCOQ',    'Aislamiento coquilla',             'm',    8, 30),
    ('INSTAL40', 'CABLE4X15',  'Cable manguera 4x1,5',             'm',    4, 40),
    ('INSTAL40', 'TUBDESAG',   'Tubo desagüe',                     'm',    4, 50),
    ('INSTAL40', 'CANAL6040',  'Canaleta 60x40 / tapas / ángulos', 'm/ud', 2, 60),
    ('INSTAL40', 'SOPORTE',    'Soporte pared / suelo',            'ud',   1, 70),
    ('INSTAL40', 'BOMBACOND',  'Bomba de condensados',             'ud',   0, 80),
    ('*',        'FUNGIBLE',   'Material fungible (nitrógeno, soldadura, silicona, tacos…)', '-', 0, 90);
