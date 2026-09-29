-- Escandallo: una instalación puede ocupar varios días, así que las horas
-- dejan de ser un único par llegada/salida y pasan a ser una lista de
-- jornadas (fecha + hora de llegada + hora de salida). El material sigue
-- siendo del parte entero, no de cada jornada, y el técnico es el mismo
-- para todo el parte.
--
-- Los partes ya guardados no necesitan migración: si un pedido no tiene
-- jornadas, el servidor construye una con la fecha de creación y las horas
-- que hay en ClimaInstal_ParteMateriales.

CREATE TABLE IF NOT EXISTS ClimaInstal_ParteJornadas (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    pedido VARCHAR(64) NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_final TIME NOT NULL,
    usuario VARCHAR(100) NULL,
    equipo_instaladores VARCHAR(100) NULL,
    fecha_creacion DATETIME NOT NULL,
    fecha_edicion DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_pedido_fecha (pedido, fecha, hora_inicio),
    KEY idx_usuario_fecha (usuario, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
