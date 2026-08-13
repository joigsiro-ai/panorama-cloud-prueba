# Auditoría de consumo Supabase — Panorama Cloud 0.4.4

## Resultado
- Polling (`setInterval`): 0
- Canales Realtime: 0
- Suscripciones `postgres_changes`: 0
- `localStorage`: 0
- Carga completa: 1 RPC `panorama_load_snapshot`
- La sesión se valida durante el flujo de autenticación; `loadAllFromSupabase()` ya no repite `getSession/getUser`.
- Aplicar el tema al arrancar ya no escribe preferencias.
- Guardar preferencias ya no hace SELECT previo: mantiene el JSON de preferencias cargado en memoria y hace un único UPSERT.

## Cambio principal
Antes, una carga completa hacía SELECT separados de:
categories, accounts, credit_cards, app_preferences, movements,
recurring_expenses, installment_plans, card_months y card_purchases.

Ahora esas nueve lecturas se resuelven dentro de PostgreSQL y vuelven al navegador
en una única respuesta JSON mediante `panorama_load_snapshot()`.

Las operaciones atómicas conservan la recarga posterior por seguridad, pero esa
recarga pasa de 9 lecturas Data API a 1 RPC Data API.

## Seguridad
`panorama_load_snapshot()` usa `security invoker`, `auth.uid()` y las políticas RLS
existentes. Solo se concede EXECUTE al rol `authenticated`.

## Llamadas presentes en el código
Tablas con CRUD directo: app_preferences, card_months
RPC: panorama_delete_account, panorama_delete_card, panorama_delete_category, panorama_delete_installment_plan, panorama_delete_recurring, panorama_export_backup, panorama_load_snapshot, panorama_reconcile_card, panorama_reset_data, panorama_restore_backup, panorama_save_account, panorama_save_card, panorama_save_installment_bundle, panorama_update_category
Auth: getSession, getUser, onAuthStateChange, refreshSession, resetPasswordForEmail, signInWithPassword, signOut, signUp, updateUser
