CREATE TABLE IF NOT EXISTS ClimaInstal_BoeEquiposRevision (
    id_linea BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    referencia VARCHAR(64) NOT NULL,
    orden_linea INT NOT NULL,
    codigo VARCHAR(120) NOT NULL,
    num_serie VARCHAR(255) NULL,
    usuario_instalador VARCHAR(100) NULL,
    date_add DATETIME NOT NULL,
    date_upd DATETIME NOT NULL,
    PRIMARY KEY (id_linea),
    KEY idx_referencia (referencia),
    KEY idx_referencia_orden (referencia, orden_linea)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
