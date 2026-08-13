# Arquitectura — Panorama Vision 2.2.0

## Principios

Panorama conserva cada importe en su moneda real. No convierte toda la información a una moneda base ni suma monedas incompatibles. El saldo de una cuenta se obtiene exclusivamente de sus movimientos; la cuenta no almacena un saldo inicial.

## Entidades

### Cuenta
- `id`
- `name`
- `bank`
- `currency`
- `isDefault`

### Tarjeta
- `id`
- `name`
- `bank`
- `currency`
- `interestRate`

### Movimiento
Los movimientos normales se vinculan a una cuenta mediante `accountId` y conservan `currency`.
Las compras con tarjeta usan `cardId` y la moneda de la tarjeta.

### Pago de tarjeta
- `operationType: card_payment`
- `accountId`: cuenta debitada
- `amount`: importe realmente debitado
- `currency`: moneda de la cuenta
- `cardId`: tarjeta pagada
- `appliedAmount`: importe aplicado al estado
- `appliedCurrency`: moneda de la tarjeta
- `effectiveRate`: dato derivado

### Transferencia
- `operationType: transfer`
- `accountId`: cuenta origen
- `amount`: importe debitado
- `destinationAccountId`: cuenta destino
- `destinationAmount`: importe acreditado
- `effectiveRate`: dato derivado

## Conciliación

La conciliación confirma el importe del estado y sus cargos. Los pagos son eventos posteriores e independientes, por lo que pueden registrarse varias veces y desde cuentas distintas.
