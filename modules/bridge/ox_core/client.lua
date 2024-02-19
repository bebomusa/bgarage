local resourceName = "ox_core"

if not GetResourceState(resourceName):find("start") then return end

CreateThread(function() lib.load("@ox_core.imports.client") end)

SetVehicleProperties = lib.setVehicleProperties
GetVehicleProperties = lib.getVehicleProperties

local ox = {}

---@return boolean
function ox.HasJob()
    local data = Ox.GetPlayerData()
    if not data then return false end

    for i = 1, #Jobs do
        if data.groups[Jobs[i]] then
            return true
        end
    end

    return false
end

---@param message string
---@param duration? integer
---@param position? string
---@param _type? string
---@param icon? string
---@param iconColor? string
function ox.Notify(message, duration, position, _type, icon, iconColor)
    return lib.notify({
        title = locale("notification_title"),
        description = message,
        duration = duration,
        position = position,
        type = _type,
        icon = icon,
        iconColor = iconColor,
    })
end

---@param text string
function ox.ShowTextUI(text)
    lib.showTextUI(text)
end

function ox.HideTextUI()
    lib.hideTextUI()
end

return ox