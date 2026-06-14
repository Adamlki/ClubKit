local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local FireSmite = RS:FindFirstChild("FireSmite")
if not FireSmite then
	FireSmite = Instance.new("RemoteEvent")
	FireSmite.Name = "FireSmite"
	FireSmite.Parent = RS
end

local SaweriaEffectEvent = ServerStorage:WaitForChild("SaweriaEffectEvent")

-- 🔥 ARCHITECT FIX: CACHE SYSTEM & ANTREAN SMITE
local userIdCache = {} 
local effectQueue = {}
local isPlayingEffect = false

local function processQueue()
	if isPlayingEffect then return end
	isPlayingEffect = true
	while #effectQueue > 0 do
		local data = table.remove(effectQueue, 1)
		FireSmite:FireAllClients(data.donorName, "SAWERIA", data.amount, data.userId)
		task.wait(4) -- JEDA 4 DETIK AGAR PETIR TIDAK NUMPUK!
	end
	isPlayingEffect = false
end

SaweriaEffectEvent.Event:Connect(function(donorData, amount)
	if amount >= 50000 and amount <= 199999 then
		local donorName = tostring(donorData or "Anonymous")
		local userId = 156

		if userIdCache[donorName] then
			userId = userIdCache[donorName]
		else
			local success, id = pcall(function() return Players:GetUserIdFromNameAsync(donorName) end)
			if success and id then 
				userId = id 
				userIdCache[donorName] = id 
			end
		end

		-- Masukkan ke antrean, JANGAN LANGSUNG DITEMBAK!
		table.insert(effectQueue, {donorName = donorName, amount = amount, userId = userId})
		processQueue()
	end
end)