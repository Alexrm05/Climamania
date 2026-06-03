ALTER TABLE ClimaInstal_ControlUbicacionesEventos
    ADD COLUMN token_evento VARCHAR(64) NULL AFTER tipo_evento,
    ADD UNIQUE KEY uq_tipo_token_evento (tipo_evento, token_evento);

ALTER TABLE ClimaInstal_Fotografias
    ADD COLUMN TokenEvento VARCHAR(64) NULL AFTER Clave,
    ADD UNIQUE KEY uq_clave_token_evento (Clave, TokenEvento);
