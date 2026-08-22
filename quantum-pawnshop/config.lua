Config = {}

Config.Debug = false
Config.JobName = 'pawnshop'
Config.CurrencySymbol = '£'
Config.CustomerPaymentAccount = 'cash' -- cash, bank or crypto
Config.ManagementDepositAccount = 'bank'
Config.ManagementWithdrawAccount = 'bank'
Config.StartingSocietyBalance = 25000
Config.OfferExpirySeconds = 45
Config.TransactionCooldownMs = 1250
Config.MaximumTransactionQuantity = 100
Config.ServerDistanceTolerance = 4.0
Config.NearbyCustomerDistance = 3.0

-- These coordinates are examples. Replace them with the exact positions in your pawnshop MLO.
Config.Locations = {
    PublicBuyer = vector4(412.14, 314.83, 103.13, 206.0),
    Appraiser = vector4(414.05, 311.78, 103.13, 25.0),
    Clock = vector3(410.95, 309.75, 103.13),
    IntakeStash = vector3(413.66, 307.55, 103.13),
    Management = vector3(409.98, 307.53, 103.13)
}

Config.Peds = {
    PublicBuyer = {
        model = 'a_m_m_business_01',
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        label = 'Sell Items Cheaply',
        icon = 'fa-solid fa-hand-holding-dollar'
    },
    Appraiser = {
        model = 's_m_m_highsec_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        label = 'Appraise Intake Items',
        icon = 'fa-solid fa-magnifying-glass-dollar'
    }
}

Config.Target = {
    distance = 2.0,
    zoneDistance = 2.0,
    drawSprite = false
}

Config.Progress = {
    OfflineSale = 2500,
    CustomerPurchase = 3000,
    Appraisal = 4000
}

Config.Stash = {
    id = 'quantum_pawnshop_intake',
    label = 'Pawnshop Intake',
    slots = 80,
    weight = 250000,
    minimumGrade = 0
}

Config.Management = {
    minimumGrade = 2,
    historyLimit = 50,
    allowWithdrawals = true
}

Config.Blip = {
    enabled = true,
    coords = vector3(412.14, 314.83, 103.13),
    sprite = 431,
    colour = 5,
    scale = 0.75,
    label = 'Pawnshop',
    shortRange = true
}

-- Price values are PER ITEM. The employee enters the total offer for the selected quantity.
-- conditionMetadata supports a numeric metadata value from 0-100, e.g. durability or condition.
Config.SellableItems = {
    rolex = {
        label = 'Rolex',
        offlinePrice = 650,
        appraiserPrice = 1500,
        minimumEmployeeOffer = 500,
        maximumEmployeeOffer = 1200,
        conditionMetadata = 'durability'
    },
    goldchain = {
        label = 'Gold Chain',
        offlinePrice = 300,
        appraiserPrice = 750,
        minimumEmployeeOffer = 200,
        maximumEmployeeOffer = 600
    },
    diamond_ring = {
        label = 'Diamond Ring',
        offlinePrice = 900,
        appraiserPrice = 2200,
        minimumEmployeeOffer = 700,
        maximumEmployeeOffer = 1800,
        conditionMetadata = 'condition'
    },
    laptop = {
        label = 'Laptop',
        offlinePrice = 175,
        appraiserPrice = 450,
        minimumEmployeeOffer = 125,
        maximumEmployeeOffer = 350,
        conditionMetadata = 'durability'
    },
    phone = {
        label = 'Mobile Phone',
        offlinePrice = 90,
        appraiserPrice = 250,
        minimumEmployeeOffer = 60,
        maximumEmployeeOffer = 190,
        conditionMetadata = 'durability'
    }
}

Config.ConditionPricing = {
    enabled = true,
    minimumMultiplier = 0.25,
    maximumMultiplier = 1.0,
    defaultCondition = 100
}

Config.Discord = {
    enabled = false,
    webhook = '',
    username = 'Quantum Pawnshop',
    avatar = ''
}
