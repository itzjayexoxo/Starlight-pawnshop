Pawnshop = Pawnshop or {}

function Pawnshop.Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function Pawnshop.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Pawnshop.FormatMoney(value)
    local amount = math.floor(tonumber(value) or 0)
    local formatted = tostring(math.abs(amount))
    local changed

    repeat
        formatted, changed = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until changed == 0

    if amount < 0 then formatted = '-' .. formatted end
    return ('%s%s'):format(Config.CurrencySymbol, formatted)
end

function Pawnshop.GetCondition(itemConfig, metadata)
    if not Config.ConditionPricing.enabled then return 100 end

    metadata = type(metadata) == 'table' and metadata or {}
    local key = itemConfig.conditionMetadata
    local condition = key and tonumber(metadata[key]) or Config.ConditionPricing.defaultCondition

    return Pawnshop.Clamp(condition or Config.ConditionPricing.defaultCondition, 0, 100)
end

function Pawnshop.GetUnitPrice(itemName, priceType, metadata)
    local itemConfig = Config.SellableItems[itemName]
    if not itemConfig then return nil end

    local basePrice = tonumber(itemConfig[priceType])
    if not basePrice or basePrice < 0 then return nil end

    local condition = Pawnshop.GetCondition(itemConfig, metadata)
    local minimum = Config.ConditionPricing.minimumMultiplier
    local maximum = Config.ConditionPricing.maximumMultiplier
    local multiplier = minimum + ((condition / 100) * (maximum - minimum))

    return Pawnshop.Round(basePrice * multiplier), condition
end

function Pawnshop.IsPositiveInteger(value, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < 1 then return false end
    if maximum and value > maximum then return false end
    return true
end
