--#region Variables

local client = lib.load("config.client")
local shared = lib.load("config.shared")
local class = require "client.class.static"
local framework = require(("client.framework.%s"):format(shared.framework))
local capitalizeFirst = require "client.utils.capitalizeFirst"
local createBlip = require "client.utils.createBlip"
local getState = require "client.utils.getState"
local registerEvent = require "client.utils.registerEvent"

local tempVehicle
local hasStarted = false
local impoundBlip = 0
local static = nil

--#endregion Variables

--#region Functions

---@param model? string | number
---@param type? string
---@return string | nil
local function getVehicleIcon(model, type)
    if not model and not type then return end

    local icon = type or client.vehicleClasses[GetVehicleClassFromName(model --[[@as string | number]])]
    icon = client.convertIcons[icon] or icon

    return icon
end

---@param plate string
---@param data Vehicle
---@param coords vector4
---@return boolean
---@return string
local function spawnVehicle(plate, data, coords)
    plate = plate and plate:upper() or plate

    if tempVehicle then
        if tempVehicle ~= plate then
            while tempVehicle do
                Wait(100)
            end
        else
            return false, locale("already_spawning")
        end
    end

    tempVehicle = plate
    lib.requestModel(data.model)

    local netVehicle = lib.callback.await("bGarage:server:spawnVehicle", false, data.model, type(coords) == "vector4" and coords, plate)
    if not netVehicle then
        TriggerServerEvent("bGarage:server:vehicleSpawnFailed", plate)
        tempVehicle = nil
        return false, locale("not_registered")
    end

    local attempts = 0
    while netVehicle == 0 or not NetworkDoesEntityExistWithNetworkId(netVehicle) do
        Wait(10)
        attempts += 1
        if attempts == 100 then
            break
        end
    end

    local vehicle = netVehicle == 0 and 0 or not NetworkDoesEntityExistWithNetworkId(netVehicle) and 0 or NetToVeh(netVehicle)
    local state = getState(vehicle)
    if not vehicle or vehicle == 0 then
        TriggerServerEvent("bGarage:server:vehicleSpawnFailed", plate, netVehicle)
        tempVehicle = nil
        return false, locale("failed_to_spawn")
    end

    Wait(500) -- Wait for the server to completely register the vehicle

    state:set("cacheVehicle", true, true)
    state:set("vehicleProperties", data.props, true)
    SetVehicleProperties(vehicle, data.props)

    tempVehicle = nil

    return true, locale("successfully_spawned")
end

--#endregion Functions

--#region Callbacks

lib.callback.register("bGarage:client:getTempVehicle", function()
    return tempVehicle
end)

lib.callback.register("bGarage:client:startedCheck", function()
    if GetInvokingResource() then return end
    hasStarted = true
end)

--#endregion Callbacks

--#region Events

registerEvent("bGarage:client:openVehicleList", function()
    if not hasStarted then return end

    ---@type table<string, Vehicle>
    local vehicles, amount = lib.callback.await("bGarage:server:getOwnedVehicles", false)
    if amount == 0 then
        framework.Notify(locale("no_vehicles"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
        return
    end

    ---@type vector4?
    local location = lib.callback.await("bGarage:server:getParkingSpot", false)

    local options = {
        {
            title = locale("vehicle_amount"):format(amount),
            disabled = true,
        },
    }

    for k, v in pairs(vehicles) do
        local vehicleListOptions = {}

        if v.location == "parked" then
            vehicleListOptions[#vehicleListOptions + 1] = {
                title = locale("menu_subtitle_one"),
                description = locale("menu_description_one"),
                onSelect = function(price)
                    local canPay, reason = lib.callback.await("bGarage:server:payFee", price, shared.garage.retrieve.price, false)
                    if not canPay then
                        framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[0])
                        return
                    end

                    if not location then
                        framework.Notify(locale("no_parking_spot"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
                        return
                    end

                    local success, status = spawnVehicle(k, v, location)
                    framework.Notify(status, shared.notifications.duration, shared.notifications.position, "success", shared.notifications.icons[0])

                    if not success then return end

                    lib.callback.await("bGarage:server:payFee", price, shared.garage.retrieve.price, true)
                end,
            }
        end

        if v.location == "parked" or v.location == "outside" and not cache.vehicle then
            vehicleListOptions[#vehicleListOptions + 1] = {
                title = locale("menu_subtitle_two"),
                description = locale("menu_description_two"),
                onSelect = function()
                    local coords = v.location == "parked" and location?.xy or v.location == "outside" and lib.callback.await("bGarage:server:getVehicleCoords", false, k)?.xy or nil
                    if not coords then
                        framework.Notify(v.location == "outside" and locale("vehicle_doesnt_exist") or locale("no_parking_spot"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[0] or shared.notifications.icons[1])
                        return
                    end

                    if coords then
                        SetNewWaypoint(coords.x, coords.y)
                        framework.Notify(locale("set_waypoint"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
                        return
                    end
                end,
            }
        end

        local make, name = capitalizeFirst(GetMakeNameFromVehicleModel(v.model)), capitalizeFirst(GetDisplayNameFromVehicleModel(v.model))
        options[#options + 1] = {
            menu = table.type(vehicleListOptions) ~= "empty" and v.location ~= "impound" and ("vehicleList_%s"):format(k) or nil,
            title = ("%s %s (%s)"):format(make, name, k),
            description = ("%s"):format(capitalizeFirst(v.location)),
            icon = getVehicleIcon(v.model, v.type),
            iconColor = v.location == "impound" and "#7f1d1d" or v.location == "parked" and "#14532d" or "#ffa94d",
            metadata = {
                Body = ("%s"):format(v.body),
                Engine = ("%s"):format(v.engine),
                Fuel = ("%s"):format(v.fuel),
            },
        }

        if table.type(vehicleListOptions) ~= "empty" then
            lib.registerContext({
                id = ("vehicleList_%s"):format(k),
                menu = "vehicleList_menu",
                title = ("%s %s - %s"):format(make, name, k),
                options = vehicleListOptions,
            })
        end
    end

    lib.registerContext({
        id = "vehicleList_menu",
        title = locale("vehicle_menu_title"),
        options = options,
    })

    framework.hideTextUI()
    framework.showContext("vehicleList_menu")
end)

RegisterNetEvent("bGarage:client:openImpoundList", function()
    if not hasStarted then return end

    ---@type table<string, Vehicle>, number
    local vehicles, amount = lib.callback.await("bGarage:server:getImpoundedVehicles", false)
    if amount == 0 then
        framework.Notify(locale("no_impounded_vehicles"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
        return
    end

    local options = {
        {
            title = locale("vehicle_amount"):format(amount),
            disabled = true,
        },
    }

    for k, v in pairs(vehicles) do
        local make, name = capitalizeFirst(GetMakeNameFromVehicleModel(v.model)), capitalizeFirst(GetDisplayNameFromVehicleModel(v.model))
        options[#options + 1] = {
            menu = ("vehicleImpound_%s"):format(k),
            title = ("%s %s (%s)"):format(make, name, k),
            description = ("%s"):format(capitalizeFirst(v.location)),
            icon = getVehicleIcon(v.model, v.type),
            iconColor = v.location == "impound" and "#7f1d1d" or v.location == "parked" and "#14532d" or "#ffa94d",
            metadata = {
                Body = ("%s"):format(v.body),
                Engine = ("%s"):format(v.engine),
                Fuel = ("%s"):format(v.fuel),
            },
        }

        lib.registerContext({
            id = ("vehicleImpound_%s"):format(k),
            menu = "vehicleImpound_menu",
            title = ("%s %s - %s"):format(make, name, k),
            options = {
                {
                    title = locale("menu_subtitle_one"),
                    description = locale("impound_description"),
                    onSelect = function(price)
                        if shared.impound.static then
                            local canPay, reason = lib.callback.await("bGarage:server:payFee", price, shared.impound.price, false)
                            if not canPay then
                                framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[1])
                                return
                            end

                            local success, status = spawnVehicle(k, v, shared.impound.location)
                            framework.Notify(status, shared.notifications.duration, shared.notifications.position, "success", shared.notifications.icons[1])

                            if not success then return end

                            lib.callback.await("bGarage:server:payFee", price, shared.impound.price, true)
                        else
                            local canPay, reason = lib.callback.await("bGarage:server:payFee", price, shared.impound.price, false)
                            if not canPay then
                                framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[1])
                                return
                            end

                            ---@type vector4?
                            local location = lib.callback.await("bGarage:server:getParkingSpot", false)
                            if not location then
                                framework.Notify(locale("no_parking_spot"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
                                return
                            end

                            local success, status = spawnVehicle(k, v, location)
                            framework.Notify(status, shared.notifications.duration, shared.notifications.position, "success", shared.notifications.icons[1])

                            if not success then return end

                            lib.callback.await("bGarage:server:payFee", price, shared.impound.price, true)
                        end
                    end,
                },
            },
        })
    end

    lib.registerContext({
        id = "vehicleImpound_menu",
        title = locale("impounded_menu_title"),
        options = options,
    })

    framework.hideTextUI()
    framework.showContext("vehicleImpound_menu")
end)

if shared.impound.static and not static then
    class:generatePoint()
    class:generateInteraction()
end

---@param price number
registerEvent("bGarage:client:purchaseParkingSpace", function(price)
    if not hasStarted then return end

    local canPay, reason = lib.callback.await("bGarage:server:payFee", price, shared.garage.parking.price, false)
    if not canPay then
        framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[1])
        return
    end

    local entity = cache.vehicle or cache.ped
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)

    local location, status = lib.callback.await("bGarage:server:setParkingSpot", false, vec4(coords.x, coords.y, coords.z, heading))
    framework.Notify(status, shared.notifications.duration, shared.notifications.position, "success", shared.notifications.icons[1])

    if not location then return end

    lib.callback.await("bGarage:server:payFee", price, shared.garage.parking.price, true)
end)

registerEvent("bGarage:client:storeVehicle", function()
    if not hasStarted then return end

    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        framework.Notify(locale("not_in_vehicle"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[0])
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    ---@type Vehicle?
    local owner = lib.callback.await("bGarage:server:getVehicleOwner", false, plate)
    if not owner then
        framework.Notify(locale("not_owner"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[0])
        return
    end

    ---@type vector4?
    local location = lib.callback.await("bGarage:server:getParkingSpot", false)
    if not location then
        framework.Notify(locale("no_parking_spot"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
        return
    end

    if #(location.xyz - GetEntityCoords(vehicle)) > 5.0 then
        SetNewWaypoint(location.x, location.y)
        framework.Notify(locale("not_in_parking_spot"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
        return
    end

    local props = GetVehicleProperties(vehicle)
    local fuel = GetVehicleFuelLevel(vehicle)
    local body = math.ceil(GetVehicleBodyHealth(vehicle))
    local engine = math.ceil(GetVehicleEngineHealth(vehicle))

    ---@type boolean, string
    local status, reason = lib.callback.await("bGarage:server:setVehicleStatus", false, "parked", plate, props, fuel, body, engine)
    if status then
        SetEntityAsMissionEntity(vehicle, false, false)
        lib.callback.await("bGarage:server:deleteVehicle", false, VehToNet(vehicle))
        framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "success", shared.notifications.icons[0])
    end

    if not status then
        framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[0])
        return
    end
end)

RegisterNetEvent("bGarage:client:impoundVehicle", function()
    if not hasStarted then return end

    local job = framework.hasJob()
    if not job then
        framework.Notify(locale("no_access"), shared.notifications.duration, shared.notifications.position, "error", shared.notifications.icons[1])
        return
    end

    local vehicle = GetVehiclePedIsIn(cache.ped, false) --[[@as number?]]
    if not vehicle or vehicle == 0 then
        vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, true)
        if not vehicle or vehicle == 0 then
            framework.Notify(locale("no_nearby_vehicles"), shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[1])
            return
        end
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local data = lib.callback.await("bGarage:server:getVehicle", false, plate) --[[@as Vehicle?]]
    if data then
        ---@type boolean, string
        local _, reason = lib.callback.await("bGarage:server:setVehicleStatus", false, "impound", plate, data.props, data.owner)
        framework.Notify(reason, shared.notifications.duration, shared.notifications.position, "inform", shared.notifications.icons[3])
    end

    SetEntityAsMissionEntity(vehicle, false, false)
    lib.callback.await("bGarage:server:deleteVehicle", false, VehToNet(vehicle))
end)

if GetResourceState("ox_target"):find("start") then
    exports.ox_target:addGlobalVehicle({
        {
            label = locale("impound_vehicle"),
            name = "impound_vehicle",
            icon = "fa-solid fa-car-burst",
            distance = 2.5,
            groups = client.jobs,
            event = "bGarage:client:impoundVehicle",
        },
    })
end

--#endregion Events

--#region Threads

CreateThread(function()
    Wait(1000)
    if hasStarted then return end
    hasStarted = lib.callback.await("bGarage:server:hasStarted", false)
end)

if shared.impound.static then
    CreateThread(function()
        local settings = { id = shared.impound.blip.sprite, colour = shared.impound.blip.color, scale = shared.impound.blip.scale }
        impoundBlip = createBlip(settings, shared.impound.location)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(locale("impound_blip"))
        EndTextCommandSetBlipName(impoundBlip)
    end)
end

CreateThread(function()
    static = class:new({
        private = {
            static = shared.impound.static
        },
    })
end)

--#endregion Threads

SetDefaultVehicleNumberPlateTextPattern(-1, shared.miscellaneous.plateTextPattern:upper())
