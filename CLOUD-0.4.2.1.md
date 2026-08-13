# Panorama Cloud 0.4.2.1 — Supabase Session Fix

Base: 0.4.2.

Corrección puntual:
- Restaura las funciones `cloudSelect` y `waitForDatabaseSession`, que por un error de empaquetado
  quedaron referenciadas pero no incluidas en la 0.4.2.
- Conserva los diagnósticos por tabla y la validación/refresco de sesión.
- No cambia esquema SQL ni persistencia.
- localStorage sigue sin utilizarse.
