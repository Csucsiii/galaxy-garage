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
    if (not factionVehicles[faction.fid]) then return cb({}) end

    local user = getUserIdentifers(source)

    for _, v in pairs(config.restrictedFactions) do
        if (faction.fid == v.id) then
            return cb(user.id, factionVehicles[faction.fid], true)
        end
    end
    local userVehicles = GetUserVehicles(user.id)
    return cb(user.id, factionVehicles[faction.fid], false, userVehicles and userVehicles.plates or {} or {})
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
    for _, v in pairs(config.restrictedFactions) do
        if (factionId == v.id) then
            local user = getUserIdentifers(source)
            for k, v2 in pairs(factionVehicles[factionId]) do
                if ((v2.stored or v2.impounded) and v2.owner == user.id and v2.garageId == garageId) then
                    vehicles[k] = v2
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

local function RegisterProctedCommand(name, rank, cb)
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

function StoreVehicleIntoGarage(garageId, faction, plate, properties, factionId)
    if (faction.fid ~= factionId) then return end
    if (not factionVehicles[factionId]) then
        factionVehicles[factionId] = {}
    end

    if (not factionVehicles[factionId][plate]) then
        local user = getUserIdentifers(_source)
        if (not userVehicles[user.id] or not userVehicles[user.id].plates or not userVehicles[user.id].plates[plate]) then
            TriggerClientEvent("notification:createNotification", _source, {type = "error", text = "Ez nem a te járműved!", duration = 5})
            return
        end

        factionVehicles[factionId][plate] = userVehicles[user.id].plates[plate].vehicle
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
end

function RemoveVehicleFromFactionVehicles(faction, plate)
    if (factionVehicles[faction.fid] and factionVehicles[faction.fid][plate]) then
        factionVehicles[faction.fid][plate] = nil

        return true
    end

    return false
end