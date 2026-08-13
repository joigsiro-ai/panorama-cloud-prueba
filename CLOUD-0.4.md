# Panorama Cloud 0.4 — Supabase Only

Base: Panorama Cloud 0.3.2.

## Arquitectura
- Supabase es la única fuente de verdad persistente.
- Panorama arranca con modelos en memoria vacíos y los reconstruye desde Supabase.
- Si Supabase no responde, Panorama no cae a una base local.
- `localStorage` fue eliminado del código.
- `sessionStorage` se usa únicamente como caché descartable de cotizaciones públicas del BCU.

## Escrituras
- Las modificaciones se envían inmediatamente a Supabase en una cola serial.
- Se sincronizan solo filas modificadas/eliminadas respecto de la última lectura Cloud.
- Esto evita reemplazar tablas completas y reduce conflictos entre dispositivos.
- Si una escritura falla, Panorama informa el error y vuelve a leer desde Supabase.

## Integridad
- Claves foráneas explícitas entre categorías, cuentas, tarjetas, recurrentes, cuotas y movimientos.
- Borrados dependientes controlados.
- Checks de meses, importes y modalidad de cuotas.
- Una sola cuenta predeterminada por usuario.
- `updated_at` automático mediante triggers.
- RLS reafirmado para usuarios autenticados.

## Respaldos
- Exportar ejecuta `panorama_export_backup()` y genera el JSON directamente desde Supabase.
- Importar ejecuta `panorama_restore_backup()` dentro de una transacción PostgreSQL.
- Si la restauración falla, la transacción completa se revierte.
- Se mantiene compatibilidad de importación con respaldos JSON antiguos de Panorama mediante conversión previa al formato Cloud v2.

## Prueba definitiva
1. Ejecutar `CLOUD-0.4-supabase-only.sql`.
2. Levantar Panorama 0.4 y validar los datos.
3. Borrar todos los datos del sitio/navegador.
4. Volver a iniciar sesión.
5. Panorama debe reconstruirse idéntico desde Supabase.
