PawnshopClient = PawnshopClient or {
    staffed = false,
    dutyCount = 0,
    publicBuyer = nil,
    appraiser = nil,
    zones = {},
    blip = nil
}

function PawnshopClient.IsEmployee(requireDuty)
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.JobName then return false end
    if requireDuty and not job.onduty then return false end
    return true
end

function PawnshopClient.IsManager()
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not job or job.name ~= Config.JobName or not job.onduty then return false end
    return job.isboss == true or ((job.grade and job.grade.level or 0) >= Config.Management.minimumGrade)
end

function PawnshopClient.Notify(message, notifyType)
    lib.notify({
        title = 'Pawnshop',
        description = message,
        type = notifyType or 'inform'
    })
end

local function addBlip()
    if not Config.Blip.enabled or PawnshopClient.blip then return end

    local blip = AddBlipForCoord(Config.Blip.coords.x, Config.Blip.coords.y, Config.Blip.coords.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.Blip.colour)
    SetBlipAsShortRange(blip, Config.Blip.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
    PawnshopClient.blip = blip
end

local function registerZones()
    PawnshopClient.zones.clock = exports.ox_target:addBoxZone({
        name = 'quantum_pawnshop_clock',
        coords = Config.Locations.Clock,
        size = vector3(1.0, 1.0, 1.5),
        rotation = 0.0,
        debug = Config.Debug,
        drawSprite = Config.Target.drawSprite,
        options = {{
            name = 'quantum_pawnshop_toggle_duty',
            icon = 'fa-solid fa-user-clock',
            label = 'Clock In / Out',
            distance = Config.Target.zoneDistance,
            canInteract = function()
                return PawnshopClient.IsEmployee(false)
            end,
            onSelect = function()
                local success, message, onDuty = lib.callback.await('quantum-pawnshop:server:toggleDuty', false)
                PawnshopClient.Notify(message, success and 'success' or 'error')
                if success and QBX and QBX.PlayerData and QBX.PlayerData.job then
                    QBX.PlayerData.job.onduty = onDuty
                end
            end
        }}
    })

    PawnshopClient.zones.intake = exports.ox_target:addBoxZone({
        name = 'quantum_pawnshop_intake',
        coords = Config.Locations.IntakeStash,
        size = vector3(1.2, 1.0, 1.5),
        rotation = 0.0,
        debug = Config.Debug,
        drawSprite = Config.Target.drawSprite,
        options = {{
            name = 'quantum_pawnshop_open_intake',
            icon = 'fa-solid fa-box-open',
            label = 'Open Pawnshop Intake',
            distance = Config.Target.zoneDistance,
            canInteract = function()
                return PawnshopClient.IsEmployee(true)
            end,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', Config.Stash.id)
            end
        }}
    })

    PawnshopClient.zones.management = exports.ox_target:addBoxZone({
        name = 'quantum_pawnshop_management',
        coords = Config.Locations.Management,
        size = vector3(1.0, 1.0, 1.5),
        rotation = 0.0,
        debug = Config.Debug,
        drawSprite = Config.Target.drawSprite,
        options = {{
            name = 'quantum_pawnshop_open_management',
            icon = 'fa-solid fa-chart-line',
            label = 'Pawnshop Management',
            distance = Config.Target.zoneDistance,
            canInteract = function()
                return PawnshopClient.IsManager()
            end,
            onSelect = function()
                PawnshopClient.OpenManagement()
            end
        }}
    })

    exports.ox_target:addGlobalPlayer({{
        name = 'quantum_pawnshop_offer_customer',
        icon = 'fa-solid fa-file-signature',
        label = 'Create Pawnshop Offer',
        distance = Config.NearbyCustomerDistance,
        canInteract = function(entity)
            return PawnshopClient.IsEmployee(true) and entity ~= cache.ped
        end,
        onSelect = function(data)
            local playerIndex = NetworkGetPlayerIndexFromPed(data.entity)
            if playerIndex == -1 then
                return PawnshopClient.Notify('Unable to identify that customer.', 'error')
            end

            PawnshopClient.OpenCustomerItems(GetPlayerServerId(playerIndex))
        end
    }})
end

local function refreshState()
    local state = lib.callback.await('quantum-pawnshop:server:getState', false)
    if not state then return end

    PawnshopClient.staffed = state.staffed
    PawnshopClient.dutyCount = state.dutyCount or 0
    PawnshopClient.RefreshPeds()
end

RegisterNetEvent('quantum-pawnshop:client:setStaffing', function(staffed, count)
    PawnshopClient.staffed = staffed == true
    PawnshopClient.dutyCount = tonumber(count) or 0
    PawnshopClient.RefreshPeds()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function()
    SetTimeout(100, refreshState)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    SetTimeout(100, refreshState)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(500, refreshState)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    PawnshopClient.staffed = false
    PawnshopClient.RefreshPeds()
end)

CreateThread(function()
    while not QBX or not QBX.PlayerData do Wait(100) end
    addBlip()
    registerZones()
    refreshState()
    TriggerServerEvent('quantum-pawnshop:server:requestStaffing')
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    exports.ox_target:removeGlobalPlayer('quantum_pawnshop_offer_customer')
    for _, zone in pairs(PawnshopClient.zones) do
        exports.ox_target:removeZone(zone)
    end

    PawnshopClient.DeletePeds()
    if PawnshopClient.blip then RemoveBlip(PawnshopClient.blip) end
end)
