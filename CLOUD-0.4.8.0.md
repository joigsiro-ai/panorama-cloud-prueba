# Panorama Cloud 0.4.8.0 — API oficial de movimientos

Parte C de Panorama Go.

## Cambio arquitectónico

Se agrega `public.panorama_save_movement(p_input jsonb)` como capa oficial compartida para altas de:

- ingreso por cuenta;
- gasto por cuenta;
- compra con tarjeta en un pago;
- compra con tarjeta en cuotas.

La función:
- toma `auth.uid()` como usuario;
- valida que categoría/cuenta/tarjeta pertenezcan al usuario;
- obtiene moneda desde la cuenta/tarjeta;
- calcula en servidor el mes de facturación usando el día de cierre;
- genera el plan y las cuotas cuando corresponde;
- realiza cada operación en una única transacción PostgreSQL.

Panorama Web 0.4.8.0 deja de construir localmente esos registros y llama al RPC.

Transferencias conservan `panorama_save_transfer`.
Pagos de tarjeta quedan fuera de esta primera centralización.

## Orden de instalación

1. Ejecutar `CLOUD-0.4.8.0-centralized-movement-api.sql` en Supabase.
2. Probar Panorama Web 0.4.8.0 local.
3. Probar altas de cuenta, tarjeta en un pago y tarjeta en cuotas.
4. Recién después desplegar.
