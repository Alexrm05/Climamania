ALTER TABLE ClimaInstal_PresupuestosInstalador
    ADD INDEX idx_presupuesto_usuario (UsuarioInstalador);

ALTER TABLE ClimaInstal_PresupuestosInstalador
    ADD INDEX idx_presupuesto_estado (Estado);

ALTER TABLE ClimaInstal_PresupuestosInstalador
    ADD INDEX idx_presupuesto_scope_date (EquipoInstaladores, FechaPresupuesto);
