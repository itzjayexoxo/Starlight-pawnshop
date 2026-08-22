local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        print(('[quantum-pawnshop] Invalid ped model: %s'):format(model))
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(50)
        if GetGameTimer() > timeout then return nil end
    end

    return hash
end

local function createPed(pedConfig, coords)
    local model = loadModel(pedConfig.model)
    if not model then return nil end

    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanRagdoll(ped, false)

    if pedConfig.scenario and pedConfig.scenario ~= '' then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    return ped
end

local function spawnPublicBuyer()
    if PawnshopClient.publicBuyer and DoesEntityExist(PawnshopClient.publicBuyer) then return end

    local ped = createPed(Config.Peds.PublicBuyer, Config.Locations.PublicBuyer)
    if not ped then return end

    PawnshopClient.publicBuyer = ped
    exports.ox_target:addLocalEntity(ped, {{
        name = 'quantum_pawnshop_public_buyer',
        icon = Config.Peds.PublicBuyer.icon,
        label = Config.Peds.PublicBuyer.label,
        distance = Config.Target.distance,
        onSelect = function()
            PawnshopClient.OpenOfflineMenu()
        end
    }})
end

local function deletePublicBuyer()
    local ped = PawnshopClient.publicBuyer
    if not ped or not DoesEntityExist(ped) then
        PawnshopClient.publicBuyer = nil
        return
    end

    exports.ox_target:removeLocalEntity(ped, 'quantum_pawnshop_public_buyer')
    DeleteEntity(ped)
    PawnshopClient.publicBuyer = nil
end

local function spawnAppraiser()
    if PawnshopClient.appraiser and DoesEntityExist(PawnshopClient.appraiser) then return end

    local ped = createPed(Config.Peds.Appraiser, Config.Locations.Appraiser)
    if not ped then return end

    PawnshopClient.appraiser = ped
    exports.ox_target:addLocalEntity(ped, {{
        name = 'quantum_pawnshop_appraiser',
        icon = Config.Peds.Appraiser.icon,
        label = Config.Peds.Appraiser.label,
        distance = Config.Target.distance,
        canInteract = function()
            return PawnshopClient.IsEmployee(true)
        end,
        onSelect = function()
            PawnshopClient.OpenAppraiserMenu()
        end
    }})
end

function PawnshopClient.RefreshPeds()
    spawnAppraiser()

    if PawnshopClient.staffed then
        deletePublicBuyer()
    else
        spawnPublicBuyer()
    end
end

function PawnshopClient.DeletePeds()
    deletePublicBuyer()

    local ped = PawnshopClient.appraiser
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped, 'quantum_pawnshop_appraiser')
        DeleteEntity(ped)
    end
    PawnshopClient.appraiser = nil
end
