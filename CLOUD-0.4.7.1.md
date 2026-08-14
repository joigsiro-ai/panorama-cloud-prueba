# Panorama Cloud 0.4.7.1 — Recurrentes por lote UX Fix

- El botón principal pasa a llamarse **Aplicar recurrentes al mes**.
- Antes de presionarlo, la pantalla muestra únicamente la lista normal de recurrentes.
- Seleccionar todos, Quitar selección, checkboxes, importes editables, resumen, Cancelar y Aplicar al mes
  aparecen únicamente dentro del modo lote.
- Al entrar al modo lote todos los recurrentes quedan seleccionados por defecto.
- Se corrige el fallo visual de 0.4.7 donde el modo lote podía abrirse sin mostrar checkboxes ni importes.
- No requiere SQL nuevo ni cambios en Supabase.
