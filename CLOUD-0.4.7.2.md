# Panorama Cloud 0.4.7.2 — Fix guardado de movimientos

- Corrige un bloqueo de validación HTML que impedía guardar ingresos y otros movimientos normales.
- `cardPaymentApplied` ya no queda `required` cuando el movimiento no es un pago de tarjeta.
- Mantiene la validación de importe aplicado únicamente para pagos de tarjeta entre monedas diferentes.
- Conserva el comportamiento automático cuando la cuenta y la tarjeta usan la misma moneda.
