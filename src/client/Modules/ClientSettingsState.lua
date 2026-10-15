--!strict
-- ============================================================
-- ClientSettingsState (Client Module)
-- Centralized reactive state for client settings & toggles
-- Maintains 100% backwards compatibility with _G flags
-- ============================================================

local ClientSettingsState = {}

local state = {
	HideDonationEffects = false,
	HideAdminNotif = false,
	HideDonationNotif = false,
}

local changeListeners: { (key: string, value: boolean) -> () } = {}

-- Sinkronisasi awal ke _G untuk kompatibilitas skrip legacy
_G.HideDonationEffects = false
_G.IsDonationEffectsHidden = function()
	return state.HideDonationEffects == true
end

_G.HideAdminNotif = false

_G.HideDonationNotif = false
_G.IsDonationNotifHidden = function()
	return state.HideDonationNotif == true
end

local function notifyChanged(key: string, value: boolean)
	for _, listener in ipairs(changeListeners) do
		task.spawn(listener, key, value)
	end
end

function ClientSettingsState.isDonationEffectsHidden(): boolean
	return state.HideDonationEffects == true or _G.HideDonationEffects == true
end

function ClientSettingsState.isDonationNotifHidden(): boolean
	return state.HideDonationNotif == true or _G.HideDonationNotif == true
end

function ClientSettingsState.isAdminNotifHidden(): boolean
	return state.HideAdminNotif == true or _G.HideAdminNotif == true
end

function ClientSettingsState.setDonationEffectsHidden(value: boolean)
	state.HideDonationEffects = value
	_G.HideDonationEffects = value
	notifyChanged("HideDonationEffects", value)
end

function ClientSettingsState.setDonationNotifHidden(value: boolean)
	state.HideDonationNotif = value
	_G.HideDonationNotif = value
	notifyChanged("HideDonationNotif", value)
end

function ClientSettingsState.setAdminNotifHidden(value: boolean)
	state.HideAdminNotif = value
	_G.HideAdminNotif = value
	notifyChanged("HideAdminNotif", value)
end

function ClientSettingsState.onChanged(callback: (key: string, value: boolean) -> ())
	table.insert(changeListeners, callback)
end

return ClientSettingsState
