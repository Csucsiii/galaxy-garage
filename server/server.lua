---@diagnostic disable: undefined-global, lowercase-global
local userVehicles = {}
local factionGarages = {}
local factionVehicles = {}

Callback.RegisterServerCallback("galaxy-garage:fetchAllUserVehicle", function (source, cb)
    local user = getUserIdentifers(source)

    cb(userVehicles[user.id] and userVehicles[user.id].plates or {} or {})
end)

Callback.RegisterServerCallback("galaxy-garage:fetchAllFactionVehicles", function(source, cb)
    local faction = exports["fraction"]:get(source)

    faction.fid = tostring(faction.fid)

    if (not faction or not faction.fid) then return cb({}) end
    if (not factionVehicles[faction.fid]) then return cb({}) end

    local user = getUserIdentifers(source)

    for _, v in pairs(config.restrictedFactions) do
        if (faction.fid == v.id) then
            return cb(user.id, factionVehicles[faction.fid], true)
        end
    end

    return cb(user.id, factionVehicles[faction.fid])
end)

Callback.RegisterServerCallback("galaxy-garage:fetchUserVehicles", function(source, cb, garageId)
    local user = getUserIdentifers(source)
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
    local user = getUserIdentifers(source)
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

    userVehicles[user.id].plates[plate].vehicle.stored = false
    userVehicles[user.id].plates[plate].vehicle.garageId = nil
    userVehicles[user.id].plates[plate].garage = nil

    userVehicles[user.id].plates[plate].autosave = true
    userVehicles[user.id].autosave = true

    cb(true, properties)
end)

Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromFactionGarage", function(source, cb, garageId, plate, factionId)
    local faction = exports["fraction"]:get(source)
    faction.fid = tostring(faction.fid)

    if (not faction or not faction.fid) then return cb(false) end
    if (factionId ~= faction.fid) then return cb(false) end

    garageId = tostring(garageId)

    if (not factionVehicles[faction.fid]) then return cb(false) end
    if (not factionVehicles[faction.fid][plate]) then return cb(false) end

    local vehicle = factionVehicles[faction.fid][plate]
    if(vehicle.garageId ~= garageId) then return cb(false) end
    if (not userVehicles[vehicle.owner] or not userVehicles[vehicle.owner].plates) then return cb(false) end
    if (not userVehicles[vehicle.owner].plates[plate] or not userVehicles[vehicle.owner].plates[plate].vehicle) then return cb (false) end

    factionVehicles[faction.fid][plate].stored = false
    factionVehicles[faction.fid][plate].garageId = nil

    userVehicles[vehicle.owner].plates[plate].vehicle.stored = false
    userVehicles[vehicle.owner].plates[plate].vehicle.garageId = nil
    userVehicles[vehicle.owner].garage = nil

    userVehicles[vehicle.owner].plates[plate].autosave = true
    userVehicles[vehicle.owner].autosave = true

    local properties = json.decode(json.encode(userVehicles[vehicle.owner].plates[plate].vehicle.properties))

    local zone = nil
    local currentGarage = factionGarages[faction.fid]

    if (currentGarage) then
        for _, v in pairs(currentGarage) do
            if (tostring(v.id) == garageId) then
                zone = v.polyzone.parkingZones
                break
            end
        end
    end

    cb(true, properties, zone)
end)

Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromImpound", function (source, cb, plate)
    local user = getUserIdentifers(source)
    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
        return cb(false)
    end

    if (not userVehicles[user.id].plates or not userVehicles[user.id].plates[plate]) then
        return cb(false)
    end

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

    userVehicles[user.id].plates[plate].vehicle.stored = false
    userVehicles[user.id].plates[plate].vehicle.impounded = false
    userVehicles[user.id].plates[plate].vehicle.garageId = nil
    userVehicles[user.id].plates[plate].garage = nil

    userVehicles[user.id].plates[plate].autosave = true
    userVehicles[user.id].autosave = true

    local factionId = userVehicles[user.id].plates[plate].vehicle.factionId
    if (factionId) then
        if (factionVehicles[factionId] and factionVehicles[factionId][plate]) then
            factionVehicles[factionId][plate] = userVehicles[user.id].plates[plate].vehicle
        end
    end

    cb(userVehicles[user.id].plates[plate].vehicle.properties)
end)

Callback.RegisterServerCallback("galaxy-garage:fetchFactionGarages", function(source, cb)
    local faction = exports["fraction"]:get(source)

    if (not faction) then return cb(false) end
    if (not faction.fid) then return cb(false) end

    cb(factionGarages[tostring(faction.fid)])
end)

Callback.RegisterServerCallback("galaxy-garage:fetchFactionVehicles", function(source, cb)
    local faction = exports["fraction"]:get(source)

    if (not faction) then return cb(false) end
    if (not faction.fid) then return cb(false) end

    local factionId = tostring(faction.fid)

    local vehicles = {}
    for _, v in pairs(config.restrictedFactions) do
        if (factionId == v.id) then
            local user = getUserIdentifers(source)
            for k, v2 in pairs(factionVehicles[factionId]) do
                if ((v2.stored or v2.impounded) and v2.owner == user.id) then
                    vehicles[k] = v2
                end
            end

            return cb(vehicles)
        end
    end

    for k, v in pairs(factionVehicles[factionId]) do
        if (v.stored or v.impounded) then
            vehicles[k] = v
        end
    end

    cb(vehicles)
end)

function getUserIdentifers(playerId)
    local dcid = exports["accountmanager"]:GetDiscordId(playerId)
    local userId = tostring(exports["accountmanager"]:GetUserIdByDiscordId(dcid))

    return {
        dcid = dcid,
        id = userId
    }
end

RegisterNetEvent("galaxy-garage:takeVehicleIntoGarage")
AddEventHandler("galaxy-garage:takeVehicleIntoGarage", function(garageId, plate, properties, netId, factionId)
    garageId = tostring(garageId)
    local _source = source
    local faction = exports["fraction"]:get(_source)
    factionId = tostring(factionId)

    if (factionId) then
        if (not faction or not faction.fid) then return end
        faction.fid = tostring(faction.fid)

        if (faction.fid ~= factionId) then return end
        if (not factionVehicles[factionId]) then
            factionVehicles[factionId] = {}
        end

        if (not factionVehicles[factionId][plate]) then
            local user = getUserIdentifers(_source)
            if (not userVehicles[user.id] or not userVehicles[user.id].plates or not userVehicles[user.id].plates[plate]) then
                exports["notification"]:createNotification({type = "error", text = "Ez nem a te járműved!", duration = 5})
                return
            end

            factionVehicles[factionId][plate] = userVehicles[user.id].plates[plate].vehicle
        end

        local vehicle = factionVehicles[factionId][plate]

        userVehicles[vehicle.owner].plates[plate].vehicle.properties = properties
        userVehicles[vehicle.owner].plates[plate].vehicle.stored = true
        userVehicles[vehicle.owner].plates[plate].vehicle.garageId = garageId
        userVehicles[vehicle.owner].plates[plate].vehicle.factionId = factionId
        userVehicles[vehicle.owner].plates[plate].garage = garageId

        userVehicles[vehicle.owner].autosave = true
        userVehicles[vehicle.owner].plates[plate].autosave = true

        factionVehicles[factionId][plate] = userVehicles[vehicle.owner].plates[plate].vehicle
    else
        local user = getUserIdentifers(_source)

        if (not userVehicles[user.id]) then
            userVehicles[user.id] = {}
            return
        end

        if (not userVehicles[user.id].plates and not userVehicles[user.id].plates[plate]) then
            exports["notification"]:createNotification({type = "error", text = "Ez nem a jármű nem a tied!", duration = 5})
            return
        end

        if (factionVehicles[factionId] and factionVehicles[factionId][plate]) then
            factionVehicles[factionId][plate] = nil
            userVehicles[user.id].plates[plate].vehicle.factionId = nil
        end

        userVehicles[user.id].plates[plate].vehicle.properties = properties
        userVehicles[user.id].plates[plate].vehicle.stored = true
        userVehicles[user.id].plates[plate].vehicle.garageId = garageId

        userVehicles[user.id].autosave = true
        userVehicles[user.id].plates[plate].autosave = true

        userVehicles[user.id].plates[plate].garage = garageId
    end

    DeleteEntity(NetworkGetEntityFromNetworkId(netId))
end)

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
                local factionId = tostring(v.factionId)
                if (not factionVehicles[factionId]) then
                    factionVehicles[factionId] = {}
                end

                factionVehicles[factionId][v.plate] = {
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
            end
        end
    end)

    MySQL.Async.fetchAll("SELECT * FROM `faction_garages`", {}, function (result)
        for _, v in pairs(result) do
            local factionId = tostring(v.factionId)

            if (not factionGarages[factionId]) then
                factionGarages[factionId] = {}
            end

            table.insert(factionGarages[factionId], {
                id = v.id,
                factionId = factionId,
                coords = json.decode(v.coords),
                polyzone = json.decode(v.zone)
            })
        end
    end)
end)

function RegisterProctedCommand(name, rank, cb)
    exports["command-handler"]:registerCommand(name, rank, cb, GetCurrentResourceName())
end

RegisterProctedCommand("createFactionGarage", "mod", function(source, args)
    local zone = {
        zone = {
            vec2(267.78, -1146.98),
            vec2(267.65, -1165.71),
            vec2(246.43, -1165.03),
            vec2(246.08, -1146.51)
        },
        minZ = 20.0,
        maxZ = 40.0
    }
    local factionId = args[1]
    local coords = GetEntityCoords(GetPlayerPed(source))
    MySQL.Async.insert("INSERT INTO `faction_garages` (id, factionId, coords, zone) VALUES (NULL, @factionId, @coords, @zone)", {
        ["@factionId"] = factionId,
        ["@coords"] = json.encode(coords),
        ["@zone"] = json.encode(zone)
    }, function(id)

        if (not factionGarages[factionId]) then
            factionGarages[factionId] = {}
        end

        table.insert(factionGarages[factionId], {
            id = id,
            factionId = factionId,
            coords = coords,
            zone = zone
        })
    end)
end)