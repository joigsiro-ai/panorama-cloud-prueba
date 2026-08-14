# Panorama Cloud 0.4.6.1 — Account Group UX

- La agrupación por cuenta ahora muestra:
  - cuánto ingresó en la cuenta;
  - cuánto salió de la cuenta;
  - neto mensual (Ingresó - Salió).
- Las transferencias de doble asiento participan naturalmente:
  - salida en la cuenta origen;
  - entrada en la cuenta destino.
- Se corrige el checkbox gigante de las filas agrupadas por cuenta.
- No modifica Supabase, transferencias, RLS ni cálculos generales.
- No requiere SQL nuevo.
