---@diagnostic disable: undefined-global
local userVehicles = {}

Callback.RegisterServerCallback("galaxy-garage:fetchAllUserVehicle", function (source, cb)
    local user = GetUserIdentifers(source)
    local faction = exports["fraction"]:get(source)

    if (not userVehicles[user.id] or not userVehicles[user.id].plates) then return cb({}) end
    if (not faction or not faction.fid) then return cb(userVehicles[user.id] and userVehicles[user.id].plates or {} or {}) end
    faction.fid = tostring(faction.fid)

    local vehicles = {}
    for _, v in pairs(config.emergency) do
        if (v.id == faction.fid) then
            for k, v2 in pairs(userVehicles[user.id]) do
                if ((v2.stored or v2.impounded) and v2.owner == user.id) then
                    vehicles[k] = v2
                end
            end

            return cb(vehicles)
        end
    end

    cb(userVehicles[user.id] and userVehicles[user.id].plates or {} or {})
end)

Callback.RegisterServerCallback("galaxy-garage:fetchUserVehicles", function(source, cb, garageId)
    local user = GetUserIdentifers(source)
    garageId = tostring(garageId)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
    end

    local vehicles = {}
    if (not userVehicles[user.id].plates) then return cb({}) end

    for k, v in pairs(userVehicles[user.id].plates) do
        if (v.garage == garageId) then
            if (v.vehicle.stored) then
                vehicles[k] = v.vehicle
            end
        end
    end

    cb(vehicles)
end)

Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromGarage", function(source, cb, garageId, plate)
    local user = GetUserIdentifers(source)
    garageId = tostring(garageId)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
        return cb(false)
    end

    if (not userVehicles[user.id].plates or not userVehicles[user.id].plates[plate]) then
        TriggerClientEvent("notification:createNotification", source, {type = "error", text = "Ez nem a te járműved!", duration = 5})
        return cb(false)
    end

    if (not userVehicles[user.id].plates[plate].garage or userVehicles[user.id].plates[plate].garage ~= garageId) then
        TriggerClientEvent("notification:createNotification", source, {type = "error", text = "Ez a jármű nem ebben a garázsban található!", duration = 5})
        return cb(false)
    end

    local properties = json.decode(json.encode(userVehicles[user.id].plates[plate].vehicle.properties))

    TakeOutVehicleFromUser(user.id, plate)
    cb(true, properties)
end)

MySQL.ready(function()
    MySQL.Async.fetchAll("SELECT * FROM `user_vehicles`", {}, function(result)
        for _, v in pairs(result) do
            local userId = v.userId

            if (not userVehicles[userId]) then
                userVehicles[userId] = {
                    autosave = false
                }
            end

            local garageId = tostring(v.garageId)

            if (not userVehicles[userId].plates) then
                userVehicles[userId].plates = {}
            end

            if (not userVehicles[userId].plates[v.plate]) then
                userVehicles[userId].plates[v.plate] = {
                    autosave = false,
                    vehicle = nil,
                    garage = {}
                }
            end

            userVehicles[userId].plates[v.plate].vehicle = {
                id = v.id,
                owner = userId,
                model = v.model,
                properties = json.decode(v.properties),
                plate = v.plate,
                vehicleName = v.vehicleName,
                factionId = v.factionId,
                garageId = garageId,
                impounded = v.impounded,
                stored = true
            }
            userVehicles[userId].plates[v.plate].garage = garageId

            if (v.factionId) then
                AddVehicleToFactionCache(userId, garageId, v)
            end

            -- print("ASD", json.encode(v))
        end
    end)
end)

function StoreUserVehicle(playerId, faction, plate, factionId, garageId, properties)
    local user = GetUserIdentifers(playerId)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
        return false
    end

    if (not userVehicles[user.id].plates and not userVehicles[user.id].plates[plate]) then
        TriggerClientEvent("notification:createNotification", _source, {type = "error", text = "Ez nem a jármű nem a tied!", duration = 5})
        return false
    end

    if (RemoveVehicleFromFactionVehicles(faction, plate)) then
        userVehicles[user.id].plates[plate].vehicle.factionId = nil
    end

    local vehicleProperties = GetVehiclePropertiesFromCache(user.id, plate)

    for key, v in pairs(properties) do
        vehicleProperties[key] = v
    end

    StoreVehicle(user.id, plate, {
        garageId = garageId,
        factionId = factionId,
        properties = vehicleProperties
    })

    return true
end

function GetAllUserVehicles()
    return userVehicles
end

function GetUserVehicles(userId)
    return userVehicles[userId]
end

function GetUserVehicle(userId, plate)
    return userVehicles[userId].plates[plate].vehicle
end

function SaveUserVehicle(userId, plate, properties)
    if (userVehicles[userId]) then
        if (userVehicles[userId].plates) then
            if (userVehicles[userId].plates[plate]) then
                userVehicles[userId].plates[plate].vehicle.properties = properties
            end
        end
    end
end

function TakeOutVehicleFromUser(userId, plate, impound)
    userVehicles[userId].plates[plate].vehicle.stored = false
    if (impound) then
        userVehicles[user.id].plates[plate].vehicle.impounded = false
    end

    userVehicles[userId].garage = nil
    userVehicles[userId].plates[plate].autosave = true
    userVehicles[userId].autosave = true
end

function StoreVehicle(userId, plate, data)
    userVehicles[userId].plates[plate].vehicle.properties = data.properties
    userVehicles[userId].plates[plate].vehicle.stored = true
    userVehicles[userId].plates[plate].vehicle.garageId = data.garageId
    userVehicles[userId].plates[plate].vehicle.factionId = data.factionId
    userVehicles[userId].plates[plate].garage = data.garageId

    userVehicles[userId].autosave = true
    userVehicles[userId].plates[plate].autosave = true

    return userVehicles[userId].plates[plate].vehicle
end

function DoesUserOwnVehicle(userId, plate)
    if (not userVehicles[userId] or not userVehicles[userId].plates) then return false end
    if (not userVehicles[userId].plates[plate] or not userVehicles[userId].plates[plate].vehicle) then return false end

    return true
end

function GetVehiclePropertiesFromCache(userId, plate)
    return json.decode(json.encode(userVehicles[userId].plates[plate].vehicle.properties))
end

function AddNewVehicle(playerId, data)
    if (not DoesEntityExist(GetPlayerPed(playerId))) then return end

    local user = GetUserIdentifers(playerId)
    MySQL.Async.insert("INSERT INTO `user_vehicles` (id, userId, model, properties, plate, vehicleName, factionId, garageId, stored, impounded) VALUES (NULL, @userId, @model, @properties, @plate, @vehicleName, @factionId, NULL, @stored, @impounded)", {
        ["@userId"] = user.id,
        ["@model"] = data.model,
        ["@properties"] = json.encode(data.properties),
        ["@plate"] = data.plate,
        ["@vehicleName"] = data.vehicleName,
        ["@factionId"] = data.factionId,
        ["@stored"] = false,
        ["@impounded"] = false
    }, function(id)
        if (not userVehicles[user.id]) then
            userVehicles[user.id] = {
                autosave = false
            }
        end

        if (not userVehicles[user.id].plates) then
            userVehicles[user.id].plates = {}
        end

        if (not userVehicles[user.id].plates[data.plate]) then
            userVehicles[user.id].plates[data.plate] = {
                autosave = false,
                vehicle = nil,
                garage = {}
            }
        end

        userVehicles[user.id].plates[data.plate].vehicle = {
            id = id,
            owner = user.id,
            model = data.model,
            properties = data.properties,
            plate = data.plate,
            vehicleName = data.vehicleName,
            factionId = data.factionId,
            impounded = data.impounded,
        }
        userVehicles[user.id].plates[data.plate].garage = garageId

        if (data.factionId) then
            AddVehicleToFactionCache(user.id, nil, data)
        end
    end)
end

CreateThread(function()
    while true do
        Wait(0.5 * 60 * 1000)
        for userId, v in pairs(userVehicles) do
            if (v.autosave and v.plates) then
                for _, v2 in pairs(v.plates) do
                    if (v2.autosave) then
                        MySQL.Async.execute("UPDATE `user_vehicles` SET properties=@properties, stored=@stored, garageId=@garageId, impounded=@impounded, factionId=@factionId WHERE id=@id AND userId=@userId", {
                            ["@id"] = v2.vehicle.id,
                            ["@userId"] = userId,
                            ["@properties"] = json.encode(v2.vehicle.properties),
                            ["@stored"] = v2.vehicle.stored,
                            ["@garageId"] = v2.vehicle.garageId,
                            ["@impounded"] = v2.vehicle.impounded,
                            ["@factionId"] = v2.vehicle.factionId
                        }, function (rowChanged)
                            if (rowChanged ~= 0) then
                                v.autosave = false
                                v2.autosave = false

                                print("SAVED")
                            end
                        end)
                    end
                end
            end
        end
    end
end)

exports("addNewVehicle", AddNewVehicle)
exports("saveUserVehicle", SaveUserVehicle)