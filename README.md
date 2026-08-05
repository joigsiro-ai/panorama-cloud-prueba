# Panorama Cloud · Prueba 1.1

En esta versión aprenderás la diferencia entre:

- **Autenticación:** quién es el usuario.
- **Base de datos:** qué información pertenece a ese usuario.

La aplicación permite guardar una frase en Supabase y recuperarla al volver a entrar.

## 1. Copiar la configuración de la versión 1.0

Abre el archivo `config.js` de tu versión 1.0 y copia sus dos valores:

```js
export const SUPABASE_URL = "...";
export const SUPABASE_PUBLIC_KEY = "...";
```

Pégalos en el `config.js` de esta versión 1.1.

No copies claves `secret` ni `service_role`.

## 2. Crear la tabla en Supabase

1. Entra a tu proyecto de Supabase.
2. Abre **SQL Editor**.
3. Presiona **New query**.
4. Abre el archivo `SQL_SETUP.sql` incluido en esta carpeta.
5. Copia todo su contenido.
6. Pégalo en el editor.
7. Presiona **Run**.

Esto crea la tabla `user_phrases` y sus reglas de seguridad.

## 3. ¿Qué es RLS?

RLS significa **Row Level Security**: seguridad a nivel de fila.

Las políticas del archivo SQL establecen que:

- un usuario puede leer solamente la fila cuyo `user_id` coincide con el suyo;
- puede crear y modificar solamente su propia frase;
- no puede consultar la frase de otro usuario.

La clave pública del navegador no evita la seguridad: Supabase verifica estas reglas
en el servidor usando la identidad de la sesión.

## 4. Ejecutar la aplicación

Abre la carpeta con Visual Studio Code y ejecuta `index.html` con Live Server.

Ingresa con la misma cuenta que creaste en la versión 1.0.

## 5. Prueba recomendada

1. Escribe una frase.
2. Presiona **Guardar en la nube**.
3. Actualiza la página con F5.
4. Comprueba que la frase vuelve a aparecer.
5. Cierra sesión.
6. Vuelve a iniciar sesión.
7. Comprueba nuevamente que sigue allí.

Más adelante podrás abrir esta misma versión publicada desde otro dispositivo.
