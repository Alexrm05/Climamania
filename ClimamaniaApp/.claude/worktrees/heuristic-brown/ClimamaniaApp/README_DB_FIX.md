Instrucciones rápidas para corregir la conexión MySQL

1) Objetivo
- Asegurar que la base de datos `ynrlpmed_fulls` existe y que el usuario `ynrlpmed_admin` puede conectarse con la contraseña definida en `.env`.

2) Archivos creados (local)
- `.env` : contiene las variables de entorno con las credenciales (NO subir al repositorio; subir solo al servidor por FTP/Panel).
- `fix_db.sql` : script SQL para ejecutar en MySQL como administrador si necesitas crear la BD/usuario o ajustar permisos.

3) Ejecutar `fix_db.sql`
- Usando cliente MySQL (CLI) en el servidor o desde tu máquina con acceso:
  ```bash
  mysql -u root -p < fix_db.sql
  ```
  o importar `fix_db.sql` desde phpMyAdmin.

4) Alternativa: actualizar `.env`
- Si ya existe el usuario/DB, simplemente coloca `.env` en el directorio del proyecto en el servidor (o define variables de entorno en el panel de hosting) con los valores correctos.
- Asegúrate de permisos restrictivos: `chmod 600 .env`.

5) Probar conexión
- Conéctate por SSH al servidor y en el directorio del proyecto ejecuta:
  ```bash
  php try_connect.php
  ```
  Debe devolver `Conexión OK. MySQL version: ...` o en caso de fallo registrar el error en `debug_db_error.log`.

6) Limpieza y seguridad
- Borrar `fix_db.sql` del servidor después de usarlo: `rm fix_db.sql`.
- No dejar `.env` en el repositorio. Añadir a `.gitignore` (ya se hizo).
- Eliminar o proteger `debug_db_error.log` si contiene mensajes sensibles.
