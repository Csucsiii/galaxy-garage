---@diagnostic disable: undefined-global, lowercase-global
local garageZones = {}
local peds = {}

RegisterCommand("garage", function()
    Callback.TriggerServerCallback("galaxy-garage:fetchUserVehicles", function (vehicles)
        print(json.encode(vehicles))
    end, 1)
end)

function createPed(model, coords, garageId)
    local modelHash = GetHashKey(model)

    while (not HasModelLoaded(modelHash)) do
        RequestModel(modelHash)
        Wait(100)
    end

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetCanAttackFriendly(ped, true, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetModelAsNoLongerNeeded(modelHash)
    FreezeEntityPosition(ped, true)

    peds[ped] = true


    exports["gl-target"]:AddTargetEntity(ped, {
        options = {
            {
                type = "client",
                event = "galaxy-garage:openGarage",
                label = "Garázs megnyitása",
                garageId = garageId
            }
        }
    })

    return ped
end

function removePed(ped)
    if (not DoesEntityExist(ped)) then return end

    exports["gl-target"]:RemoveTargetEntity(ped, { "Garázs megnyitása" })
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)

    peds[ped] = nil

    print("removed")
end

CreateThread(function()
    for _, v in pairs(config.locations) do
        garageZones[string.format("garage_%s", v.id)] = {
            zoneId = v.id,
            zone = PolyZone:Create(v.zone, {
                name = string.format("garage_%s", v.id),
                minZ = v.minZ,
                maxZ = v.maxZ,
                debugGrid = true,
                gridDivision = 30
            }),
            isIn = false,
            ped = v.ped,
            entity = nil
        }
    end

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped, false)

        for _, v in pairs(garageZones) do
            local isIn = false

            if (v.zone:isPointInside(coords)) then
                isIn = true
            end

            if (isIn) then
                if (not v.isIn) then
                    print("Inside")
                    v.entity = createPed(v.ped.model, v.ped.coords, v.zoneId)
                end
            else
                if (v.isIn) then
                    print("Outside")
                    removePed(v.entity)
                end
            end

            v.isIn = isIn
        end

        Wait(3000)
    end
end)

RegisterNetEvent("galaxy-garage:openGarage")
AddEventHandler("galaxy-garage:openGarage", function(data)
    print("garageId:", data.garageId)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    for _, v in pairs(garageZones) do
        v.zone:destroy()
    end

    for _, v in pairs(peds) do
        if (DoesEntityExist(v)) then
            SetEntityAsMissionEntity(v, true, true)
            DeleteEntity(v)
        end
    end
end)