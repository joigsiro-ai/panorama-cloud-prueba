# Panorama Cloud 0.3 — Motor financiero Cloud

Base validada: 0.2.1.1.

Migra a Supabase movimientos, recurrentes, planes de cuotas, estados mensuales y compras auxiliares de tarjeta. Supabase pasa a ser la fuente de verdad; localStorage queda como caché temporal. Cada fila conserva `payload` para mantener fidelidad total con el modelo actual durante la transición.
