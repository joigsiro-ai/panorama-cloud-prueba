# Auditoría de integridad — Panorama Cloud 0.4.3

## Regla arquitectónica
Supabase continúa siendo la única fuente de verdad persistente. Las columnas estructuradas de PostgreSQL pasan a tener precedencia sobre `payload`; `payload` queda como compatibilidad/extensión y nunca puede contradecir una FK estructurada al reconstruir el modelo.

## Riesgo alto — corregido

| Operación | Riesgo detectado | Corrección 0.4.3 |
|---|---|---|
| Conciliar estado | `card_months` + posible actualización de tasa podían quedar a medias | RPC `panorama_reconcile_card` |
| Crear/editar compra en cuotas | plan + N movimientos se guardaban por separado | RPC `panorama_save_installment_bundle` |
| Convertir compra a cuotas desde Movimientos | podía quedar el movimiento original junto al nuevo plan | misma RPC elimina el movimiento reemplazado dentro de la transacción |
| Eliminar compra en cuotas | plan y movimientos se eliminaban en escrituras distintas | RPC `panorama_delete_installment_plan` + FK CASCADE |
| Eliminar tarjeta | afecta movimientos, recurrentes, estados, cuotas y compras auxiliares | RPC `panorama_delete_card` |
| Editar/eliminar/reasignar categoría | categoría + nombres desnormalizados + referencias podían divergir | RPC `panorama_update_category` / `panorama_delete_category` |
| Eliminar recurrente | definición y `source_recurring_id` histórico podían quedar inconsistentes | RPC `panorama_delete_recurring` |
| Crear/editar cuenta predeterminada | cambio de predeterminada podía chocar con índice único según el orden | RPC `panorama_save_account` |
| Eliminar cuenta predeterminada | promoción de reemplazo + borrado no eran atómicos; faltaba revisar cuenta destino en transferencias | RPC `panorama_delete_account` |
| Cambiar moneda de cuenta/tarjeta usada | podía dejar movimientos históricos con moneda incompatible | validación server-side; se rechaza si ya existe actividad |

## Integridad adicional
- `card_purchases` incorpora `card_id` estructurado y FK a `credit_cards`.
- Las lecturas de `movements`, `recurring_expenses`, `installment_plans`, `card_months` y `card_purchases` usan las columnas reales de PostgreSQL como fuente canónica.
- Los campos de `payload` ya no pueden “resucitar” una referencia vieja después de que una FK fue modificada/eliminada.
- Las operaciones atómicas se serializan junto con el resto de las escrituras Cloud.

## CRUD que puede seguir siendo directo
Estas operaciones afectan una sola entidad/tabla y no requieren RPC transaccional:
- movimiento normal;
- ingreso/gasto rápido;
- transferencia (se modela como un solo movimiento con origen/destino);
- pago de tarjeta (un solo movimiento);
- compra de tarjeta en un pago (un solo movimiento);
- alta/edición de recurrente;
- agregar recurrente al mes (crea un solo movimiento);
- marcar/desmarcar movimiento como pagado;
- arrastre de pendientes (batch sobre `movements`);
- orden de categorías;
- preferencia de tema/mes.

## Operaciones ya protegidas antes de esta auditoría
- Importación completa: `panorama_restore_backup` (transaccional).
- Reset: `panorama_reset_data` (transaccional).
- Exportación: snapshot generado directamente por `panorama_export_backup`.
- RLS: cada usuario trabaja únicamente con sus filas.

## Pruebas recomendadas para 0.4.3
1. Conciliar estado con y sin guardar nueva tasa.
2. Crear, editar y eliminar compra en cuotas desde Tarjetas.
3. Crear compra en cuotas desde Movimientos.
4. Eliminar tarjeta que tenga recurrentes, estados y cuotas.
5. Editar nombre de categoría usada y eliminarla reasignando.
6. Eliminar recurrente que ya haya generado movimientos.
7. Crear una segunda cuenta, marcarla predeterminada y borrar la anterior si no tiene movimientos.
8. Intentar borrar una cuenta usada como origen o destino de transferencia: debe rechazarse.
9. Intentar cambiar moneda de cuenta/tarjeta con actividad: debe rechazarse.
10. Exportar → importar → abrir en InPrivate y comparar.
