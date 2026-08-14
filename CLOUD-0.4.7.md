# Panorama Cloud 0.4.7 — Recurrentes por lote

- Nuevo botón **Agregar recurrentes al mes**.
- Al entrar al modo lote, todos los recurrentes quedan seleccionados inicialmente.
- Se pueden desmarcar los que no se quieran agregar.
- El importe puede modificarse para el mes antes de confirmar; el importe base del recurrente no cambia.
- Se muestra cantidad seleccionada y total por moneda.
- Se conservan las reglas existentes para recurrentes de tarjeta y el botón individual **Agregar al mes**.
- Si un recurrente ya fue agregado al mes, se informa visualmente; en modo lote sigue siendo seleccionable para no cambiar la conducta histórica que permite repetirlo.
- No requiere cambios SQL ni modifica el esquema de Supabase.
