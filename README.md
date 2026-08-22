# 💎 Quantum Pawnshop — Free FiveM Pawnshop Job

A fully-featured **FiveM Pawnshop Job** built for **Qbox/QBX**, designed around a realistic player-to-pawnshop buying system with employee-controlled pricing, an offline public buyer, and a dedicated back-room appraiser.

**100% FREE to use and release.**

## ✨ Features

### 🏪 Dynamic Pawnshop System

The pawnshop changes depending on whether employees are available.

**When NO pawnshop employees are on duty:**

* A public NPC automatically appears.
* Players can sell supported items directly to the NPC.
* Items are purchased at a reduced price.
* The NPC provides a simple way for players to make money even when the business is closed.

**When an employee clocks in:**

* The public low-price NPC automatically disappears.
* Players are encouraged to deal directly with the pawnshop employee.
* The system synchronizes the duty state for everyone on the server.

### 👩‍💼 Employee Customer Purchases

Pawnshop employees can purchase items directly from players.

Employees can:

* Target nearby customers.
* Select items from the customer's inventory.
* Choose quantities.
* Set an offer price.
* Send the offer to the customer.
* Allow the customer to accept or decline.

The server validates the transaction before anything is transferred.

### 💰 Pawnshop Profit System

The resource includes a complete pawnshop business loop.

For example:

> Customer sells an item for **£700**
> Pawnshop appraiser value: **£1,000**
> Pawnshop profit: **£300**

The customer's agreed payment comes from the pawnshop society account.

The purchased item can then be taken to the **back-room appraiser**, where the pawnshop receives the configured resale value.

### 🔍 Back-Room Appraiser

A dedicated appraiser NPC is always available in the back of the pawnshop.

Employees can:

* Take purchased items to the intake stash.
* Appraise items.
* See their resale value.
* Sell items to the appraiser.
* Return the proceeds to the pawnshop society account.

This creates a proper **buy low → appraise → resell → generate profit** gameplay loop.

### 📦 Pawnshop Intake Stash

Includes a secure employee-only intake stash using `ox_inventory`.

Features:

* Configurable slots.
* Configurable weight.
* Employee access only.
* Items can be moved into the stash after purchasing from customers.
* Items can then be sold through the appraiser.

### 📊 Management System

Authorized managers can view:

* Society balance
* Employees currently on duty
* Customer purchases
* Appraiser revenue
* Total pawnshop profit
* Recent transactions
* Employee transaction history
* Most profitable items

Managers can also manage the pawnshop society funds depending on their configured permissions.

### 🛡️ Server-Side Security

The resource is designed with server-side validation in mind.

Protection includes:

* Item ownership validation
* Quantity validation
* Price validation
* Job and grade validation
* Duty validation
* Distance checks
* Transaction locks
* Duplicate transaction protection
* Society balance validation
* Offer expiration
* Protection against client-side price manipulation

Client-side values are **not blindly trusted**.

### 💎 Configurable Items

Everything is configurable.

You can configure:

* Item names
* Item labels
* Offline NPC prices
* Appraiser prices
* Minimum employee offers
* Maximum employee offers
* Condition multipliers
* Random pricing
* NPC locations
* Job name
* Job grades
* Stash settings
* Society settings
* Blips
* Notifications
* Animations
* Progress bars

Example:

```lua
rolex = {
    label = 'Rolex',
    appraiserPrice = 1500,
    offlinePrice = 700,
    minimumEmployeeOffer = 500,
    maximumEmployeeOffer = 1200
}
```

## 🧰 Dependencies

* Qbox / QBX Core
* ox_lib
* ox_target
* ox_inventory
* oxmysql

## 📁 Included

```text
quantum-pawnshop/
├── fxmanifest.lua
├── config.lua
├── shared/
├── client/
├── server/
├── locales/
├── sql/
└── README.md
```

## 💖 Why I Made It

I wanted to create a pawnshop system that felt more like an actual **player-run business** rather than simply walking up to an NPC and selling items.

The dynamic NPC system means players can always sell their items, while having pawnshop employees online creates a reason to visit and interact with the actual business.

---

### 🆓 FREE RELEASE

This resource is being released **completely free** for the FiveM community.

If you use it on your server, feel free to credit **Quantum Developments**.

Please do not re-upload, resell, or claim the resource as your own.

Enjoy! 💎✨
