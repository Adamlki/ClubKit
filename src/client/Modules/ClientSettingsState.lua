local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClientState"))

local ClientSettingsState = {}

function ClientSettingsState.isDonationEffectsHidden(): boolean
	return ClientState.isDonationEffectsHidden()
end

function ClientSettingsState.isDonationNotifHidden(): boolean
	return ClientState.isDonationNotifHidden()
end

function ClientSettingsState.isAdminNotifHidden(): boolean
	return ClientState.isAdminNotifHidden()
end

function ClientSettingsState.setDonationEffectsHidden(value: boolean)
	return ClientState.setDonationEffectsHidden(value)
end

function ClientSettingsState.setDonationNotifHidden(value: boolean)
	return ClientState.setDonationNotifHidden(value)
end

function ClientSettingsState.setAdminNotifHidden(value: boolean)
	return ClientState.setAdminNotifHidden(value)
end

function ClientSettingsState.onChanged(callback: (key: string, value: boolean) -> ())
	ClientState.onChanged(callback)
end

return ClientSettingsState
