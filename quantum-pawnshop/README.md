# quantum-pawnshop

A Qbox pawnshop job using `ox_target`, `ox_inventory`, `ox_lib`, `oxmysql`, and a built-in society ledger.

## Main behaviour

- When **zero pawnshop employees are on duty**, a public NPC appears and buys configured items for reduced prices.
- When the **first employee clocks in**, the public NPC is removed for every player.
- When the **last employee clocks out**, the public NPC returns.
- Employees target customers, inspect only configured sellable items, and create a server-validated purchase offer.
- Accepted items move directly into the shared pawnshop intake stash.
- Customer payment is removed from the pawnshop society balance and paid directly to the customer.
- A permanent back-room appraiser buys intake items at the higher configured price and deposits the proceeds into the society balance.
- Managers can review performance, transaction history, deposits, and withdrawals.

## Dependencies

Start these before `quantum-pawnshop`:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure ox_target
ensure ox_inventory
ensure quantum-pawnshop
```

## Installation

1. Import `sql/pawnshop.sql` into your database.
2. Add the pawnshop job to `qbx_core/shared/jobs.lua` or your server's Qbox jobs file.
3. Confirm every item in `Config.SellableItems` exists in `ox_inventory/data/items.lua`.
4. Replace all example coordinates in `config.lua` with your MLO coordinates.
5. Add `ensure quantum-pawnshop` after its dependencies.
6. Restart the server.

## Qbox job example

Add this inside the jobs table used by your Qbox installation:

```lua
pawnshop = {
    label = 'Pawnshop',
    type = 'business',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        [0] = {
            name = 'Trainee',
            payment = 50,
        },
        [1] = {
            name = 'Employee',
            payment = 75,
        },
        [2] = {
            name = 'Manager',
            payment = 100,
            bankAuth = true,
        },
        [3] = {
            name = 'Owner',
            payment = 125,
            isboss = true,
            bankAuth = true,
        },
    },
},
```

Qbox grades must use numeric keys.

## Pricing

All values in `Config.SellableItems` are per item:

```lua
rolex = {
    label = 'Rolex',
    offlinePrice = 650,
    appraiserPrice = 1500,
    minimumEmployeeOffer = 500,
    maximumEmployeeOffer = 1200,
    conditionMetadata = 'durability'
}
```

The employee enters a **total** offer. For 2 Rolex watches, the accepted range would be £1,000–£2,400.

When condition pricing is enabled, metadata such as `durability = 50` reduces the final NPC/appraiser price using the configured multiplier range.

## Society account

This release uses its own `pawnshop_society_accounts` database table. This avoids assumptions about which banking resource the server uses and keeps customer purchases/appraiser reimbursements atomic.

The initial balance is controlled by:

```lua
Config.StartingSocietyBalance = 25000
```

This value is only used when the society account is first created. Changing it later will not overwrite an existing balance.

## Security

The server validates:

- Job and duty status
- Manager grade
- Player and NPC distance
- Item name, slot, metadata, and quantity
- Employee offer limits
- Society affordability
- Intake capacity
- Offer expiry
- Duplicate processing
- Transaction cooldowns

The intake stash also uses an `ox_inventory` `openInventory` hook so off-duty employees cannot bypass the target interaction.

## Configuration notes

- `Config.CustomerPaymentAccount`: account used to pay customers (`cash`, `bank`, or `crypto`).
- `Config.ManagementDepositAccount`: personal account managers deposit from.
- `Config.ManagementWithdrawAccount`: personal account managers receive withdrawals into.
- `Config.Management.minimumGrade`: minimum numeric Qbox grade for management access.
- `Config.Discord`: optional transaction webhook logging.
- `Config.Debug`: enables target-zone debug rendering.
