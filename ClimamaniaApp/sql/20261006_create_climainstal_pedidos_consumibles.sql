-- Pedidos de consumibles desde la app del instalador.
--
-- La app solo inserta: cabecera, líneas y las marcas de envío de correo. Los
-- campos de gestión (FechaGestion, ReferenciaGotel, CantidadServida...) los
-- rellena ClimaGEST más adelante; la app no los toca.
--
-- Collation utf8mb4_general_ci, la misma que ClimaSinc_ClimaInstal_Consumibles:
-- con utf8mb4_unicode_ci, cruzar estas tablas con las de consumibles desde
-- ClimaGEST falla por mezcla de collations.

CREATE TABLE IF NOT EXISTS ClimaInstal_PedidosConsumibles (
  Id                  INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  Referencia          VARCHAR(20)  NOT NULL DEFAULT '',
  FechaSolicitud      DATETIME     NOT NULL,
  Usuario             VARCHAR(100) NOT NULL,
  NombreSolicitante   VARCHAR(150) NOT NULL DEFAULT '',
  EmailSolicitante    VARCHAR(150) NOT NULL DEFAULT '',
  Equipo              VARCHAR(100) NOT NULL DEFAULT '',
  Observaciones       TEXT NULL,
  NumLineas           INT          NOT NULL DEFAULT 0,
  TotalSinIVA         DECIMAL(12,2) NOT NULL DEFAULT 0,
  Estado              VARCHAR(20)  NOT NULL DEFAULT 'SOLICITADO',
  EmailComprasEnviado TINYINT(1)   NOT NULL DEFAULT 0,
  FechaEmailCompras   DATETIME NULL,
  EmailConfirmacionEnviado TINYINT(1) NOT NULL DEFAULT 0,
  FechaEmailConfirmacion   DATETIME NULL,
  ErrorEmail          VARCHAR(500) NULL,
  -- Gestión futura desde ClimaGEST (la app NO los toca)
  FechaGestion        DATETIME NULL,
  UsuarioGestion      VARCHAR(50) NULL,
  ReferenciaGotel     VARCHAR(50) NULL,
  NotasInternas       TEXT NULL,
  FechaCreacion       DATETIME NOT NULL,
  FechaModificacion   DATETIME NOT NULL,
  KEY idx_usuario_fecha (Usuario, FechaSolicitud),
  KEY idx_equipo_fecha (Equipo, FechaSolicitud),
  KEY idx_estado (Estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS ClimaInstal_PedidosConsumibles_Lineas (
  Id                  INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  IdPedido            INT NOT NULL,
  Linea               INT NOT NULL,
  IdConsumible        INT NOT NULL,
  IdGotel             INT NOT NULL,
  Codigo              VARCHAR(20)  NOT NULL,
  Descripcion         VARCHAR(1024) NOT NULL DEFAULT '',
  TextoFormato        VARCHAR(60)  NOT NULL DEFAULT '',
  UnidadVenta         VARCHAR(20)  NOT NULL DEFAULT '',
  UnidadesPorFormato  DECIMAL(12,4) NOT NULL DEFAULT 1,
  CantidadFormatos    DECIMAL(12,2) NOT NULL,
  CantidadUnidades    DECIMAL(14,4) NOT NULL,
  PrecioFormato       DECIMAL(12,2) NOT NULL,
  PrecioUnidad        DECIMAL(12,4) NOT NULL,
  ImporteLinea        DECIMAL(12,2) NOT NULL,
  -- Gestión futura desde ClimaGEST (la app NO los toca)
  CantidadServida     DECIMAL(12,2) NULL,
  EstadoLinea         VARCHAR(20) NULL,
  KEY idx_pedido (IdPedido),
  KEY idx_codigo (Codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
