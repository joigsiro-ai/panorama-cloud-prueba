# Panorama Cloud 0.4.8.1 — Topbar refinada · Fix de inicialización

Corrección local sobre la iteración de topbar refinada.

- Corrige el orden de inicialización del selector de período.
- `$`, `now` y `currentMonth` quedan definidos antes de ser usados por los controles del shell.
- Evita que el JavaScript se interrumpa antes de cargar el snapshot de Supabase y registrar el resto de eventos.
- No modifica lógica financiera ni contratos RPC.
