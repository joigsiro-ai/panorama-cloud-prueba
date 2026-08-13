# Panorama Pre-Cloud 0.2.4 — Contexto de tarjeta consistente

- Corrige el cambio entre tarjetas: título, importes, consumos, cuotas activas, administración de cuotas y proyecciones se renderizan desde el mismo `cardId` explícito.
- El detalle de Tarjetas deja de depender de valores DOM/globales de la tarjeta anterior durante un cambio de selección.
- Refuerzo de render tras `Ver` para que toda la pantalla quede sincronizada con la tarjeta seleccionada.

# Changelog

## Panorama Pre-Cloud 0.2.2 — Sincronización de cuotas
- Evita dobles altas desde “Guardar movimiento” deshabilitando el botón durante el guardado de una compra en cuotas.
- Conserva el modo de compra antes de resetear el formulario y navega a la tarjeta/mes correctos tras guardar.
- Unifica la generación de cuotas usando `syncInstallmentPlanMovements`, evitando lógicas duplicadas.
- Al cambiar de tarjeta se ejecuta un render completo para reconstruir consumos, cuotas activas, administración, pendientes y proyecciones.
- Los planes nuevos conservan también la categoría elegida al regenerar sus movimientos.


## Panorama Pre-Cloud 0.2.1 — Migración conservadora de cuotas

- Se elimina la corrección automática de planes históricos ambiguos cuando el total de compra coincide con el importe por cuota.
- Panorama ya no reinterpreta ni regenera silenciosamente esos planes.
- Solo se completa `totalPurchaseAmount` en planes antiguos donde ese dato no existía y el esquema histórico permite derivarlo de `amount × count`.


## Panorama Pre-Cloud 0.2 — Cuotas coherentes
- Unifica el alta de compras en cuotas desde “Agregar movimiento” con el modelo de planes de tarjeta.
- Permite ingresar total de compra o importe por cuota y calcula automáticamente el otro valor.
- Conserva la tarjeta seleccionada al refrescar el formulario y abre la tarjeta/estado correctos tras registrar cuotas.
- Normaliza planes antiguos inconsistentes donde total y cuota habían quedado iguales y regenera sus movimientos.
- “Administrar compras en cuotas” ofrece las mismas dos modalidades de importe.
## 2.2.0.16.1 — Dark Mode Tarjetas

- Corrige los tres resúmenes del estado de tarjeta en modo oscuro (Pendiente, Pagado y Total del estado), manteniendo su semántica azul/verde/ámbar con contraste adecuado.
- Uniforma la altura interna de las tarjetas del selector horizontal para que nombres de dos líneas, como “SANTANDER Pesos”, no desalineen importes ni botones.
- Limita visualmente el nombre de tarjeta a dos líneas y mantiene las acciones alineadas al pie.

# Panorama Vision 2.2.0.14 — Inicio multimoneda coherente

- Inicio ahora calcula Ingresos, Pagado y Pendiente con el mismo criterio multimoneda de Presupuesto.
- Los pagos de tarjeta ya no se duplican al calcular Pagado.
- Los importes aplicados en USD permanecen en USD y no se suman numéricamente a UYU.
- Disponible real hoy refleja el flujo efectivo por moneda de las cuentas.
- El porcentaje comprometido y el mensaje de estado se calculan sobre la moneda de la cuenta predeterminada.

# Panorama Vision 2.2.0.13 — Gestión de consumos de tarjeta

- Agrega menú de acciones `···` en los consumos de tarjeta del estado.
- Permite editar y eliminar compras normales y débitos automáticos.
- Los pagos de tarjeta y las cuotas generadas por planes no muestran estas acciones, para preservar su lógica específica.
- El menú reutiliza el posicionamiento flotante seguro de los movimientos: `position: fixed`, cálculo dinámico y apertura hacia arriba cuando no hay espacio, evitando recortes por contenedores con `overflow`.
- Al editar un recurrente ya materializado en tarjeta se preservan `origin` y `sourceRecurringId`, evitando perder el vínculo con la definición recurrente.

## 2.2.0.16 — Tarjetas e Insights
- Tarjetas definidas pasan a un selector horizontal superior, junto al navegador temporal, evitando desplazamientos largos para cambiar de tarjeta.
- El selector de tarjetas admite desplazamiento horizontal en pantallas angostas.
- Panorama Insights analiza únicamente meses que tengan al menos un ingreso registrado.
- Meses sin ingresos quedan fuera de Horizonte, comparaciones, mejor/peor mes y simulador, y se informa el límite real de la proyección disponible.
