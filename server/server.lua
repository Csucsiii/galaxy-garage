---@diagnostic disable: undefined-global, lowercase-global
local userVehicles = {}
local factionVehicles = {}
local spawnedVehicles = {}

Callback.RegisterServerCallback("galaxy-garage:fetchUserVehicles", function(source, cb, garageId)
    local user = getUserIdentifers(source)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
    end

    garageId = tostring(garageId)
    local allUserVehicles = userVehicles[user.id]
    local vehicles = {}

    for k, v in pairs(allUserVehicles) do
        print(json.encode(v))
        if (v[garageId]) then
            if (spawnedVehicles[k] and DoesEntityExist(spawnedVehicles[k])) then
                v[garageId].impounded = true
            end

            table.insert(vehicles, v)
        end
    end

    cb(vehicles or {})
end)

Callback.RegisterServerCallback("galaxy-garage:fetchFactionVehicles", function(source, cb, garageId)
    local faction = exports["fraction"]:get(source)

    if (not faction or not faction.name) then return cb({}) end
    if (not factionVehicles[faction.name]) then return cb({}) end


    cb(factionVehicles[faction.name][tostring(garageId)] or {})
end)

Callback.RegisterServerCallback("galaxy-garage:takeVehicleOutFromGarage", function(source, cb, garageId, plate, coords)
    local user = getUserIdentifers(source)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}
        return cb(false)
    end


    local current = userVehicles[user.id][v.plate]

    if (not current) then
        return cb(false)
    end

    local currentGarage = current[tostring(garageId)]

    if (not currentGarage) then
        return cb(false)
    end

    plate = tostring(plate)
    currentGarage.stored = false

    local data = currentGarage.properties
    local vehicle = CreateVehicle(data.model, coords.x, coords.y, coords.z, coords.h, true, true)
    spawnedVehicles[plate] = vehicle

    cb(true, NetworkGetNetworkIdFromEntity(vehicle))
end)

Callback.RegisterServerCallback("galaxy-garage:takeVehicleIntoGarage", function(source, cb, garageId, plate, properties)
    local user = getUserIdentifers(source)

    if (not userVehicles[user.id]) then
        userVehicles[user.id] = {}

        return cb(false)
    end

    garageId = tostring(garageId)
    local current = userVehicles[user.id][plate]

    if (not current) then
        return cb(false)
    end

    for _, v in pairs(current) do
        if (v.plate == plate) then
            if (k == garageId) then
                v.properties = properties
                v.stored = true
            else
                current[garageId] = json.decode(json.encode(v))
                current[garageId].properties = properties
                current[garageId].stored = true
                current[garageId].garageId = garageId

                --Remove old garage
                current[k] = nil
            end

            return cb(true)
        end
    end

    cb(false)
end)

function getUserIdentifers(playerId)
    local dcid = exports["accountmanager"]:GetDiscordId(playerId)
    local userId = tostring(exports["accountmanager"]:GetUserIdByDiscordId(dcid))

    return {
        dcid = dcid,
        id = userId
    }
end

MySQL.ready(function()
    -- MySQL.Async.fetchAll("SELECT * FROM `faction_vehicles`", {}, function (result)
    --     factionVehicles = {}
    --     for _, v in pairs(result) do
    --         local faction = tostring(v.faction)
    --         factionVehicles[faction] = {}
    --         factionVehicles[faction][v.plate][tostring(v.garageId)] = {
    --             id = v.id,
    --             faction = v.faction,
    --             properties = v.properties,
    --             plate = v.plate,
    --             garageId = v.garageId,
    --             stored = true
    --         }
    --     end
    -- end)
    local players = GetPlayers()
    for _, playerId in pairs(players) do
        local user = getUserIdentifers(playerId)

        print(json.encode(user))
        MySQL.Async.fetchAll("SELECT * FROM `user_vehicles` WHERE userId=@userId", {
            ["@userId"] = user.id
        }, function(result)
            print(json.encode(result))
            userVehicles[user.id] = {}

            for _, v in pairs(result) do
                userVehicles[user.id][v.plate] = {}
                userVehicles[user.id][v.plate][tostring(v.garageId)] = {
                    id = v.id,
                    owner = user.id,
                    properties = v.properties,
                    plate = v.plate,
                    garageId = v.garageId,
                    impounded = v.store and false or true,
                    stored = v.stored
                }
            end
        end)
    end

    print(json.encode(userVehicles))
end)

AddEventHandler("playerConnected", function(playerId)
    local dcid = exports["accountmanager"]:GetDiscordId(playerId)
    local userId = tostring(exports["accountmanager"]:GetUserIdByDiscordId(dcid))

    if (not userVehicles[userId]) then
        MySQL.Async.fetchAll("SELECT * FROM `user_vehicles` WHERE userId=@userId", {
            ["@userId"] = tonumber(userId)
        }, function(result)
            userVehicles[userId] = {}

            for _, v in pairs(result) do
                userVehicles[userId][v.plate][tostring(v.garageId)] = {
                    id = v.id,
                    owner = userId,
                    properties = v.properties,
                    plate = v.plate,
                    garageId = v.garageId,
                    impounded = v.store and false or true,
                    stored = v.stored
                }
            end
        end)
    end
end)