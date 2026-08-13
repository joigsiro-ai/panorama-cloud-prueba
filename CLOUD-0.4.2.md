# Panorama Cloud 0.4.2 — Supabase Session Diagnostics

Base: 0.4.1.

- Valida la sesión contra Supabase Auth (`getUser`) antes de consultar tablas RLS.
- Si una sesión fresca necesita revalidación, intenta `refreshSession`.
- Las lecturas Cloud quedan identificadas por tabla: categories, accounts, credit_cards,
  app_preferences, movements, recurring_expenses, installment_plans, card_months y card_purchases.
- Los errores de arranque muestran build, etapa y detalle real de Supabase.
- Se mantiene Supabase como única persistencia; localStorage continúa en cero referencias.
