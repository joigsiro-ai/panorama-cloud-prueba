# Panorama Cloud 0.3.1 — Insights + UX Fix

Base: Panorama Cloud 0.3 — Motor financiero Cloud.

Cambios:
- Corrige el checkbox sobredimensionado de las filas agrupadas por categoría.
- Insights incorpora meses futuros con compromisos aunque todavía no tengan ingresos registrados.
- Esos meses se presentan como información parcial y no como saldo negativo confirmado.
- Los pagos de tarjeta se consideran salida real de caja en Insights cuando no existe una obligación/estado de tarjeta ya reconocido para ese mes, evitando inflar el saldo esperado.
- "Próximo mes crítico" ya no etiqueta como crítico a un mes saludable solo por ser el peor de los disponibles.
- Comparaciones de saldo esperado se realizan solamente entre meses que tienen ingresos registrados.
