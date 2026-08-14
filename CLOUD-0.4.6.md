# Panorama Cloud 0.4.6 — Presupuesto + Transferencias

## Presupuesto
- Nuevo filtro por cuenta de origen.
- Nueva agrupación por cuenta.
- Agrupar por cuenta y por categoría son modos mutuamente excluyentes.
- Los gastos pendientes/parciales se muestran antes que los pagados, sin importar su fecha.

## Transferencias
- Cada traspaso genera dos asientos vinculados:
  - gasto/salida en la cuenta origen;
  - ingreso/entrada en la cuenta destino.
- Ambos asientos tienen efecto patrimonial neutro en los totales generales.
- Editar o eliminar una transferencia actúa sobre el par completo.
- El script SQL migra transferencias antiguas de una sola fila al nuevo modelo.

## Tarjetas
- Se eliminan símbolos `$` fijos en cuotas, detalle, Presupuesto de tarjetas y Evolución proyectada.
- Todos esos importes usan la moneda real de la tarjeta.

## Auth
- Recuperación de contraseña usa `redirectTo: `${window.location.origin}/`` para funcionar tanto en local como en Vercel.

## Requisitos
Ejecutar `CLOUD-0.4.6-transfer-double-entry.sql` una vez en Supabase antes de usar esta versión.
