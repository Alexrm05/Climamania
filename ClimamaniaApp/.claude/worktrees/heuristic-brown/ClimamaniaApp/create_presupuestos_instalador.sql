CREATE TABLE IF NOT EXISTS `ClimaInstal_PresupuestosInstalador` (
  `ID_Presupuesto` INT NOT NULL AUTO_INCREMENT,
  `NumeroPedido` VARCHAR(64) NOT NULL,
  `NombreCliente` VARCHAR(255) NOT NULL,
  `DireccionCliente` TEXT NULL,
  `Telefono` VARCHAR(80) NULL,
  `EmailCliente` VARCHAR(255) NULL,
  `FotoFirma` VARCHAR(255) NULL,
  `PdfPresupuesto` VARCHAR(255) NULL,
  `FechaPresupuesto` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `FechaAceptacion` DATETIME NULL,
  `EquipoInstaladores` VARCHAR(100) NULL,
  `UsuarioInstalador` VARCHAR(100) NULL,
  `ImporteSinIva` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `ImporteIva` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `ImporteConIva` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `Estado` VARCHAR(30) NOT NULL DEFAULT 'ACEPTADO',
  `Origen` VARCHAR(30) NOT NULL DEFAULT 'APP_ANDROID',
  `FechaEnvioMail` DATETIME NULL,
  `MailEnviado` TINYINT(1) NOT NULL DEFAULT 0,
  `MailError` VARCHAR(500) NULL,
  `date_add` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_upd` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ID_Presupuesto`),
  KEY `idx_presupuesto_numero_pedido` (`NumeroPedido`),
  KEY `idx_presupuesto_fecha` (`FechaPresupuesto`),
  KEY `idx_presupuesto_equipo` (`EquipoInstaladores`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ClimaInstal_PresupuestosInstalador_Lineas` (
  `ID_Linea` INT NOT NULL AUTO_INCREMENT,
  `ID_Presupuesto` INT NOT NULL,
  `OrdenLinea` INT NOT NULL DEFAULT 1,
  `Cantidad` DECIMAL(10,2) NOT NULL,
  `Articulo` VARCHAR(120) NOT NULL,
  `Descripcion` TEXT NULL,
  `PrecioUnitarioSinIva` DECIMAL(12,6) NOT NULL DEFAULT 0.000000,
  `PrecioTotalLinea` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `IvaPct` DECIMAL(6,3) NOT NULL DEFAULT 21.000,
  `PrecioTotalLineaConIva` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `IvaFallback` TINYINT(1) NOT NULL DEFAULT 0,
  `date_add` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_upd` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`ID_Linea`),
  KEY `idx_lineas_presupuesto` (`ID_Presupuesto`),
  KEY `idx_lineas_articulo` (`Articulo`),
  CONSTRAINT `fk_presupuesto_lineas_presupuesto`
    FOREIGN KEY (`ID_Presupuesto`)
    REFERENCES `ClimaInstal_PresupuestosInstalador` (`ID_Presupuesto`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

