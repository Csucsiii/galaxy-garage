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