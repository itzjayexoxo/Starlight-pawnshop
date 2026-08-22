PawnshopSociety = PawnshopSociety or {}

local accountName = Config.JobName
local accountBusy = false

local function acquireAccount()
    while accountBusy do Wait(0) end
    accountBusy = true
end

local function releaseAccount()
    accountBusy = false
end

local function runLocked(callback)
    acquireAccount()
    local results = table.pack(xpcall(callback, debug.traceback))
    releaseAccount()

    if not results[1] then error(results[2]) end
    return table.unpack(results, 2, results.n)
end

local function ensureAccount()
    MySQL.insert.await([[
        INSERT INTO pawnshop_society_accounts (account_name, balance)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE account_name = VALUES(account_name)
    ]], { accountName, math.max(0, math.floor(Config.StartingSocietyBalance)) })
end

local function readBalance()
    ensureAccount()
    return tonumber(MySQL.scalar.await(
        'SELECT balance FROM pawnshop_society_accounts WHERE account_name = ? LIMIT 1',
        { accountName }
    )) or 0
end

function PawnshopSociety.GetBalance()
    return readBalance()
end

function PawnshopSociety.Credit(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then
        local balance = readBalance()
        return false, balance, balance
    end

    return runLocked(function()
        local before = readBalance()
        local changed = MySQL.update.await(
            'UPDATE pawnshop_society_accounts SET balance = balance + ? WHERE account_name = ?',
            { amount, accountName }
        )
        local after = changed == 1 and (before + amount) or before

        if changed ~= 1 then return false, before, before end
        return true, before, after
    end)
end

function PawnshopSociety.Debit(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then
        local balance = readBalance()
        return false, balance, balance
    end

    return runLocked(function()
        local before = readBalance()
        local changed = MySQL.update.await([[
            UPDATE pawnshop_society_accounts
            SET balance = balance - ?
            WHERE account_name = ? AND balance >= ?
        ]], { amount, accountName, amount })
        local after = changed == 1 and (before - amount) or before

        if changed ~= 1 then return false, before, before end
        return true, before, after
    end)
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(250) end
    ensureAccount()
end)
