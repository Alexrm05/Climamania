-- Adds fields required for finalization details
ALTER TABLE ClimaInstal_Finalizadas
    ADD COLUMN CobroMetalico DECIMAL(10,2) NULL,
    ADD COLUMN CobroVisa DECIMAL(10,2) NULL,
    ADD COLUMN Extras VARCHAR(10) NULL,
    ADD COLUMN SatisfaccionCliente VARCHAR(10) NULL,
    ADD COLUMN Observaciones TEXT NULL;
