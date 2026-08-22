local activeOfferToken

local function itemImage(itemName)
    return ('nui://ox_inventory/web/images/%s.png'):format(itemName)
end

local function runProgress(label, duration, animation)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = animation
    })
end

local function showResult(success, message)
    PawnshopClient.Notify(message or (success and 'Completed.' or 'Failed.'), success and 'success' or 'error')
end

function PawnshopClient.OpenOfflineMenu()
    local success, payload = lib.callback.await('quantum-pawnshop:server:getOfflineItems', false)
    if not success then return PawnshopClient.Notify(payload, 'error') end
    if #payload == 0 then return PawnshopClient.Notify('You have nothing this buyer wants.', 'error') end

    local options = {}
    for i = 1, #payload do
        local item = payload[i]
        options[#options + 1] = {
            title = ('%s ×%s'):format(item.label, item.count),
            description = ('%s each | Condition: %s%%'):format(Pawnshop.FormatMoney(item.unitPrice), item.condition),
            image = itemImage(item.name),
            onSelect = function()
                local input = lib.inputDialog(('Sell %s'):format(item.label), {{
                    type = 'number',
                    label = 'Quantity',
                    description = ('You own %s. Total at maximum: %s'):format(item.count, Pawnshop.FormatMoney(item.unitPrice * item.count)),
                    required = true,
                    min = 1,
                    max = math.min(item.count, Config.MaximumTransactionQuantity),
                    default = 1
                }})
                if not input then return end

                local quantity = math.floor(tonumber(input[1]) or 0)
                local confirm = lib.alertDialog({
                    header = 'Confirm Pawnshop Sale',
                    content = ('Sell **%sx %s** for **%s**?\n\nThis is the reduced out-of-hours price.'):format(
                        quantity,
                        item.label,
                        Pawnshop.FormatMoney(item.unitPrice * quantity)
                    ),
                    centered = true,
                    cancel = true,
                    labels = { confirm = 'Sell', cancel = 'Cancel' }
                })
                if confirm ~= 'confirm' then return end

                if not runProgress('Handing over items...', Config.Progress.OfflineSale, {
                    dict = 'mp_common',
                    clip = 'givetake1_a'
                }) then return end

                local sold, message = lib.callback.await('quantum-pawnshop:server:sellOffline', false, item.slot, quantity)
                showResult(sold, message)
            end
        }
    end

    lib.registerContext({
        id = 'quantum_pawnshop_offline_menu',
        title = 'Out-of-Hours Pawn Buyer',
        options = options
    })
    lib.showContext('quantum_pawnshop_offline_menu')
end

function PawnshopClient.OpenCustomerItems(customerSource)
    local success, payload = lib.callback.await('quantum-pawnshop:server:getCustomerItems', false, customerSource)
    if not success then return PawnshopClient.Notify(payload, 'error') end
    if #payload == 0 then return PawnshopClient.Notify('This customer has no eligible pawn items.', 'error') end

    local options = {}
    for i = 1, #payload do
        local item = payload[i]
        options[#options + 1] = {
            title = ('%s ×%s'):format(item.label, item.count),
            description = ('Offer range per item: %s–%s | Condition: %s%%'):format(
                Pawnshop.FormatMoney(item.minimumOffer),
                Pawnshop.FormatMoney(item.maximumOffer),
                item.condition
            ),
            image = itemImage(item.name),
            onSelect = function()
                local input = lib.inputDialog(('Offer for %s'):format(item.label), {
                    {
                        type = 'number',
                        label = 'Quantity',
                        required = true,
                        min = 1,
                        max = math.min(item.count, Config.MaximumTransactionQuantity),
                        default = 1
                    },
                    {
                        type = 'number',
                        label = 'Total customer payment',
                        description = 'Enter the total offer, not the price per item.',
                        required = true,
                        min = item.minimumOffer,
                        max = item.maximumOffer * math.min(item.count, Config.MaximumTransactionQuantity)
                    }
                })
                if not input then return end

                local quantity = math.floor(tonumber(input[1]) or 0)
                local totalOffer = math.floor(tonumber(input[2]) or 0)
                local minimum = item.minimumOffer * quantity
                local maximum = item.maximumOffer * quantity

                if totalOffer < minimum or totalOffer > maximum then
                    return PawnshopClient.Notify(('Offer must be between %s and %s for that quantity.'):format(
                        Pawnshop.FormatMoney(minimum),
                        Pawnshop.FormatMoney(maximum)
                    ), 'error')
                end

                local sent, message = lib.callback.await(
                    'quantum-pawnshop:server:createOffer',
                    false,
                    customerSource,
                    item.slot,
                    quantity,
                    totalOffer
                )
                showResult(sent, message)
            end
        }
    end

    lib.registerContext({
        id = 'quantum_pawnshop_customer_items',
        title = 'Create Customer Offer',
        options = options
    })
    lib.showContext('quantum_pawnshop_customer_items')
end

RegisterNetEvent('quantum-pawnshop:client:receiveOffer', function(offer)
    if activeOfferToken then
        lib.callback.await('quantum-pawnshop:server:resolveOffer', false, activeOfferToken, false)
    end

    activeOfferToken = offer.token
    local result = lib.alertDialog({
        header = 'Pawnshop Purchase Offer',
        content = ('**Employee:** %s\n\n**Item:** %sx %s\n\n**You receive:** %s\n\nThe item will be transferred to the pawnshop intake when accepted.'):format(
            offer.employeeName,
            offer.quantity,
            offer.itemLabel,
            Pawnshop.FormatMoney(offer.totalOffer)
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Accept Offer', cancel = 'Decline' }
    })

    if activeOfferToken ~= offer.token then return end
    local accepted = result == 'confirm'

    if accepted then
        accepted = runProgress('Completing pawnshop sale...', Config.Progress.CustomerPurchase, {
            dict = 'mp_common',
            clip = 'givetake1_a'
        }) == true
    end

    local success, message = lib.callback.await('quantum-pawnshop:server:resolveOffer', false, offer.token, accepted)
    activeOfferToken = nil
    showResult(success, message)
end)

RegisterNetEvent('quantum-pawnshop:client:offerCancelled', function(token)
    if activeOfferToken == token then
        activeOfferToken = nil
        PawnshopClient.Notify('The pawnshop offer expired or was cancelled.', 'error')
    end
end)

function PawnshopClient.OpenAppraiserMenu()
    local success, payload = lib.callback.await('quantum-pawnshop:server:getAppraiserItems', false)
    if not success then return PawnshopClient.Notify(payload, 'error') end
    if #payload == 0 then return PawnshopClient.Notify('The intake stash has no eligible items.', 'error') end

    local options = {}
    for i = 1, #payload do
        local item = payload[i]
        options[#options + 1] = {
            title = ('%s ×%s'):format(item.label, item.count),
            description = ('Appraised at %s each | Condition: %s%%'):format(Pawnshop.FormatMoney(item.unitPrice), item.condition),
            image = itemImage(item.name),
            onSelect = function()
                local input = lib.inputDialog(('Appraise %s'):format(item.label), {{
                    type = 'number',
                    label = 'Quantity',
                    required = true,
                    min = 1,
                    max = math.min(item.count, Config.MaximumTransactionQuantity),
                    default = 1
                }})
                if not input then return end

                local quantity = math.floor(tonumber(input[1]) or 0)
                local confirm = lib.alertDialog({
                    header = 'Confirm Appraiser Sale',
                    content = ('Sell **%sx %s** to the appraiser for **%s**?\n\nThe payment goes directly into the pawnshop society account.'):format(
                        quantity,
                        item.label,
                        Pawnshop.FormatMoney(item.unitPrice * quantity)
                    ),
                    centered = true,
                    cancel = true,
                    labels = { confirm = 'Appraise & Sell', cancel = 'Cancel' }
                })
                if confirm ~= 'confirm' then return end

                if not runProgress('Appraising item...', Config.Progress.Appraisal, {
                    dict = 'amb@world_human_clipboard@male@idle_a',
                    clip = 'idle_c'
                }) then return end

                local sold, message = lib.callback.await('quantum-pawnshop:server:sellToAppraiser', false, item.slot, quantity)
                showResult(sold, message)
            end
        }
    end

    lib.registerContext({
        id = 'quantum_pawnshop_appraiser_menu',
        title = 'Back-Room Appraiser',
        options = options
    })
    lib.showContext('quantum_pawnshop_appraiser_menu')
end

local function transactionDescription(row)
    local parts = {
        ('Type: %s'):format((row.transaction_type or 'unknown'):gsub('_', ' ')),
        ('Quantity: %s'):format(row.quantity or 0),
        ('Customer payout: %s'):format(Pawnshop.FormatMoney(row.customer_payout or 0)),
        ('Appraiser revenue: %s'):format(Pawnshop.FormatMoney(row.appraiser_payout or 0)),
        ('Profit movement: %s'):format(Pawnshop.FormatMoney(row.profit or 0)),
        ('Society: %s → %s'):format(Pawnshop.FormatMoney(row.society_balance_before or 0), Pawnshop.FormatMoney(row.society_balance_after or 0)),
        ('Date: %s'):format(row.created_at or 'Unknown')
    }
    return table.concat(parts, '\n')
end

function PawnshopClient.OpenManagement()
    local success, stats, history = lib.callback.await('quantum-pawnshop:server:getManagement', false)
    if not success then return PawnshopClient.Notify(stats, 'error') end

    local options = {
        {
            title = ('Society Balance: %s'):format(Pawnshop.FormatMoney(stats.balance or 0)),
            description = ('On-duty staff: %s | Transactions: %s'):format(stats.dutyCount or 0, stats.transaction_count or 0),
            icon = 'fa-solid fa-building-columns',
            readOnly = true
        },
        {
            title = 'Business Performance',
            description = ('Items purchased: %s\nCustomer payouts: %s\nAppraiser revenue: %s\nNet profit: %s'):format(
                stats.items_purchased or 0,
                Pawnshop.FormatMoney(stats.customer_payouts or 0),
                Pawnshop.FormatMoney(stats.appraiser_revenue or 0),
                Pawnshop.FormatMoney(stats.net_profit or 0)
            ),
            icon = 'fa-solid fa-chart-column',
            readOnly = true
        },
        {
            title = 'Deposit Society Funds',
            icon = 'fa-solid fa-money-bill-transfer',
            onSelect = function()
                local input = lib.inputDialog('Deposit Society Funds', {{
                    type = 'number',
                    label = 'Amount',
                    required = true,
                    min = 1
                }})
                if not input then return end
                local deposited, message = lib.callback.await('quantum-pawnshop:server:managementDeposit', false, math.floor(tonumber(input[1]) or 0))
                showResult(deposited, message)
            end
        }
    }

    if Config.Management.allowWithdrawals then
        options[#options + 1] = {
            title = 'Withdraw Society Funds',
            icon = 'fa-solid fa-money-check-dollar',
            onSelect = function()
                local input = lib.inputDialog('Withdraw Society Funds', {{
                    type = 'number',
                    label = 'Amount',
                    required = true,
                    min = 1,
                    max = math.max(1, math.floor(tonumber(stats.balance) or 1))
                }})
                if not input then return end
                local withdrawn, message = lib.callback.await('quantum-pawnshop:server:managementWithdraw', false, math.floor(tonumber(input[1]) or 0))
                showResult(withdrawn, message)
            end
        }
    end

    local historyOptions = {}
    for i = 1, #history do
        local row = history[i]
        historyOptions[#historyOptions + 1] = {
            title = ('#%s %s'):format(row.id, row.item_label or row.item_name or row.transaction_type),
            description = transactionDescription(row),
            icon = 'fa-solid fa-receipt',
            readOnly = true
        }
    end

    if #historyOptions == 0 then
        historyOptions[1] = { title = 'No transactions recorded', readOnly = true }
    end

    lib.registerContext({
        id = 'quantum_pawnshop_history',
        title = 'Pawnshop Transaction History',
        menu = 'quantum_pawnshop_management',
        options = historyOptions
    })

    options[#options + 1] = {
        title = 'Transaction History',
        description = ('View the latest %s records.'):format(#history),
        icon = 'fa-solid fa-clock-rotate-left',
        menu = 'quantum_pawnshop_history'
    }

    lib.registerContext({
        id = 'quantum_pawnshop_management',
        title = 'Pawnshop Management',
        options = options
    })
    lib.showContext('quantum_pawnshop_management')
end
