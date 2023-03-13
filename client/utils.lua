---@diagnostic disable: undefined-global

local entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end

        enum.destructor = nil
        enum.handle = nil
    end
}

function IsSpawnPointClear(coords, radius)
    local vehicles = GetVehiclesInArea(coords, radius)
    return #vehicles == 0
end

function GetVehiclesInArea(coords, area)
    local vehicles = GetVehicles()
    local vehiclesInArea = {}

    for i = 1, #vehicles, 1 do
        local vehicleCoords = GetEntityCoords(vehicles[i])
        local distance = GetDistanceBetweenCoords(vehicleCoords, coords.x, coords.y, coords.z, true)

        if distance <= area then
            table.insert(vehiclesInArea, vehicles[i])
        end
    end

    return vehiclesInArea
end

function GetClosestVehicle(coords)
    local function getClosestEntity(entities, isPlayerEntities)
        local closestEntity, closestEntityDistance, filteredEntities = -1, -1, nil

        coords = vector3(coords.x, coords.y, coords.z)

        for k, entity in pairs(entities) do
            local distance = #(coords - GetEntityCoords(entity))
            if closestEntityDistance == -1 or distance < closestEntityDistance then
                closestEntity, closestEntityDistance = isPlayerEntities and k or entity, distance
            end
        end
        return closestEntity, closestEntityDistance
    end


    return getClosestEntity(GetVehicles(), false)
end



function GetVehicles()
    local vehicles = {}

    for vehicle in EnumerateVehicles() do
        table.insert(vehicles, vehicle)
    end

    return vehicles
end

function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end

        local enum = {
            handle = iter,
            destructor = disposeFunc
        }
        setmetatable(enum, entityEnumerator)

        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next

        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end

function GetVehicleNumberPlate(vehicle)
    return string.gsub(string.lower(GetVehicleNumberPlateText(vehicle)), "%s+", "")
end

function GetVehicleProperties(vehicle)
    local nitroAmount = DecorExistOn(vehicle, "vehicle_nitro_amount") and DecorGetInt(vehicle, "vehicle_nitro_amount") or 0
    nitroAmount = nitroAmount < 0 and 0 or nitroAmount

    if DoesEntityExist(vehicle) then
        local windows = {}
        local tyres = {}
        local doors = {}
        for i = 1, 13, 1 do
            windows[i] = IsVehicleWindowIntact(vehicle, i - 1)
        end
        for i = 0, 10, 1 do
            tyres[i] = IsVehicleTyreBurst(vehicle, i)
        end
        for i = 0, 10, 1 do
            doors[i] = IsVehicleDoorDamaged(vehicle, i)
        end

        local fuelLevel = GetVehicleFuelLevel(vehicle)

        if (DecorExistOn(vehicle, "vehicle_fuel")) then
            fuelLevel = DecorGetFloat(vehicle, "vehicle_fuel") or 32
        end

        return {
            windows = windows,
            tyres = tyres,
            doors = doors,

            bodyHealth = GetVehicleBodyHealth(vehicle),
            engineHealth = GetVehicleEngineHealth(vehicle),
            tankHealth = GetVehiclePetrolTankHealth(vehicle),

            fuelLevel = fuelLevel,
            dirtLevel = GetVehicleDirtLevel(vehicle),

            modNitro = nitroAmount
        }
    else
        return
    end
end