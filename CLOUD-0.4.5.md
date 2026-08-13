# Panorama Cloud 0.4.5 — Cotizaciones + Bienvenida

- Nueva sección **Cotizaciones** en Configuración: USD, EUR, JPY, CLP, PYG y UI.
- Las cotizaciones se consultan al BCU desde un proxy server-side (`/api/cotizaciones`) para evitar CORS.
- En desarrollo local, Vite expone la misma ruta mediante middleware.
- Caché server-side de 6 horas + caché descartable de sesión en el navegador.
- Tour de bienvenida por usuario.
- La pregunta para ver la presentación aparece una sola vez y se persiste en `app_preferences.preferences` de Supabase.
- Botón **Ver presentación** en Configuración para repetir el recorrido.
- No requiere cambios de esquema SQL.
