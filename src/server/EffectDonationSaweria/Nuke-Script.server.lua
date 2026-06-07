local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FireNuke = RS:FindFirstChild("FireNuke")
if not FireNuke then
	FireNuke = Instance.new("RemoteEvent")
	FireNuke.Name = "FireNuke"
	FireNuke.Parent = RS
end

local defaultRecipient = "SAWERIA" 
local SaweriaEffectEvent = ServerStorage:WaitForChild("SaweriaEffectEvent")

-- 🔥 ARCHITECT FIX: ANTREAN EFEK
local effectQueue = {}
local isPlayingEffect = false

local function processQueue()
	if isPlayingEffect then return end
	isPlayingEffect = true

	while #effectQueue > 0 do
		local data = table.remove(effectQueue, 1)
		FireNuke:FireAllClients(data.donorName, data.recipient, data.amount, 0)

		-- Jeda 5 DETIK sebelum Nuke selanjutnya boleh dijatuhkan!
		task.wait(5) 
	end

	isPlayingEffect = false
end

SaweriaEffectEvent.Event:Connect(function(donorName, amount)
	if amount >= 10000 and amount <= 49999 then
		-- Masukkan ke antrean, jangan langsung ditembak!
		table.insert(effectQueue, {donorName = donorName, recipient = defaultRecipient, amount = amount})
		processQueue()
	end
end)