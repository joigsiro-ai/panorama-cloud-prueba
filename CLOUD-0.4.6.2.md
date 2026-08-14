# Panorama Cloud 0.4.6.2 — Account Flow Fix

- El filtro por cuenta ahora muestra el asiento real que pertenece a esa cuenta.
  - cuenta origen: salida de la transferencia;
  - cuenta destino: entrada de la transferencia.
- Al expandir una agrupación por cuenta, las tres columnas monetarias de cada movimiento
  representan Ingresó / Salió / Neto, igual que la cabecera del grupo.
- Un ingreso ya no aparece visualmente como si también hubiera salido.
- En el resumen por cuenta, “Salió” utiliza el importe efectivamente debitado (`paidAmount`);
  los gastos pendientes no se cuentan como dinero ya salido.
- No modifica Supabase ni requiere SQL nuevo.
