---@diagnostic disable: undefined-global
local factionGarages = {}
local factionVehicles = {}

Callback.RegisterServerCallback("galaxy-garage:fetchFactionGarages", function(source, cb)
    local faction = exports["fraction"]:get(source)

    if (not faction) then return cb(false) end
    if (not faction.fid) then return cb(false) end

    cb(factionGarages[tostring(faction.fid)])
end)

Callback.RegisterServerCallback("galaxy-garage:getZone", function(source, cb, garageId)
    local faction = exports["fraction"]:get(source)

    if (not faction or not faction.fid) then return cb(false) end
    faction.fid = tostring(faction.fid)
    garageId = tostring(garageId)

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

    cb(zone)
end)

Callback.RegisterServerCallback("galaxy-garage:fetchAllFactionVehicles", function(source, cb)
    local faction = exports["fraction"]:get(source)

    faction.fid = tostring(faction.fid)

    if (not faction or not faction.fid) then return cb({}) end
    local user = GetUserIdentifers(source)
    local userVehicles = GetUserVehicles(user.id)

    for key in pairs(config.emergency) do
        if (faction.fid == key) then
            if (not factionVehicles or not factionVehicles[faction.fid]) then
                return cb(user.id, nil, true, userVehicles and userVehicles.plates or nil or nil)
            end

            return cb(user.id, factionVehicles[faction.fid], true, userVehicles and userVehicles.plates or nil or nil)
        end
    end

    return cb(user.id, factionVehicles[faction.fid], false, userVehicles and userVehicles.plates or nil or nil)
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

    if (not DoesUserOwnVehicle(vehicle.owner, plate)) then
        return cb(false)
    end

    factionVehicles[faction.fid][plate].stored = false
    TakeOutVehicleFromUser(vehicle.owner, plate)

    cb(true, GetVehiclePropertiesFromCache(vehicle.owner, plate))
end)

Callback.RegisterServerCallback("galaxy-garage:fetchFactionVehicles", function(source, cb, garageId)
    local faction = exports["fraction"]:get(source)

    if (not faction) then return cb(false) end
    if (not faction.fid) then return cb(false) end

    local factionId = tostring(faction.fid)

    local vehicles = {}
    print("Vehicle")
    for key in pairs(config.emergency) do
        if (factionId == key) then
            local user = GetUserIdentifers(source)
            for k, v in pairs(factionVehicles[factionId]) do
                if ((v.stored or v.impounded) and v.owner == user.id and v.garageId == tostring(garageId)) then
                    vehicles[k] = v
                end
            end

            return cb(vehicles)
        end
    end

    for k, v in pairs(factionVehicles[factionId]) do
        if ((v.stored or v.impounded) and v.garageId == tostring(garageId)) then
            vehicles[k] = v
        end
    end

    cb(vehicles)
end)

MySQL.ready(function ()
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

function AddVehicleToFactionCache(userId, garageId, data)
    local factionId = tostring(data.factionId)
    if (not factionVehicles[factionId]) then
        factionVehicles[factionId] = {}
    end

    factionVehicles[factionId][data.plate] = {
        id = data.id,
        owner = userId,
        model = data.model,
        properties = json.decode(data.properties),
        plate = data.plate,
        vehicleName = data.vehicleName,
        factionId = data.factionId,
        garageId = garageId,
        impounded = data.impounded,
        stored = true
    }
end

function StoreVehicleIntoGarage(playerId, garageId, faction, plate, properties, factionId)
    if (faction.fid ~= factionId) then return false end
    if (not factionVehicles[factionId]) then
        factionVehicles[factionId] = {}
    end

    if (not factionVehicles[factionId][plate]) then
        local user = GetUserIdentifers(playerId)
        local userVehicles = GetUserVehicles(user.id)
        if (not userVehicles or not userVehicles.plates or not userVehicles.plates[plate]) then
            TriggerClientEvent("notification:createNotification", playerId, {type = "error", text = "Ez nem a te járműved!", duration = 5})
            return false
        end

        factionVehicles[factionId][plate] = userVehicles.plates[plate].vehicle
    end

    local vehicle = factionVehicles[factionId][plate]
    local vehicleProperties = GetVehiclePropertiesFromCache(vehicle.owner, plate)

    for key, v in pairs(properties) do
        vehicleProperties[key] = v
    end

    factionVehicles[factionId][plate] = StoreVehicle(vehicle.owner, plate, {
        garageId = garageId,
        factionId = factionId,
        properties = vehicleProperties
    })


    return true
end

function RemoveVehicleFromFactionVehicles(faction, plate)
    if (factionVehicles[faction.fid] and factionVehicles[faction.fid][plate]) then
        factionVehicles[faction.fid][plate] = nil

        return true
    end

    return false
end

function SetVehicleIntoFactionGarage(userId, factionId, plate)
    if (factionVehicles[factionId] and factionVehicles[factionId][plate]) then
        factionVehicles[factionId][plate] = GetUserVehicle(userId, plate)
    end
end

function DoesFactionOwnVehicle(playerId, plate)
    local faction = exports["fraction"]:get(playerId)

    if (not faction) then return false end
    if (not faction.fid) then return false end
    if (not plate) then return false end

    local factionId = tostring(faction.fid)

    if (not factionVehicles[factionId]) then return false end
    if (not factionVehicles[factionId][plate]) then return false end
    if (factionVehicles[factionId][plate].plate ~= plate) then return false end


    return true
end