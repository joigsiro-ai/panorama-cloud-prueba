# Panorama Cloud 0.1.1 — Supabase Auth

Esta versión incorpora la primera conexión real con Supabase.

## Incluye

- Vite + Node como entorno de desarrollo.
- `@supabase/supabase-js`.
- Variables de entorno para URL y Publishable Key.
- Registro con Supabase Auth.
- Inicio de sesión con correo y contraseña.
- Persistencia y renovación automática de sesión.
- Cierre de sesión real en Supabase.
- Identificación del usuario por el UUID de `auth.users`.
- Los datos financieros continúan temporalmente en `localStorage`, separados por UUID de Supabase.

## Próximo paso

Crear/aplicar el esquema PostgreSQL + RLS y migrar gradualmente categorías, cuentas, movimientos, recurrentes y tarjetas a Supabase.
