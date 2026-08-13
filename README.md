# Panorama Cloud 0.1

Base estable: Panorama Pre-Cloud 0.2.5.

Esta rama prepara la migración real a Supabase sin modificar todavía el motor financiero. Ver `CLOUD-0.1.md`, `.env.example` y `supabase-schema.sql`.

# Panorama Pre-Cloud 0.2.2

Base: Panorama Vision 2.2.0.18 — Insights + Flujo.

Esta edición introduce la capa multiusuario local previa a Panorama Cloud. Ver `PRE-CLOUD.md` y `supabase-schema.sql`.

# Panorama

**Versión:** Panorama Vision 2.2.0.18 — Insights + Flujo

Aplicación local de presupuesto personal con cuentas, tarjetas y movimientos en sus monedas reales.

## 2.2.0.17.1 — Precisión de interés

- El interés mensual de las tarjetas admite cuatro decimales, preservando tasas detectadas por conciliación al editar una tarjeta.
- Corregida la validación HTML que impedía guardar una tarjeta existente con tasas como 0,8907%.

## 2.2.0.17 — Ciclos de tarjeta

- Cada tarjeta puede definir **día de cierre** y, opcionalmente, **día de vencimiento**.
- Las compras con tarjeta calculan automáticamente el **estado en que se pagan** usando la fecha de compra y el día de cierre.
- Las compras en cuotas guardan **fecha de compra** y proponen automáticamente el **primer estado con cuota**; el mes puede corregirse manualmente si el banco presenta la compra en otro ciclo.
- Crear o editar un plan de cuotas sincroniza inmediatamente sus cuotas con la actividad de la tarjeta.
- Las cuotas incluidas en un estado estimado ahora impactan efectivamente en el **total del estado**, el pendiente y las proyecciones siguientes.
- Los estados ya conciliados continúan respetando el importe real confirmado para evitar duplicar consumos que ya forman parte del estado emitido.
- Los recurrentes con tarjeta conservan la lógica de facturación y aprovechan el ciclo cuando existe una fecha de compra conocida.

## Notas

Las tarjetas creadas antes de esta versión no tienen día de cierre guardado. Editalas una vez para indicar su cierre y habilitar el cálculo automático del estado.

Los datos permanecen en el navegador mediante `localStorage`. Se recomienda utilizar periódicamente la exportación JSON.


## 2.2.0.18 — Insights + Flujo

- `Visión General Test` pasa a llamarse **Insights**.
- `Visión General` pasa a llamarse **Flujo**.
- El orden de navegación queda **Tarjetas → Insights → Flujo → Configuración**.
- En Flujo, los importes reducen su peso tipográfico para no dominar visualmente la pantalla.
- Flujo incorpora navegación mensual con el patrón de Tarjetas/Presupuesto: anterior, mes visible y siguiente.
- Cada acción avanza o retrocede exactamente un mes y queda limitada al horizonte seleccionado de 6, 9 o 12 meses.
