# Panorama Cloud 0.1.2 — Recuperación de contraseña

- Agrega “¿Olvidaste tu contraseña?” al acceso.
- Envía el correo de recuperación mediante Supabase Auth.
- Procesa el enlace de recuperación y permite definir una nueva contraseña.
- Cierra la sesión de recuperación y vuelve al login después del cambio.
- No modifica todavía la persistencia financiera: continúa local por UUID de Supabase.
