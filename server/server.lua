---@diagnostic disable: undefined-global, lowercase-global

Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromImpound", function (source, cb, plate)
    local user = GetUserIdentifers(source)
    if (not DoesUserOwnVehicle(user.id, plate)) then return cb(false) end

    local balance = exports["balance"]:getBalance(source)
    local cash = exports["inventory"]:getItemCount(source, 104) --cash id 
    local paid = false

    if (balance.usd >= config.impound.price) then
        exports["balance"]:changeBalance(source, {
            type = "usd",
            amount = config.impound.price * 1,
            paymentType = "impounded"
        })

        paid = true
    elseif (cash and cash >= config.impound.price) then
        exports["inventory"]:changeItem(source, 104, tonumber(config.impound.price) * -1)
        paid = true
    end

    if (not paid) then
        return cb(false)
    end

    TakeOutVehicleFromUser(user.id, plate, true)
    local userVehicle = GetUserVehicle(user.id, plate)
    if (userVehicle.factionId) then
        SetVehicleIntoFactionGarage(user.id, userVehicle.factionId, plate)
    end

    cb(userVehicle.plates[plate].vehicle.properties)
end)

Callback.RegisterServerCallback("galaxy-garage:doesPlayerOwnVehicle", function(source, cb, plate)
    local user = GetUserIdentifers(source)

    if (DoesUserOwnVehicle(user.id, plate)) then return cb(true) end
    if (DoesFactionOwnVehicle(source, plate)) then return cb(true) end

    return cb(false)
end)

function GetUserIdentifers(playerId)
    local dcid = exports["accountmanager"]:GetDiscordId(playerId)
    local userId = tostring(exports["accountmanager"]:GetUserIdByDiscordId(dcid))

    return {
        dcid = dcid,
        id = userId
    }
end

function SaveVehicleProperties(properties)
    local plate = properties.plate:lower()
    local userVehicles = GetAllUserVehicles()
    for userId, v in pairs(userVehicles) do
        if (v.plates) then
            if (v.plates[plate]) then
                SaveUserVehicle(userId, plate, properties)
                break
            end
        end
    end
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
    local success = false

    if (factionId) then
        success = StoreVehicleIntoGarage(_source, garageId, faction, plate, properties, factionId)
    else
        success = StoreUserVehicle(_source, faction, plate, factionId, garageId, properties)
    end

    if (success) then
        TriggerEvent("vehicle_spawn:UnregistVehicle", plate)
        DeleteEntity(NetworkGetEntityFromNetworkId(netId))
    end
end)

RegisterNetEvent("galaxy-garage:vehicleDoorlockSync")
AddEventHandler("galaxy-garage:vehicleDoorlockSync", function(netId, status)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local entityOwner = NetworkGetEntityOwner(entity)

    TriggerClientEvent("galaxy-garage:vehicleDoorlockSync", entityOwner, netId, status)
end)

-- AddEventHandler("playerConnected", function(playerId)
--     local user = GetUserIdentifers(playerId)

--     print(user.id)
--     MySQL.Async.fetchScalar("SELECT id FROM `account` WHERE userId=@userId LIMIT 1", {
--         ["@userId"] = user.id
--     }, function(id)
--         print("Account Id")
--         MySQL.Async.fetchAll("SELECT * FROM `vehicles` WHERE owner=@owner", {
--             ["@owner"] = id
--         }, function(result)
--             for _, v in pairs(result) do
--                 local obj = {
--                     model = v.model,
--                     vehicleName = v.vehicleName,
--                     plate = v.plate,
--                     properties = json.decode(v.data),
--                     factionId = nil,
--                     garageId = v.garageId,
--                     stored = v.isOut,
--                     impounded = false
--                 }

--                 print("Adding Vehicle", v.plate)
--                 AddNewVehicle(playerId, obj)

--                 MySQL.Async.execute("DELETE FROM `vehicles` WHERE id=@id", {
--                     ["@id"] = v.id
--                 }, function(rowsChanged)
--                     if (rowsChanged) then
--                         print("Removed Vehicle", v.id, v.plate, v.model)
--                     end
--                 end)
--             end
--         end)
--     end)
-- end)


exports("saveVehicleProperties", SaveVehicleProperties)