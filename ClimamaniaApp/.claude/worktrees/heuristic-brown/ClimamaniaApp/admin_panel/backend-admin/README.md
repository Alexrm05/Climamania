Admin backend (PHP)

- Ubicacion: /admin_panel/backend-admin/
- Endpoints: /admin/\* (ver carpeta admin/)

Requisitos

- PHP 7.4+ y PDO MySQL.
- Acceso a la misma base de datos que la app actual.

Instalacion rapida

1. Ejecutar el esquema SQL:
   - Archivo: schema_admin.sql
2. Crear un usuario admin inicial.
   - Genera hash:
     php -r "echo password_hash('ChangeMe123', PASSWORD_DEFAULT);"
   - Inserta usuario:
     INSERT INTO Admin_Users (usuario, password_hash, rol, activo, created_at, updated_at)
     VALUES ('admin', 'HASH_AQUI', 'superadmin', 1, NOW(), NOW());

Autenticacion

- Login: POST /admin/login
- Header para endpoints protegidos:
  Authorization: Bearer <token>

Notas

- Este backend usa getDBConnection() desde conexion.php.
- Mover credenciales a variables de entorno es recomendado.
