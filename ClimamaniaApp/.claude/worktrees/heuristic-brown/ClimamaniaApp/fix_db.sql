-- fix_db.sql
-- Crea la base de datos y el usuario con permisos mínimos necesarios.
-- EJECUTA SOLO SI TIENES ACCESO DE ADMIN A MySQL (root)

CREATE DATABASE IF NOT EXISTS `ynrlpmed_fulls` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Cambia 'localhost' por '%' o la IP del servidor si la conexión no es local
CREATE USER IF NOT EXISTS 'ynrlpmed_admin'@'localhost' IDENTIFIED BY 'r&^%1CB%Gxfi';
GRANT SELECT, INSERT, UPDATE, DELETE ON `ynrlpmed_fulls`.* TO 'ynrlpmed_admin'@'localhost';
FLUSH PRIVILEGES;

-- Nota: Si tu servidor MySQL requiere conexiones remotas, crea el usuario para la IP/host adecuado:
-- CREATE USER 'ynrlpmed_admin'@'%' IDENTIFIED BY 'LA_CONTRASEÑA';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON `ynrlpmed_fulls`.* TO 'ynrlpmed_admin'@'%';