local inRadialMenu = false
local isDead = false
local jobIndex = nil
local vehicleIndex = nil
local DynamicMenuItems = {}
local FinalMenuItems = {}
-- Functions

local function Notificationn(message, typee)
	lib.notify({
		title = message,
		type = typee
	})
end

local function deepcopy(orig) -- modified the deep copy function from http://lua-users.org/wiki/CopyTable
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if not orig.canOpen or orig.canOpen() then
            local toRemove = {}
            copy = {}
            for orig_key, orig_value in next, orig, nil do
                if type(orig_value) == 'table' then
                    if not orig_value.canOpen or orig_value.canOpen() then
                        copy[deepcopy(orig_key)] = deepcopy(orig_value)
                    else
                        toRemove[orig_key] = true
                    end
                else
                    copy[deepcopy(orig_key)] = deepcopy(orig_value)
                end
            end
            for i=1, #toRemove do table.remove(copy, i) --[[ Using this to make sure all indexes get re-indexed and no empty spaces are in the radialmenu ]] end
            if copy and next(copy) then setmetatable(copy, deepcopy(getmetatable(orig))) end
        end
    elseif orig_type ~= 'function' then
        copy = orig
    end
    return copy
end

local function getNearestVeh()
    local pos = GetEntityCoords(cache.ped)
    local entityWorld = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 20.0, 0.0)
    local rayHandle = CastRayPointToPoint(pos.x, pos.y, pos.z, entityWorld.x, entityWorld.y, entityWorld.z, 10, cache.ped, 0)
    local _, _, _, _, vehicleHandle = GetRaycastResult(rayHandle)
    return vehicleHandle
end

local function AddOption(data, id)
    local menuID = id ~= nil and id or (#DynamicMenuItems + 1)
    DynamicMenuItems[menuID] = deepcopy(data)
    return menuID
end

local function RemoveOption(id)
    DynamicMenuItems[id] = nil
end

local function SetupJobMenu()
    local JobMenu = {
        id = 'jobinteractions',
        title = 'Work',
        icon = 'briefcase',
        items = {}
    }
    if Config.JobInteractions[ESX.PlayerData.job.name] and next(Config.JobInteractions[ESX.PlayerData.job.name]) then
        JobMenu.items = Config.JobInteractions[ESX.PlayerData.job.name]
    end

    if #JobMenu.items == 0 then
        if jobIndex then
            RemoveOption(jobIndex)
            jobIndex = nil
        end
    else
        jobIndex = AddOption(JobMenu, jobIndex)
    end
end

local function SetupVehicleMenu()
    local VehicleMenu = {
        id = 'vehicle',
        title = 'Vehicle',
        icon = 'car',
        items = {}
    }

    local ped = cache.ped
    local Vehicle = GetVehiclePedIsIn(ped) ~= 0 and GetVehiclePedIsIn(ped) or getNearestVeh()
    if Vehicle ~= 0 then
        VehicleMenu.items[#VehicleMenu.items+1] = Config.VehicleDoors
        if Config.EnableExtraMenu then VehicleMenu.items[#VehicleMenu.items+1] = Config.VehicleExtras end

        if IsPedInAnyVehicle(ped) then
            local seatIndex = #VehicleMenu.items+1
            VehicleMenu.items[seatIndex] = deepcopy(Config.VehicleSeats)

            local seatTable = {
                [1] = _U('driver_seat'),
                [2] = _U('passenger_seat'),
                [3] = _U('rear_left_seat'),
                [4] = _U('rear_right_seat'),
            }

            local AmountOfSeats = GetVehicleModelNumberOfSeats(GetEntityModel(Vehicle))
            for i = 1, AmountOfSeats do
                local newIndex = #VehicleMenu.items[seatIndex].items+1
                VehicleMenu.items[seatIndex].items[newIndex] = {
                    id = i - 2,
                    title = seatTable[i] or _U('other_seats'),
                    icon = 'caret-up',
                    type = 'client',
                    event = 'qb-radialmenu:client:ChangeSeat',
                    shouldClose = false,
                }
            end
        end
    end

    if #VehicleMenu.items == 0 then
        if vehicleIndex then
            RemoveOption(vehicleIndex)
            vehicleIndex = nil
        end
    else
        vehicleIndex = AddOption(VehicleMenu, vehicleIndex)
    end
end

local function SetupSubItems()
    SetupJobMenu()
    SetupVehicleMenu()
end

local function selectOption(t, t2)
    for _, v in pairs(t) do
        if v.items then
            local found, hasAction, val = selectOption(v.items, t2)
            if found then return true, hasAction, val end
        else
            if v.id == t2.id and ((v.event and v.event == t2.event) or v.action) and (not v.canOpen or v.canOpen()) then
                return true, v.action, v
            end
        end
    end
    return false
end

local function IsPoliceOrEMS()
    return (ESX.PlayerData.job.name == 'police' or ESX.PlayerData.job.name == 'ambulance')
end

RegisterNetEvent('esx_ambulancejob:revive', function()  ---CHANGE HERE WITH YOUR TRIGGER REVIVE
    isDead = false
end)

AddEventHandler('esx:onPlayerDeath', function()
	isDead = true
end)

local function IsDowned()
    return isDead
end

local function SetupRadialMenu()
    FinalMenuItems = {}
    if (IsDowned() and IsPoliceOrEMS()) then
        FinalMenuItems = {
            [1] = {
                id = 'emergencybutton1',
                title = '10-13A - Officer Down',
                icon = 'sad-tear',
                type = 'client',
                event = 'ps-dispatch:client:officerdown', -- replace with your event
                shouldClose = true,
            },
            [2] = {
                id = 'emergencybutton2',
                title = '10-13B - EMS Down',
                icon = 'sad-cry',
                type = 'client',
                event = 'ps-dispatch:client:emsdown', -- replace with your event
                shouldClose = true,
            },
        }
    else
        SetupSubItems()
        FinalMenuItems = deepcopy(Config.MenuItems)
        for _, v in pairs(DynamicMenuItems) do
            FinalMenuItems[#FinalMenuItems+1] = v
        end

    end
end

local function setRadialState(bool, sendMessage, delay)
    -- Menuitems have to be added only once

    if bool then
        TriggerEvent('qb-radialmenu:client:onRadialmenuOpen')
        SetupRadialMenu()
    else
        TriggerEvent('qb-radialmenu:client:onRadialmenuClose')
    end

    SetNuiFocus(bool, bool)
    if sendMessage then
        SendNUIMessage({
            action = "ui",
            radial = bool,
            items = FinalMenuItems
        })
    end
    if delay then Wait(500) end
    inRadialMenu = bool
end

-- Command

RegisterCommand('radialmenu', function()
    if ((IsDowned() and IsPoliceOrEMS()) or not IsDowned()) and not IsPedCuffed(cache.ped) and not IsPauseMenuActive() and not inRadialMenu then
        setRadialState(true, true)
        SetCursorLocation(0.5, 0.5)
    end
end)

RegisterKeyMapping('radialmenu', _U('command_description'), 'keyboard', 'F1')

RegisterNetEvent('qb-radialmenu:client:openDoor', function(data)
    local string = data.id
    local replace = string:gsub("door", "")
    local door = tonumber(replace)
    local closestVehicle = GetVehiclePedIsIn(cache.ped) ~= 0 and GetVehiclePedIsIn(cache.ped) or getNearestVeh()
    if closestVehicle ~= 0 then
        if closestVehicle ~= GetVehiclePedIsIn(cache.ped) then
            local plate = GetVehicleNumberPlateText(closestVehicle)
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', false, plate, door)
                else
                    SetVehicleDoorShut(closestVehicle, door, false)
                end
            else
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', true, plate, door)
                else
                    SetVehicleDoorOpen(closestVehicle, door, false, false)
                end
            end
        else
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                SetVehicleDoorShut(closestVehicle, door, false)
            else
                SetVehicleDoorOpen(closestVehicle, door, false, false)
            end
        end
    else
        Notificationn(Config.Notif['no_vehicle_found'], 'error')
    end
end)

RegisterNetEvent('qb-radialmenu:client:setExtra', function(data)
    local string = data.id
    local replace = string:gsub("extra", "")
    local extra = tonumber(replace)
    local veh = GetVehiclePedIsIn(cache.ped)
    if veh ~= nil then
        if GetPedInVehicleSeat(veh, -1) == cache.ped then
            SetVehicleAutoRepairDisabled(veh, true) -- Forces Auto Repair off when Toggling Extra [GTA 5 Niche Issue]
            if DoesExtraExist(veh, extra) then
                if IsVehicleExtraTurnedOn(veh, extra) then
                    SetVehicleExtra(veh, extra, 1)
                    Notificationn(_U('extra_deactivated', {extra = extra}), 'error')
                else
                    SetVehicleExtra(veh, extra, 0)
                    Notificationn(_U('extra_activated', {extra = extra}), 'success')
                end
            else
                Notificationn(_U('extra_not_present', {extra = extra}), 'error')
            end
        else
            Notificationn(_U('not_driver'), 'error')
        end
    end
end)

RegisterNetEvent('qb-radialmenu:trunk:client:Door', function(plate, door, open)
    local veh = GetVehiclePedIsIn(cache.ped)
    if veh ~= 0 then
        local pl = GetVehicleNumberPlateText(veh)
        if pl == plate then
            if open then
                SetVehicleDoorOpen(veh, door, false, false)
            else
                SetVehicleDoorShut(veh, door, false)
            end
        end
    end
end)

RegisterNetEvent('qb-radialmenu:client:ChangeSeat', function(data)
    local Veh = GetVehiclePedIsIn(cache.ped)
    local IsSeatFree = IsVehicleSeatFree(Veh, data.id)
    local speed = GetEntitySpeed(Veh)
        local kmh = speed * 3.6
        if IsSeatFree then
            if kmh <= 100.0 then
                SetPedIntoVehicle(cache.ped, Veh, data.id)
            else
                Notificationn(_U('vehicle_driving_fast'), 'error')
            end
        else
            Notificationn(_U('seat_occupied'), 'error')
        end
end)

-- NUI Callbacks

RegisterNUICallback('closeRadial', function(data, cb)
    setRadialState(false, false, data.delay)
    cb('ok')
end)

RegisterNUICallback('selectItem', function(inData, cb)
    local itemData = inData.itemData
    local found, action, data = selectOption(FinalMenuItems, itemData)
    if data and found then
        if action then
            action(data)
        elseif data.type == 'client' then
            TriggerEvent(data.event, data)
        elseif data.type == 'server' then
            TriggerServerEvent(data.event, data)
        elseif data.type == 'command' then
            ExecuteCommand(data.event)
        end
    end
    cb('ok')
end)

exports('AddOption', AddOption)
exports('RemoveOption', RemoveOption)
