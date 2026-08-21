# Panorama Cloud 0.4.8.2.3 — Identidad de cabecera y meses de Presupuesto

- Mueve `Hola Nacho` y la fecha desde la topbar hacia la sidebar, inmediatamente antes de la navegación.
- Libera la cabecera superior para que la marca Panorama, su icono y su frase tengan mayor presencia y mejor respiración visual.
- Mantiene los controles de período, avatar y tema en el extremo derecho de la topbar.
- Corrige la barra horizontal de meses de Presupuesto: `renderBudgetMonthNavigator()` vuelve a ejecutarse en cada `render()`, por lo que los siete meses deben mostrarse y actualizarse con el período seleccionado.
- No modifica reglas financieras, operaciones Supabase ni APIs.
