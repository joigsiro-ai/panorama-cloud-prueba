# Panorama Cloud 0.4.7.6 — Recurrentes con destino y día

Parte de **0.4.7.5 — Fix Inicio y transferencias**.

## Cambios

- Los gastos recurrentes que no usan tarjeta permiten seleccionar una **cuenta específica**.
- Los recurrentes con tarjeta mantienen la selección de **tarjeta específica**.
- Se agrega **día del mes** (1 a 28) para cada recurrente.
- La lista de recurrentes muestra en una sola línea: **categoría · destino · día**.
- El modo **Aplicar recurrentes al mes** muestra la misma información de destino.
- Al generar el movimiento mensual, Panorama usa la cuenta/tarjeta y el día configurados en el recurrente.
- Los recurrentes existentes, que no tenían cuenta ni día, se normalizan usando la **cuenta predeterminada** y el **día 1**, conservando compatibilidad.
- La moneda del resumen de aplicación masiva se calcula según la cuenta o tarjeta configurada en cada recurrente.

No requiere migración SQL: `accountId` y `day` se conservan en el `payload` existente de `recurring_expenses`.
