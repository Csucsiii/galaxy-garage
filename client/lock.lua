---@diagnostic disable: undefined-global
local anim = {
    dict = "anim@mp_player_intmenu@key_fob@",
    name = "fob_click_fp"
}

local cooldown = 0

RegisterKeyMapping("+openVehicle", "Ajtó zár", "keyboard", "g")

RegisterCommand("+openVehicle", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle, distance = GetClosestVehicle(coords)

    print(vehicle, distance)
    print(DoesEntityExist(vehicle))
    if (not DoesEntityExist(vehicle)) then return end
    if (distance > 8.0) then return end

    local plate = GetVehicleNumberPlate(vehicle)
    print(cooldown ~= 0 and GetNetworkTime() - cooldown < 250)
    if (cooldown ~= 0 and GetNetworkTime() - cooldown < 250) then return end

    Callback.TriggerServerCallback("galaxy-garage:doesPlayerOwnVehicle", function(status)
        print("status", status)
        if (not status) then return end

        RequestAnimDict(anim.dict)
        while (not HasAnimDictLoaded(anim.dict)) do
            Wait(100)
        end

        TaskPlayAnim(ped, anim.dict, anim.name, 8.0, 8.0, GetAnimDuration(anim.dict, anim.name) * 1000, 48, 1, false, false, false)
        cooldown = GetNetworkTime()

        local doorStatus = GetVehicleDoorLockStatus(vehicle)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if (doorStatus > 1) then
            exports["notification"]:createNotification({
                type = "unlock",
                text = string.format("%s kinyitva", plate),
                duration = 5
            })

            TriggerServerEvent("galaxy-garage:vehicleDoorlockSync", netId, true)
        else
            exports["notification"]:createNotification({
                type = "lock",
                text = string.format("%s bezárva", plate),
                duration = 5
            })

            TriggerServerEvent("galaxy-garage:vehicleDoorlockSync", netId, false)
        end
    end, plate)
end)

RegisterNetEvent("galaxy-garage:vehicleDoorlockSync")
AddEventHandler("galaxy-garage:vehicleDoorlockSync", function(netId, status)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if (GetEntityType(entity) ~= 2) then return end

    SetVehicleDoorsLocked(entity, status and 1 or 2)
end)