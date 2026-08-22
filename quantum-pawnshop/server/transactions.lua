PawnshopTransactions = PawnshopTransactions or {}

local function sendDiscordLog(entry)
    if not Config.Discord.enabled or Config.Discord.webhook == '' then return end

    local description = table.concat({
        ('**Type:** %s'):format(entry.transactionType or 'unknown'),
        ('**Employee:** %s (%s)'):format(entry.employeeName or 'N/A', entry.employeeCitizenId or 'N/A'),
        ('**Customer:** %s (%s)'):format(entry.customerName or 'N/A', entry.customerCitizenId or 'N/A'),
        ('**Item:** %sx %s'):format(entry.quantity or 0, entry.itemLabel or entry.itemName or 'N/A'),
        ('**Customer payout:** %s'):format(Pawnshop.FormatMoney(entry.customerPayout or 0)),
        ('**Appraiser payout:** %s'):format(Pawnshop.FormatMoney(entry.appraiserPayout or 0)),
        ('**Profit movement:** %s'):format(Pawnshop.FormatMoney(entry.profit or 0)),
        ('**Society:** %s → %s'):format(
            Pawnshop.FormatMoney(entry.societyBefore or 0),
            Pawnshop.FormatMoney(entry.societyAfter or 0)
        )
    }, '\n')

    PerformHttpRequest(Config.Discord.webhook, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatar,
        embeds = {{
            title = 'Pawnshop Transaction',
            description = description,
            color = 15844367,
            footer = { text = os.date('!%Y-%m-%d %H:%M:%S UTC') }
        }}
    }), { ['Content-Type'] = 'application/json' })
end

function PawnshopTransactions.Log(entry)
    entry = entry or {}

    local id = MySQL.insert.await([[
        INSERT INTO pawnshop_transactions (
            transaction_type,
            employee_citizenid,
            employee_name,
            customer_citizenid,
            customer_name,
            item_name,
            item_label,
            quantity,
            customer_payout,
            appraiser_payout,
            profit,
            society_balance_before,
            society_balance_after,
            metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        entry.transactionType or 'unknown',
        entry.employeeCitizenId,
        entry.employeeName,
        entry.customerCitizenId,
        entry.customerName,
        entry.itemName,
        entry.itemLabel,
        math.floor(tonumber(entry.quantity) or 0),
        math.floor(tonumber(entry.customerPayout) or 0),
        math.floor(tonumber(entry.appraiserPayout) or 0),
        math.floor(tonumber(entry.profit) or 0),
        math.floor(tonumber(entry.societyBefore) or 0),
        math.floor(tonumber(entry.societyAfter) or 0),
        entry.metadata and json.encode(entry.metadata) or nil
    })

    entry.id = id
    sendDiscordLog(entry)
    return id
end

function PawnshopTransactions.GetRecent(limit)
    limit = math.floor(tonumber(limit) or Config.Management.historyLimit)
    limit = math.max(1, math.min(limit, 100))

    return MySQL.query.await(([[
        SELECT id, transaction_type, employee_name, customer_name, item_name, item_label,
               quantity, customer_payout, appraiser_payout, profit,
               society_balance_before, society_balance_after, created_at
        FROM pawnshop_transactions
        ORDER BY id DESC
        LIMIT %d
    ]]):format(limit)) or {}
end

function PawnshopTransactions.GetStats()
    local row = MySQL.single.await([[
        SELECT
            COUNT(*) AS transaction_count,
            COALESCE(SUM(CASE WHEN transaction_type = 'employee_customer_purchase' THEN quantity ELSE 0 END), 0) AS items_purchased,
            COALESCE(SUM(CASE WHEN transaction_type IN ('employee_customer_purchase', 'offline_npc_sale') THEN customer_payout ELSE 0 END), 0) AS customer_payouts,
            COALESCE(SUM(CASE WHEN transaction_type = 'appraiser_sale' THEN appraiser_payout ELSE 0 END), 0) AS appraiser_revenue,
            COALESCE(SUM(CASE WHEN transaction_type IN ('employee_customer_purchase', 'appraiser_sale') THEN profit ELSE 0 END), 0) AS net_profit
        FROM pawnshop_transactions
    ]]) or {}

    row.balance = PawnshopSociety.GetBalance()
    return row
end
