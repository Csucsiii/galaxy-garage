---@diagnostic disable: undefined-global, lowercase-global
local garageZones = {}
local peds = {}
local currentVehicles = {}

function closeUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        status = false
    })
end

function openUI(vehicles, faction)
    SetNuiFocus(true, true)
    SendNUIMessage({
        status = true,
        vehicles = vehicles,
        faction = faction
    })
end

function spawnVehicle(plate, properties, zone)
    local garageId = currentVehicles[plate].garageId
    local modelHash = GetHashKey(currentVehicles[plate].model)
    local parkingZone = zone and zone or config.locations[garageId].parkingZones

    for _, v in pairs(parkingZone) do
        if (IsSpawnPointClear({ x = v.x, y = v.y, z = v.z }, 2.5)) then
            TriggerServerEvent("galaxy-garage:spawnVehicle", modelHash, v, properties)
            return
        end
    end
end

RegisterNUICallback("impound", function(data, cb)
    if (not data.plate) then return cb({}) end

    local timeout = 300

    Callback.TriggerServerCallback("galaxy-garage:takeVehicleOutFromImpound", function(properties)
        if (not properties) then
            exports["notification"]:createNotification({type = "error", text = "Nincs elegendő pénzed a kocsi kivételéhez!", duration = 5})
        else
            exports["notification"]:createNotification({type = "success", text = "Sikeresen kivetted a kocsit a garázsból!", duration = 5})
            spawnVehicle(data.plate, properties)
        end

        timeout = 0
    end, data.plate)

    while (timeout > 0) do
        timeout = timeout - 1
        Wait(100)
    end

    cb({})
end)

RegisterNUICallback("takeout", function(data, cb)
    if (not data.plate) then return cb({}) end
    if (not data.garageId) then return cb({}) end

    local timeout = 300

    Callback.TriggerServerCallback("galaxy-garage:takeVehicleOutFromGarage", function(status, properties)
        if (status) then
            spawnVehicle(data.plate, properties)
        end

        timeout = 0
    end, data.garageId, data.plate)

    while (timeout > 0) do
        timeout = timeout - 1
        Wait(100)
    end

    cb({})
end)

RegisterNUICallback("factionTakeout", function(data, cb)
    if (not data.plate) then return cb({}) end
    if (not data.garageId) then return cb({}) end
    if (not data.factionId) then return cb({}) end

    local timeout = 300

    Callback.TriggerServerCallback("galaxy-garage:takeVehicleOutFromFactionGarage", function(status, properties, parkingZones)
        if (status) then
            spawnVehicle(data.plate, properties, parkingZones)
        end

        timeout = 0
    end, data.garageId, data.plate, data.factionId)

    while (timeout > 0) do
        timeout = timeout - 1
        Wait(100)
    end

    cb({})
end)

RegisterNUICallback("quit", function(_, cb)
    closeUI()

    cb({})
end)

function createPed(model, coords, garageId, faction, userFaction)
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

    if (faction) then
        if (faction == tostring(userFaction.fid)) then
            exports["gl-target"]:AddTargetEntity(ped, {
                options = {
                    {
                        type = "client",
                        label = "Garázs megnyitása",
                        action = openFactionGarage,
                        garageId = garageId,
                        faction = faction
                    }
                }
            })
        end
    else
        exports["gl-target"]:AddTargetEntity(ped, {
            options = {
                {
                    type = "client",
                    label = "Garázs megnyitása",
                    action = openGarage,
                    garageId = garageId,
                }
            }
        })
    end

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

function storeVehicle(data)
    print(json.encode(data))
    if (not data.garageId) then return end
    if (not DoesEntityExist(data.entity)) then return end
    if (GetEntityType(data.entity) ~= 2) then return end

    local plate = GetVehicleNumberPlate(data.entity)
    local netId = NetworkGetNetworkIdFromEntity(data.entity)
    local properties = exports["galaxy-tuning"]:GetVehicleProperties(data.entity)

    TriggerServerEvent("galaxy-garage:takeVehicleIntoGarage", data.garageId, plate, properties, netId, data.factionId)
end

function openGarage(data)
    local garageId = data.garageId
    currentVehicles = {}
    Callback.TriggerServerCallback("galaxy-garage:fetchUserVehicles", function(vehicles)
        for k, v in pairs(vehicles) do
            currentVehicles[k] = {
                plate = k,
                model = v.model,
                name = v.vehicleName,
                impounded = v.impounded,
                garageId = garageId
            }
        end

        openUI(currentVehicles)
    end, garageId)
end

function openFactionGarage(data)
    local garageId = data.garageId
    currentVehicles = {}

    Callback.TriggerServerCallback("galaxy-garage:fetchFactionVehicles", function(vehicles)
        print(json.encode(vehicles))
        for k, v in pairs(vehicles) do
            currentVehicles[k] = {
                plate = k,
                model = v.model,
                name = v.vehicleName,
                impounded = v.impounded,
                garageId = garageId
            }
        end

        openUI(currentVehicles, data.faction)
    end)
end

CreateThread(function()
    local factionGarages = nil
    local timeout = 300

    Callback.TriggerServerCallback("galaxy-garage:fetchFactionGarages", function(data)
        factionGarages = data
        timeout = 0
    end)

    while (timeout > 0) do
        timeout = timeout - 1
        Wait(100)
    end

    if (factionGarages) then
        for _, v in pairs(factionGarages) do
            print(json.encode(factionGarages))
            garageZones[string.format("faction_garage_%s", v.id)] = {
                zoneId = v.id,
                zone = PolyZone:Create(v.polyzone.zone, {
                    name = string.format("faction_garage_%s", v.id),
                    minZ = v.polyzone.minZ,
                    maxZ = v.polyzone.maxZ,
                    debugGrid = true,
                    gridDivision = 30
                }),
                factionId = v.factionId,
                isIn = false,
                ped = {
                    model = config.default.ped.model,
                    coords = v.coords
                },
                entity = nil
            }
        end
    end

    for k, v in pairs(config.locations) do
        garageZones[string.format("garage_%s", k)] = {
            zoneId = k,
            zone = PolyZone:Create(v.zone, {
                name = string.format("garage_%s", k),
                minZ = v.minZ,
                maxZ = v.maxZ,
                debugGrid = false,
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
        local faction = exports["fraction"]:get()

        for _, v in pairs(garageZones) do
            local isIn = false

            if (v.zone:isPointInside(coords)) then
                isIn = true
            end

            if (isIn) then
                if (not v.isIn) then
                    v.entity = createPed(v.ped.model, v.ped.coords, v.zoneId, v.factionId, faction)
                    if (v.factionId) then
                        Callback.TriggerServerCallback("galaxy-garage:fetchAllFactionVehicles", function(userId, vehicles, restricted)
                            exports["gl-target"]:AddType(2, {
                                options = {
                                    {
                                        type = "client",
                                        action = storeVehicle,
                                        label = "XJármű leparkolása",
                                        garageId = v.zoneId,
                                        factionId = v.factionId,
                                        canInteract = function(entity)
                                            local plate = GetVehicleNumberPlate(entity)
                                            if (not faction) then return false end
                                            if (not faction.fid) then return false end
                                            if (restricted) then
                                                if (not vehicles[plate]) then return false end
                                                if (vehicles[plate].owner ~= userId) then return false end
                                            end

                                            return v.factionId == tostring(faction.fid)
                                        end
                                    }
                                },
                                distance = 2.5
                            })
                        end)
                    else
                        Callback.TriggerServerCallback("galaxy-garage:fetchAllUserVehicle", function(vehicles)
                            exports["gl-target"]:AddType(2, {
                                options = {
                                    {
                                        type = "client",
                                        action = storeVehicle,
                                        label = "XJármű leparkolása",
                                        garageId = v.zoneId,
                                        canInteract = function(entity)
                                            return vehicles[GetVehicleNumberPlate(entity)] ~= nil
                                        end
                                    }
                                },
                                distance = 2.5
                            })
                        end)
                    end
                end
            else
                if (v.isIn) then
                    removePed(v.entity)
                    exports["gl-target"]:RemoveType(2, { "XJármű leparkolása" })
                end
            end

            v.isIn = isIn
        end

        Wait(3000)
    end
end)

RegisterNetEvent("galaxy-garage:setVehicleData")
AddEventHandler("galaxy-garage:setVehicleData", function (netId, properties)
    if (not NetworkDoesEntityExistWithNetworkId(netId)) then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if (GetEntityType(vehicle) ~= 2) then return end
    exports["galaxy-tuning"]:SetVehicleProperties(vehicle, properties)
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