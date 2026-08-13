# Panorama Cloud 0.1.3 — Auth consolidado

- Corrige el flujo de recuperación: un enlace recovery obliga a definir una contraseña nueva antes de acceder a Panorama.
- Política de contraseña: mínimo 8 caracteres, mayúscula, minúscula, número y símbolo.
- Confirmación de contraseña y feedback visual de requisitos.
- Mostrar/ocultar contraseña.
- El nombre se solicita exclusivamente al crear usuario.
- La misma política se aplica en alta y recuperación.
- Los datos financieros continúan en almacenamiento local por UUID de usuario; migración Cloud pendiente.
