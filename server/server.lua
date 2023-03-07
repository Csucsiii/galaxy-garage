---@diagnostic disable: undefined-global, lowercase-global

-- Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromImpound", function (source, cb, plate)
--     local user = getUserIdentifers(source)
--     if (not userVehicles[user.id]) then
--         userVehicles[user.id] = {}
--         return cb(false)
--     end

--     if (not userVehicles[user.id].plates or not userVehicles[user.id].plates[plate]) then
--         return cb(false)
--     end

--     local balance = exports["balance"]:getBalance(source)
--     local cash = exports["inventory"]:getItemCount(source, 104) --cash id 
--     local paid = false

--     if (balance.usd >= config.impound.price) then
--         exports["balance"]:changeBalance(source, {
--             type = "usd",
--             amount = config.impound.price * 1,
--             paymentType = "impounded"
--         })

--         paid = true
--     elseif (cash and cash >= config.impound.price) then
--         exports["inventory"]:changeItem(source, 104, tonumber(config.impound.price) * -1)
--         paid = true
--     end

--     if (not paid) then
--         return cb(false)
--     end

--     userVehicles[user.id].plates[plate].vehicle.stored = false
--     userVehicles[user.id].plates[plate].vehicle.impounded = false
--     userVehicles[user.id].plates[plate].vehicle.garageId = nil
--     userVehicles[user.id].plates[plate].garage = nil

--     userVehicles[user.id].plates[plate].autosave = true
--     userVehicles[user.id].autosave = true

--     local factionId = userVehicles[user.id].plates[plate].vehicle.factionId
--     if (factionId) then
--         if (factionVehicles[factionId] and factionVehicles[factionId][plate]) then
--             factionVehicles[factionId][plate] = userVehicles[user.id].plates[plate].vehicle
--         end
--     end

--     cb(userVehicles[user.id].plates[plate].vehicle.properties)
-- end)

function getUserIdentifers(playerId)
    local dcid = exports["accountmanager"]:GetDiscordId(playerId)
    local userId = tostring(exports["accountmanager"]:GetUserIdByDiscordId(dcid))

    return {
        dcid = dcid,
        id = userId
    }
end

RegisterNetEvent("galaxy-garage:spawnVehicle")
AddEventHandler("galaxy-garage:spawnVehicle", function(modelHash, coords, properties)
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.w, true, true)

    while (not DoesEntityExist(vehicle)) do
        Wait(100)
    end

    local entityOwner = NetworkGetEntityOwner(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    TriggerClientEvent("galaxy-garage:setVehicleData", entityOwner, netId, properties)
end)

RegisterNetEvent("galaxy-garage:takeVehicleIntoGarage")
AddEventHandler("galaxy-garage:takeVehicleIntoGarage", function(garageId, plate, properties, netId, factionId)
    garageId = tostring(garageId)
    local _source = source
    local faction = exports["fraction"]:get(_source)
    if (not faction or not faction.fid) then return end
    faction.fid = tostring(faction.fid)
    factionId = factionId and tostring(factionId) or nil

    if (factionId) then
        StoreVehicleIntoGarage(garageId, faction, plate, properties, factionId)
    else
        StoreUserVehicle(_source, faction, plate, factionId, properties)
    end

    DeleteEntity(NetworkGetEntityFromNetworkId(netId))
end)