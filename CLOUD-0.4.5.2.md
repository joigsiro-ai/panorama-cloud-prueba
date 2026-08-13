# Panorama Cloud 0.4.5.2 — Tour Stacking Fix

- Corrige la causa real del solapamiento del tour: el elemento resaltado ya no puede crear
  un contexto de apilado por encima del overlay.
- El overlay del tour queda por encima de toda la aplicación.
- El último paso señala la pestaña Configuración en vez de elevar la tarjeta completa de Cotizaciones.
- No cambia Supabase, cotizaciones, lógica financiera ni onboarding persistente.
- No requiere SQL nuevo.
