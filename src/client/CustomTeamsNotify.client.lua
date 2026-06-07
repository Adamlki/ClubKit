local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local folder = ReplicatedStorage:WaitForChild("CustomTeamsRemotes", 10)
if not folder then return end

local notifyRemote = folder:WaitForChild("Notify", 10)
if not notifyRemote then return end

notifyRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end

	local attempts = 0
	local success  = false

	while not success and attempts < 5 do
		attempts = attempts + 1
		local ok = pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title    = data.Title    or "Team System",
				Text     = data.Text     or "",
				Duration = data.Duration or 5,
			})
		end)
		if ok then
			success = true
		else
			task.wait(0.2)
		end
	end
end)