# Panorama Cloud 0.4.5.3 — BCU Web Service

## Objetivo

Reemplaza la consulta al handler web de cotizaciones del BCU por el Web Service SOAP oficial `awsbcucotizaciones`.

## Cambios

- `/api/cotizaciones` conserva el mismo contrato para el frontend.
- `lib/bcu.js` consulta el Web Service SOAP del BCU desde Vercel.
- Se solicita código de moneda `0` y grupo `0` para obtener las monedas disponibles del período y luego se seleccionan USD, EUR, JPY, CLP, PYG y UI.
- Se mantiene la caché de 6 horas.
- Se mantiene validación TLS normal; no se desactiva la verificación de certificados.
- Se agregan mensajes de error para HTTP y SOAP Fault.

## Motivo

El endpoint web anterior presentaba en Vercel `UNABLE_TO_VERIFY_LEAF_SIGNATURE`. Esta versión usa el servicio de integración documentado por el BCU.
