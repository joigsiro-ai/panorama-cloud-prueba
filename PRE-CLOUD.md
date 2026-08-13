# Panorama Pre-Cloud 0.2.2

Esta versión conserva toda la lógica de Panorama Vision 2.2.0.18 y agrega una capa previa a la migración real a Cloud.

## Qué se agregó

- Registro e inicio de sesión local por correo y contraseña.
- Separación completa de `localStorage` por usuario.
- Nombre de usuario visible en el encabezado y cierre de sesión.
- Migración automática: al crear el primer usuario, los datos locales existentes de Panorama se copian a ese usuario.
- Exportación con `owner` y `userId` en todas las entidades.
- `supabase-schema.sql` con las tablas objetivo, `user_id`, claves foráneas e RLS.

## Importante

El login de esta edición **no es todavía autenticación Cloud**. La contraseña se conserva como hash SHA-256 en el navegador únicamente para probar el flujo multiusuario. No debe considerarse un mecanismo de seguridad para producción.

Cuando Panorama pase a Cloud, la pantalla de acceso puede mantenerse casi igual y la implementación se sustituirá por Supabase Auth. Los datos dejarán de vivir en el almacenamiento local y pasarán a las tablas definidas en `supabase-schema.sql`.

## Prueba sugerida

1. Abrir Panorama y crear el primer usuario.
2. Confirmar que los datos anteriores siguen disponibles.
3. Cerrar sesión.
4. Crear un segundo usuario y comprobar que comienza con una base independiente.
5. Volver al primer usuario y verificar que sus datos permanecen intactos.
