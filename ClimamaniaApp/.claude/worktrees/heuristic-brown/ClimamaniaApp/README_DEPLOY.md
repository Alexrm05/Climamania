Despliegue rápido

Archivos que debes subir por FileZilla (mínimo):
- `login.php`
- `con_env.php` (si puedes, colócalo fuera del webroot y ajusta la ruta en `login.php`)

Archivos a crear en servidor (no subir, usar variables de entorno o panel del hosting):
- Definir variables de entorno: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`, `DB_CHARSET`.

Archivos que NO deben permanecer en producción (elimina en FileZilla):
- `test_db.php` (script de pruebas)
- `debug_db_error.log` (logs de depuración)
- `con.php` (contiene credenciales en texto plano) — si el nombre `con.php` no se borra desde Windows, bórralo manualmente desde el panel/FTP.

Pasos después de subir:
1. Configurar variables de entorno en el panel del hosting o en la configuración de PHP-FPM/Apache.
2. Probar la conexión con `test_db.php` (solo mientras depuras), luego eliminarlo.
3. Asegurar permisos de archivos: `con_env.php` con permisos restrictivos.
