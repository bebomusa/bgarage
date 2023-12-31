if GetResourceState("ox_core") ~= "started" then return end

assert(load(LoadResourceFile("ox_core", "imports/client.lua"), "@@ox_core/imports/client.lua"))()

SetVehicleProperties = lib.setVehicleProperties
GetVehicleProperties = lib.getVehicleProperties

---@return boolean
function CheckImpoundJob()
	local data = Ox.GetPlayerData()
	if not data then return false end

	for i = 1, #ImpoundJobs do
		if data.groups[ImpoundJobs[i]] then
			return true
		end
	end

	return false
end

---@return string
function GetEmergencyJob()
	local data = Ox.GetPlayerData()
	if not data then return "none" end

	for i = 1, #EmergencyJobs do
		if data.groups[EmergencyJobs[i]] then
			return EmergencyJobs[i]
		end
	end

	return "none"
end

---@param message string
---@param type "error" | "info" | "success"
function ShowNotification(message, icon, type)
	return lib.notify({
		title = locale("notification_title"),
		duration = NotificationDuration,
		description = message,
		position = NotificationPosition,
		icon = icon,
		iconColor = NotificationIconColors[type] or "#ffffff",
	})
end