local pendingOffers = {}
local sourceCooldowns = {}
local transactionLocks = {}
local inventoryHookId

math.randomseed(os.time())

local function notify(source, message, notifyType)
    exports.qbx_core:Notify(source, message, notifyType or 'inform')
end

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getFullName(player)
    if not player or not player.PlayerData then return 'Unknown' end
    local charinfo = player.PlayerData.charinfo or {}
    local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or GetPlayerName(player.PlayerData.source or 0) or 'Unknown'
end

local function isEmployee(source, requireDuty)
    local player = getPlayer(source)
    if not player then return false, nil end

    local job = player.PlayerData.job
    if not job or job.name ~= Config.JobName then return false, player end
    if requireDuty and not job.onduty then return false, player end

    return true, player
end

local function isManager(source)
    local employee, player = isEmployee(source, true)
    if not employee then return false, player end

    local level = player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
    return player.PlayerData.job.isboss == true or level >= Config.Management.minimumGrade, player
end

local function isNear(source, coords, tolerance)
    local ped = GetPlayerPed(source)
    if ped <= 0 then return false end

    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= (tolerance or Config.ServerDistanceTolerance)
end

local function arePlayersNear(first, second, tolerance)
    local firstPed = GetPlayerPed(first)
    local secondPed = GetPlayerPed(second)
    if firstPed <= 0 or secondPed <= 0 then return false end

    return #(GetEntityCoords(firstPed) - GetEntityCoords(secondPed)) <= (tolerance or Config.NearbyCustomerDistance)
end

local function onCooldown(source, key)
    local now = GetGameTimer()
    sourceCooldowns[source] = sourceCooldowns[source] or {}
    local expires = sourceCooldowns[source][key] or 0

    if expires > now then return true end
    sourceCooldowns[source][key] = now + Config.TransactionCooldownMs
    return false
end

local function withLock(key, callback)
    if transactionLocks[key] then return false, 'This transaction is already being processed.' end
    transactionLocks[key] = true

    local ok, first, second, third = xpcall(callback, debug.traceback)
    transactionLocks[key] = nil

    if not ok then
        print(('[quantum-pawnshop] Transaction error (%s): %s'):format(key, first))
        return false, 'The transaction could not be completed.'
    end

    return first, second, third
end

local function dutyCount()
    local count = exports.qbx_core:GetDutyCountJob(Config.JobName)
    return tonumber(count) or 0
end

local function syncStaffingState(target)
    local count = dutyCount()
    GlobalState.quantumPawnshopStaffed = count > 0
    TriggerClientEvent('quantum-pawnshop:client:setStaffing', target or -1, count > 0, count)
end

local function itemSlot(inventoryId, slotId)
    local items = exports.ox_inventory:GetInventoryItems(inventoryId) or {}
    return items[tonumber(slotId)]
end

local function listEligibleItems(inventoryId, priceType)
    local items = exports.ox_inventory:GetInventoryItems(inventoryId) or {}
    local result = {}

    for slotId, slot in pairs(items) do
        local itemConfig = slot and Config.SellableItems[slot.name]
        if itemConfig and (slot.count or 0) > 0 then
            local price, condition = Pawnshop.GetUnitPrice(slot.name, priceType, slot.metadata)
            if price and price > 0 then
                result[#result + 1] = {
                    slot = tonumber(slot.slot or slotId),
                    name = slot.name,
                    label = itemConfig.label or slot.label or slot.name,
                    count = slot.count,
                    metadata = slot.metadata or {},
                    unitPrice = price,
                    condition = condition
                }
            end
        end
    end

    table.sort(result, function(a, b)
        if a.label == b.label then return a.slot < b.slot end
        return a.label < b.label
    end)

    return result
end

local function cleanupEmployeeOffers(employeeSource)
    for token, offer in pairs(pendingOffers) do
        if offer.employeeSource == employeeSource or offer.customerSource == employeeSource then
            pendingOffers[token] = nil
            if offer.customerSource and GetPlayerName(offer.customerSource) then
                TriggerClientEvent('quantum-pawnshop:client:offerCancelled', offer.customerSource, token)
            end
        end
    end
end

local function createToken()
    local token
    repeat
        token = ('%08x%08x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
    until not pendingOffers[token]
    return token
end

local function registerStashAndHook()
    exports.ox_inventory:RegisterStash(
        Config.Stash.id,
        Config.Stash.label,
        Config.Stash.slots,
        Config.Stash.weight,
        nil,
        { [Config.JobName] = Config.Stash.minimumGrade },
        Config.Locations.IntakeStash
    )

    if inventoryHookId then exports.ox_inventory:removeHooks(inventoryHookId) end
    inventoryHookId = exports.ox_inventory:registerHook('openInventory', function(payload)
        if payload.inventoryId ~= Config.Stash.id then return end

        local allowed = isEmployee(payload.source, true)
        if not allowed or not isNear(payload.source, Config.Locations.IntakeStash, Config.ServerDistanceTolerance) then
            notify(payload.source, 'You must be an on-duty pawnshop employee to open this intake.', 'error')
            return false
        end
    end, {
        inventoryFilter = { ('^%s$'):format(Config.Stash.id:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')) }
    })
end

lib.callback.register('quantum-pawnshop:server:getState', function(source)
    local player = getPlayer(source)
    local job = player and player.PlayerData.job or nil

    return {
        staffed = dutyCount() > 0,
        dutyCount = dutyCount(),
        employee = job and job.name == Config.JobName or false,
        onDuty = job and job.name == Config.JobName and job.onduty or false,
        manager = job and job.name == Config.JobName and (
            job.isboss == true or ((job.grade and job.grade.level or 0) >= Config.Management.minimumGrade)
        ) or false
    }
end)

lib.callback.register('quantum-pawnshop:server:toggleDuty', function(source)
    if onCooldown(source, 'duty') then return false, 'Please wait before changing duty again.' end

    local employee, player = isEmployee(source, false)
    if not employee then return false, 'You do not work at this pawnshop.' end
    if not isNear(source, Config.Locations.Clock) then return false, 'You are too far away from the clock-in point.' end

    local newState = not player.PlayerData.job.onduty
    local success = exports.qbx_core:SetJobDuty(source, newState)
    if success == false then return false, 'Duty status could not be changed.' end

    if not newState then cleanupEmployeeOffers(source) end
    SetTimeout(100, function() syncStaffingState() end)

    return true, newState and 'You are now on duty.' or 'You are now off duty.', newState
end)

lib.callback.register('quantum-pawnshop:server:getOfflineItems', function(source)
    if dutyCount() > 0 then return false, 'Pawnshop staff are available. Speak to an employee.' end
    if not isNear(source, vector3(Config.Locations.PublicBuyer.x, Config.Locations.PublicBuyer.y, Config.Locations.PublicBuyer.z)) then
        return false, 'You are too far away from the buyer.'
    end

    return true, listEligibleItems(source, 'offlinePrice')
end)

lib.callback.register('quantum-pawnshop:server:sellOffline', function(source, slotId, quantity)
    if onCooldown(source, 'offline_sale') then return false, 'Please wait before selling again.' end
    if dutyCount() > 0 then return false, 'Pawnshop staff are now available. Speak to an employee.' end
    if not isNear(source, vector3(Config.Locations.PublicBuyer.x, Config.Locations.PublicBuyer.y, Config.Locations.PublicBuyer.z)) then
        return false, 'You are too far away from the buyer.'
    end
    if not Pawnshop.IsPositiveInteger(quantity, Config.MaximumTransactionQuantity) then
        return false, 'Invalid quantity.'
    end

    return withLock(('offline:%s'):format(source), function()
        local player = getPlayer(source)
        local slot = itemSlot(source, slotId)
        local itemConfig = slot and Config.SellableItems[slot.name]
        if not player or not slot or not itemConfig or slot.count < quantity then
            return false, 'You no longer have enough of that item.'
        end

        local unitPrice = Pawnshop.GetUnitPrice(slot.name, 'offlinePrice', slot.metadata)
        if not unitPrice then return false, 'That item cannot be sold here.' end
        local total = unitPrice * quantity

        local removed = exports.ox_inventory:RemoveItem(source, slot.name, quantity, slot.metadata, slot.slot, false, true)
        if not removed then return false, 'The item could not be removed from your inventory.' end

        local paid = exports.qbx_core:AddMoney(source, Config.CustomerPaymentAccount, total, 'pawnshop-offline-sale')
        if not paid then
            exports.ox_inventory:AddItem(source, slot.name, quantity, slot.metadata)
            return false, 'Payment failed and your item was returned.'
        end

        local balance = PawnshopSociety.GetBalance()
        PawnshopTransactions.Log({
            transactionType = 'offline_npc_sale',
            customerCitizenId = player.PlayerData.citizenid,
            customerName = getFullName(player),
            itemName = slot.name,
            itemLabel = itemConfig.label or slot.label,
            quantity = quantity,
            customerPayout = total,
            profit = 0,
            societyBefore = balance,
            societyAfter = balance,
            metadata = slot.metadata
        })

        return true, ('Sold %sx %s for %s.'):format(quantity, itemConfig.label or slot.label, Pawnshop.FormatMoney(total)), total
    end)
end)

lib.callback.register('quantum-pawnshop:server:getCustomerItems', function(source, customerSource)
    local employee = isEmployee(source, true)
    customerSource = tonumber(customerSource)

    if not employee then return false, 'You must be on duty.' end
    if not customerSource or customerSource == source or not getPlayer(customerSource) then
        return false, 'Invalid customer.'
    end
    if not arePlayersNear(source, customerSource) then return false, 'The customer is too far away.' end

    local items = listEligibleItems(customerSource, 'appraiserPrice')
    for i = 1, #items do
        local config = Config.SellableItems[items[i].name]
        items[i].minimumOffer = math.floor(config.minimumEmployeeOffer or 0)
        items[i].maximumOffer = math.floor(config.maximumEmployeeOffer or items[i].unitPrice)
        items[i].unitPrice = nil
    end

    return true, items
end)

lib.callback.register('quantum-pawnshop:server:createOffer', function(source, customerSource, slotId, quantity, totalOffer)
    if onCooldown(source, 'create_offer') then return false, 'Please wait before creating another offer.' end

    local employee, employeePlayer = isEmployee(source, true)
    customerSource = tonumber(customerSource)
    totalOffer = tonumber(totalOffer)

    if not employee then return false, 'You must be on duty.' end
    if not customerSource or customerSource == source then return false, 'Invalid customer.' end
    local customerPlayer = getPlayer(customerSource)
    if not customerPlayer then return false, 'The customer is no longer online.' end
    if not arePlayersNear(source, customerSource) then return false, 'The customer is too far away.' end
    if not Pawnshop.IsPositiveInteger(quantity, Config.MaximumTransactionQuantity) then return false, 'Invalid quantity.' end
    if not Pawnshop.IsPositiveInteger(totalOffer, 100000000) then return false, 'Invalid offer amount.' end

    local slot = itemSlot(customerSource, slotId)
    local itemConfig = slot and Config.SellableItems[slot.name]
    if not slot or not itemConfig or slot.count < quantity then return false, 'The customer no longer has enough of that item.' end

    local minimum = math.floor(itemConfig.minimumEmployeeOffer or 0) * quantity
    local maximum = math.floor(itemConfig.maximumEmployeeOffer or 0) * quantity
    if totalOffer < minimum or totalOffer > maximum then
        return false, ('The total offer must be between %s and %s.'):format(Pawnshop.FormatMoney(minimum), Pawnshop.FormatMoney(maximum))
    end

    if PawnshopSociety.GetBalance() < totalOffer then return false, 'The pawnshop society cannot afford this offer.' end

    local token = createToken()
    pendingOffers[token] = {
        token = token,
        employeeSource = source,
        employeeCitizenId = employeePlayer.PlayerData.citizenid,
        employeeName = getFullName(employeePlayer),
        customerSource = customerSource,
        customerCitizenId = customerPlayer.PlayerData.citizenid,
        customerName = getFullName(customerPlayer),
        slot = tonumber(slot.slot or slotId),
        itemName = slot.name,
        itemLabel = itemConfig.label or slot.label,
        metadata = slot.metadata or {},
        quantity = quantity,
        totalOffer = math.floor(totalOffer),
        expiresAt = os.time() + Config.OfferExpirySeconds,
        processing = false
    }

    TriggerClientEvent('quantum-pawnshop:client:receiveOffer', customerSource, {
        token = token,
        employeeName = pendingOffers[token].employeeName,
        itemLabel = pendingOffers[token].itemLabel,
        quantity = quantity,
        totalOffer = math.floor(totalOffer),
        expiresAt = pendingOffers[token].expiresAt
    })

    return true, ('Offer sent to %s.'):format(pendingOffers[token].customerName)
end)

lib.callback.register('quantum-pawnshop:server:resolveOffer', function(source, token, accepted)
    local offer = pendingOffers[tostring(token)]
    if not offer or offer.customerSource ~= source then return false, 'This offer is no longer available.' end

    if not accepted then
        pendingOffers[token] = nil
        if GetPlayerName(offer.employeeSource) then
            notify(offer.employeeSource, ('%s declined the pawnshop offer.'):format(offer.customerName), 'error')
        end
        return true, 'Offer declined.'
    end

    return withLock(('offer:%s'):format(token), function()
        offer = pendingOffers[token]
        if not offer then return false, 'This offer is no longer available.' end
        if offer.processing then return false, 'This offer is already being processed.' end
        offer.processing = true

        if os.time() > offer.expiresAt then
            pendingOffers[token] = nil
            return false, 'This offer has expired.'
        end

        local employee, employeePlayer = isEmployee(offer.employeeSource, true)
        local customerPlayer = getPlayer(source)
        if not employee or not customerPlayer then
            pendingOffers[token] = nil
            return false, 'The employee or customer is no longer available.'
        end
        if not arePlayersNear(offer.employeeSource, source) then
            offer.processing = false
            return false, 'You are too far away from the employee.'
        end

        local slot = itemSlot(source, offer.slot)
        if not slot or slot.name ~= offer.itemName or slot.count < offer.quantity then
            pendingOffers[token] = nil
            return false, 'You no longer have the offered item.'
        end

        local removed = exports.ox_inventory:RemoveItem(source, offer.itemName, offer.quantity, offer.metadata, offer.slot, false, true)
        if not removed then
            offer.processing = false
            return false, 'The item could not be removed.'
        end

        local debited, societyBefore, societyAfter = PawnshopSociety.Debit(offer.totalOffer)
        if not debited then
            exports.ox_inventory:AddItem(source, offer.itemName, offer.quantity, offer.metadata)
            pendingOffers[token] = nil
            return false, 'The pawnshop society can no longer afford the offer.'
        end

        if not exports.ox_inventory:CanCarryItem(Config.Stash.id, offer.itemName, offer.quantity, offer.metadata) then
            PawnshopSociety.Credit(offer.totalOffer)
            exports.ox_inventory:AddItem(source, offer.itemName, offer.quantity, offer.metadata)
            pendingOffers[token] = nil
            return false, 'The pawnshop intake is full.'
        end

        local added = exports.ox_inventory:AddItem(Config.Stash.id, offer.itemName, offer.quantity, offer.metadata)
        if not added then
            PawnshopSociety.Credit(offer.totalOffer)
            exports.ox_inventory:AddItem(source, offer.itemName, offer.quantity, offer.metadata)
            pendingOffers[token] = nil
            return false, 'The pawnshop intake rejected the item.'
        end

        local paid = exports.qbx_core:AddMoney(source, Config.CustomerPaymentAccount, offer.totalOffer, 'pawnshop-customer-sale')
        if not paid then
            exports.ox_inventory:RemoveItem(Config.Stash.id, offer.itemName, offer.quantity, offer.metadata, nil, false, true)
            PawnshopSociety.Credit(offer.totalOffer)
            exports.ox_inventory:AddItem(source, offer.itemName, offer.quantity, offer.metadata)
            pendingOffers[token] = nil
            return false, 'Payment failed and the transaction was reversed.'
        end

        PawnshopTransactions.Log({
            transactionType = 'employee_customer_purchase',
            employeeCitizenId = employeePlayer.PlayerData.citizenid,
            employeeName = getFullName(employeePlayer),
            customerCitizenId = customerPlayer.PlayerData.citizenid,
            customerName = getFullName(customerPlayer),
            itemName = offer.itemName,
            itemLabel = offer.itemLabel,
            quantity = offer.quantity,
            customerPayout = offer.totalOffer,
            profit = -offer.totalOffer,
            societyBefore = societyBefore,
            societyAfter = societyAfter,
            metadata = offer.metadata
        })

        pendingOffers[token] = nil
        notify(offer.employeeSource, ('Purchase completed for %s. Item moved to intake.'):format(Pawnshop.FormatMoney(offer.totalOffer)), 'success')
        return true, ('You sold %sx %s for %s.'):format(offer.quantity, offer.itemLabel, Pawnshop.FormatMoney(offer.totalOffer))
    end)
end)

lib.callback.register('quantum-pawnshop:server:getAppraiserItems', function(source)
    local employee = isEmployee(source, true)
    if not employee then return false, 'You must be on duty.' end
    if not isNear(source, vector3(Config.Locations.Appraiser.x, Config.Locations.Appraiser.y, Config.Locations.Appraiser.z)) then
        return false, 'You are too far away from the appraiser.'
    end

    return true, listEligibleItems(Config.Stash.id, 'appraiserPrice')
end)

lib.callback.register('quantum-pawnshop:server:sellToAppraiser', function(source, slotId, quantity)
    if onCooldown(source, 'appraiser_sale') then return false, 'Please wait before appraising another item.' end

    local employee, player = isEmployee(source, true)
    if not employee then return false, 'You must be on duty.' end
    if not isNear(source, vector3(Config.Locations.Appraiser.x, Config.Locations.Appraiser.y, Config.Locations.Appraiser.z)) then
        return false, 'You are too far away from the appraiser.'
    end
    if not Pawnshop.IsPositiveInteger(quantity, Config.MaximumTransactionQuantity) then return false, 'Invalid quantity.' end

    return withLock(('appraiser:%s:%s'):format(source, slotId), function()
        local slot = itemSlot(Config.Stash.id, slotId)
        local itemConfig = slot and Config.SellableItems[slot.name]
        if not slot or not itemConfig or slot.count < quantity then return false, 'The intake item is no longer available.' end

        local unitPrice = Pawnshop.GetUnitPrice(slot.name, 'appraiserPrice', slot.metadata)
        if not unitPrice then return false, 'The appraiser will not buy this item.' end
        local total = unitPrice * quantity

        local removed = exports.ox_inventory:RemoveItem(Config.Stash.id, slot.name, quantity, slot.metadata, slot.slot, false, true)
        if not removed then return false, 'The item could not be removed from intake.' end

        local credited, societyBefore, societyAfter = PawnshopSociety.Credit(total)
        if not credited then
            exports.ox_inventory:AddItem(Config.Stash.id, slot.name, quantity, slot.metadata)
            return false, 'The society account could not receive the payment.'
        end

        PawnshopTransactions.Log({
            transactionType = 'appraiser_sale',
            employeeCitizenId = player.PlayerData.citizenid,
            employeeName = getFullName(player),
            itemName = slot.name,
            itemLabel = itemConfig.label or slot.label,
            quantity = quantity,
            appraiserPayout = total,
            profit = total,
            societyBefore = societyBefore,
            societyAfter = societyAfter,
            metadata = slot.metadata
        })

        return true, ('The appraiser paid %s into the society account.'):format(Pawnshop.FormatMoney(total)), total
    end)
end)

lib.callback.register('quantum-pawnshop:server:getManagement', function(source)
    local manager = isManager(source)
    if not manager then return false, 'You do not have management access.' end
    if not isNear(source, Config.Locations.Management) then return false, 'You are too far away from management.' end

    local stats = PawnshopTransactions.GetStats()
    stats.dutyCount = dutyCount()
    return true, stats, PawnshopTransactions.GetRecent(Config.Management.historyLimit)
end)

lib.callback.register('quantum-pawnshop:server:managementDeposit', function(source, amount)
    if onCooldown(source, 'management_deposit') then return false, 'Please wait.' end
    local manager, player = isManager(source)
    if not manager then return false, 'You do not have management access.' end
    if not isNear(source, Config.Locations.Management) then return false, 'You are too far away from management.' end
    if not Pawnshop.IsPositiveInteger(amount, 100000000) then return false, 'Invalid amount.' end

    return withLock(('management:%s'):format(source), function()
        local removed = exports.qbx_core:RemoveMoney(source, Config.ManagementDepositAccount, amount, 'pawnshop-society-deposit')
        if not removed then return false, 'You do not have enough money.' end

        local credited, before, after = PawnshopSociety.Credit(amount)
        if not credited then
            exports.qbx_core:AddMoney(source, Config.ManagementDepositAccount, amount, 'pawnshop-deposit-refund')
            return false, 'The deposit failed and your money was returned.'
        end

        PawnshopTransactions.Log({
            transactionType = 'society_deposit',
            employeeCitizenId = player.PlayerData.citizenid,
            employeeName = getFullName(player),
            customerPayout = 0,
            appraiserPayout = amount,
            profit = 0,
            societyBefore = before,
            societyAfter = after
        })

        return true, ('Deposited %s.'):format(Pawnshop.FormatMoney(amount))
    end)
end)

lib.callback.register('quantum-pawnshop:server:managementWithdraw', function(source, amount)
    if not Config.Management.allowWithdrawals then return false, 'Society withdrawals are disabled.' end
    if onCooldown(source, 'management_withdraw') then return false, 'Please wait.' end
    local manager, player = isManager(source)
    if not manager then return false, 'You do not have management access.' end
    if not isNear(source, Config.Locations.Management) then return false, 'You are too far away from management.' end
    if not Pawnshop.IsPositiveInteger(amount, 100000000) then return false, 'Invalid amount.' end

    return withLock(('management:%s'):format(source), function()
        local debited, before, after = PawnshopSociety.Debit(amount)
        if not debited then return false, 'The society account does not have enough money.' end

        local paid = exports.qbx_core:AddMoney(source, Config.ManagementWithdrawAccount, amount, 'pawnshop-society-withdrawal')
        if not paid then
            PawnshopSociety.Credit(amount)
            return false, 'The withdrawal failed and the society balance was restored.'
        end

        PawnshopTransactions.Log({
            transactionType = 'society_withdrawal',
            employeeCitizenId = player.PlayerData.citizenid,
            employeeName = getFullName(player),
            customerPayout = amount,
            appraiserPayout = 0,
            profit = 0,
            societyBefore = before,
            societyAfter = after
        })

        return true, ('Withdrew %s.'):format(Pawnshop.FormatMoney(amount))
    end)
end)

RegisterNetEvent('quantum-pawnshop:server:requestStaffing', function()
    syncStaffingState(source)
end)

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    if not onDuty then cleanupEmployeeOffers(source) end
    SetTimeout(100, function() syncStaffingState() end)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    if not job or job.name ~= Config.JobName or not job.onduty then cleanupEmployeeOffers(source) end
    SetTimeout(100, function() syncStaffingState() end)
end)

AddEventHandler('playerDropped', function()
    local source = source
    cleanupEmployeeOffers(source)
    sourceCooldowns[source] = nil
    SetTimeout(100, function() syncStaffingState() end)
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() and resource ~= 'ox_inventory' then return end
    SetTimeout(500, function()
        registerStashAndHook()
        syncStaffingState()
    end)
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for token, offer in pairs(pendingOffers) do
            if now > offer.expiresAt then
                pendingOffers[token] = nil
                if GetPlayerName(offer.customerSource) then
                    TriggerClientEvent('quantum-pawnshop:client:offerCancelled', offer.customerSource, token)
                end
                if GetPlayerName(offer.employeeSource) then
                    notify(offer.employeeSource, 'A pawnshop offer expired.', 'error')
                end
            end
        end
    end
end)
