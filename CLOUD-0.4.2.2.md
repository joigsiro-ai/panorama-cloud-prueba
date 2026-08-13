# Panorama Cloud 0.4.2.2 — Card Reconciliation Fix

- `card_months` se guarda por la clave natural `(user_id, card_id, month)`.
- Deduplica estados por tarjeta/mes antes de persistir.
- La conciliación espera confirmación de Supabase antes de cerrar.
- Los errores de escritura muestran el mensaje real devuelto por Supabase.
- La carga de `card_months` no reemplaza filas válidas por un payload JSON vacío.
