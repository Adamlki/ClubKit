--!optimize 2

local ClientState = {}

local flags = {
	HideDonationEffects = false,
	HideAdminNotif = false,
	HideDonationNotif = false,
	ActiveDonationNotification = false,
}

local listeners = {}
local actions = {}

local function notifyChanged(key, value)
	for _, listener in ipairs(listeners) do
		task.spawn(listener, key, value)
	end
end

function ClientState.getFlag(key)
	return flags[key] == true
end

function ClientState.setFlag(key, value)
	if flags[key] == nil then
		return false, "flag tidak dikenal: " .. tostring(key)
	end
	flags[key] = value == true
	notifyChanged(key, flags[key])
	return true
end

function ClientState.isDonationEffectsHidden()
	return flags.HideDonationEffects
end

function ClientState.isDonationNotifHidden()
	return flags.HideDonationNotif
end

function ClientState.isAdminNotifHidden()
	return flags.HideAdminNotif
end

function ClientState.setDonationEffectsHidden(value)
	return ClientState.setFlag("HideDonationEffects", value)
end

function ClientState.setDonationNotifHidden(value)
	return ClientState.setFlag("HideDonationNotif", value)
end

function ClientState.setAdminNotifHidden(value)
	return ClientState.setFlag("HideAdminNotif", value)
end

function ClientState.isDonationNotificationActive()
	return flags.ActiveDonationNotification == true
end

function ClientState.setDonationNotificationActive(value)
	return ClientState.setFlag("ActiveDonationNotification", value)
end

function ClientState.clearDonationNotificationActive()
	return ClientState.setFlag("ActiveDonationNotification", false)
end

function ClientState.onChanged(callback)
	if type(callback) == "function" then
		table.insert(listeners, callback)
	end
end

function ClientState.registerAction(name, callback)
	if type(name) ~= "string" or name == "" or type(callback) ~= "function" then
		return false, "action tidak valid"
	end
	actions[name] = callback
	return true
end

function ClientState.hasAction(name)
	return actions[name] ~= nil
end

function ClientState.callAction(name, ...)
	local callback = actions[name]
	if not callback then
		return false, "action belum terdaftar: " .. tostring(name)
	end

	local ok, result = pcall(callback, ...)
	if not ok then
		warn("[ClientState] action " .. tostring(name) .. " error: " .. tostring(result))
		return false, result
	end
	return true, result
end

return ClientState
