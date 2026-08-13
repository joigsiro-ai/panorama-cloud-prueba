# Panorama Cloud 0.3.2 — Persistencia + restauración

Base: Panorama Cloud 0.3.1.

Correcciones:
- `accounts` y `credit_cards` hacen upsert usando la clave real `(user_id, id)`.
- La restauración JSON escribe directamente en Supabase y espera cada etapa.
- Respeta dependencias: categorías → cuentas → tarjetas → recurrentes/cuotas/estados → movimientos.
- Al finalizar vuelve a leer desde Supabase para comprobar que el contenido quedó persistido.
- Los errores de importación muestran el detalle y quedan registrados en consola.
- Conserva las correcciones de Insights y del checkbox de la 0.3.1.
