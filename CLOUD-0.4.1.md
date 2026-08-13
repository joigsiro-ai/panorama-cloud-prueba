# Panorama Cloud 0.4.1 — Import + Insights Fix

Base: Panorama Cloud 0.4.

- Corrige un error de Insights al deduplicar meses cuando alguno de los candidatos era `undefined`.
- Separa la transacción de importación en Supabase del refresco visual posterior.
- Un error de render ya no informa falsamente que falló una restauración que PostgreSQL confirmó.
- Actualiza la versión visible en Configuración a Cloud 0.4.1 · Supabase Only.
- Mantiene Supabase como única fuente persistente; no reintroduce localStorage.
