CREATE TABLE IF NOT EXISTS ClimaInstal_ControlUbicacionesEventos (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    referencia VARCHAR(64) NULL,
    id_presupuesto BIGINT UNSIGNED NULL,
    numero_pedido VARCHAR(64) NULL,
    tipo_evento VARCHAR(50) NOT NULL,
    token_evento VARCHAR(64) NULL,
    latitud DECIMAL(10,7) NOT NULL,
    longitud DECIMAL(10,7) NOT NULL,
    fecha_hora DATETIME NOT NULL,
    usuario VARCHAR(100) NULL,
    origen VARCHAR(30) NOT NULL DEFAULT 'APP_ANDROID',
    PRIMARY KEY (id),
    KEY idx_referencia (referencia),
    KEY idx_id_presupuesto (id_presupuesto),
    KEY idx_tipo_evento_fecha (tipo_evento, fecha_hora),
    UNIQUE KEY uq_tipo_token_evento (tipo_evento, token_evento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
