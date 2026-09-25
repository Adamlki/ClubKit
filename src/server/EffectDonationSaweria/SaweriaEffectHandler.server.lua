-- ==========================================
-- SAWERIA EFFECT HANDLER (SERVER)
-- Menghubungkan SaweriaEffectEvent ke Efek 3D
-- Mendukung EffectsEvent & Remote Legacy (FireSmite, FireNuke, FireBlackHole)
-- ==========================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local MegaEffectsConfig = require(script.Parent:WaitForChild("MegaEffectsConfig"))
_G.MegaEffectsConfig = MegaEffectsConfig

-- Remote Events (Baru & Lama untuk kompatibilitas penuh)
local effectsRemotes = ReplicatedStorage:FindFirstChild("EffectsRemotes")
if not effectsRemotes then
	effectsRemotes = Instance.new("Folder")
	effectsRemotes.Name = "EffectsRemotes"
	effectsRemotes.Parent = ReplicatedStorage
end

local effectsEvent = effectsRemotes:FindFirstChild("EffectsEvent")
if not effectsEvent then
	effectsEvent = Instance.new("RemoteEvent")
	effectsEvent.Name = "EffectsEvent"
	effectsEvent.Parent = effectsRemotes
end

local FireSmite = ReplicatedStorage:FindFirstChild("FireSmite")
local FireNuke = ReplicatedStorage:FindFirstChild("FireNuke")
local FireBlackHole = ReplicatedStorage:FindFirstChild("FireBlackHole")

-- Bindable Event dari DonasiSaweria
local SaweriaEffectEvent = ServerStorage:FindFirstChild("SaweriaEffectEvent")
if not SaweriaEffectEvent then
	SaweriaEffectEvent = Instance.new("BindableEvent")
	SaweriaEffectEvent.Name = "SaweriaEffectEvent"
	SaweriaEffectEvent.Parent = ServerStorage
end

-- Bindable Event dari Robux Donation (1k - 10k Robux)
local RobuxEffectEvent = ServerStorage:FindFirstChild("RobuxEffectEvent")
if not RobuxEffectEvent then
	RobuxEffectEvent = Instance.new("BindableEvent")
	RobuxEffectEvent.Name = "RobuxEffectEvent"
	RobuxEffectEvent.Parent = ServerStorage
end

-- Cache UserId (Bounded with eviction limit)
local userIdCache = {}
local cacheCount = 0
local MAX_CACHE_LIMIT = 100

-- Antrean Efek (FIFO Queue) dengan batas maksimal
local effectQueue = {}
local isPlayingEffect = false
local MAX_QUEUE_LIMIT = 20

local function getUserId(username)
	if userIdCache[username] then
		return userIdCache[username]
	end

	-- Cari pemain yang sedang online di server dulu
	local onlinePlayer = Players:FindFirstChild(username)
	if onlinePlayer then
		if cacheCount >= MAX_CACHE_LIMIT then
			table.clear(userIdCache)
			cacheCount = 0
		end
		userIdCache[username] = onlinePlayer.UserId
		cacheCount += 1
		return onlinePlayer.UserId
	end

	-- Ambil dari API Roblox
	local success, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(username)
	end)

	if cacheCount >= MAX_CACHE_LIMIT then
		table.clear(userIdCache)
		cacheCount = 0
	end

	if success and userId then
		userIdCache[username] = userId
		cacheCount += 1
		return userId
	end

	-- Fallback jika ID tidak ditemukan / nama anonim
	userIdCache[username] = 1
	cacheCount += 1
	return 1
end

-- ==========================================
-- TIER EFEK (DRIVEN BY MegaEffectsConfig)
-- ==========================================
local function getRobuxEffectTier(amount)
	if not MegaEffectsConfig.GLOBAL_ENABLED or not MegaEffectsConfig.ROBUX_ENABLED then
		return nil
	end

	local tiers = MegaEffectsConfig.ROBUX_TIERS
	local effects = MegaEffectsConfig.EFFECTS_ENABLED

	if tiers.Nuke and tiers.Nuke.Enabled and effects.Nuke then
		if amount >= tiers.Nuke.MinPrice and amount <= tiers.Nuke.MaxPrice then
			return "Nuke", tiers.Nuke.WaitTime or 10
		end
	end

	if tiers.Smite and tiers.Smite.Enabled and effects.Smite then
		if amount >= tiers.Smite.MinPrice and amount <= tiers.Smite.MaxPrice then
			return "Smite", tiers.Smite.WaitTime or 15
		end
	end

	if tiers.BlackHole and tiers.BlackHole.Enabled and effects.BlackHole then
		if amount >= tiers.BlackHole.MinPrice and amount <= tiers.BlackHole.MaxPrice then
			return "BlackHole", tiers.BlackHole.WaitTime or 20
		end
	end

	if tiers.Starfall and tiers.Starfall.Enabled and effects.Starfall then
		if amount >= tiers.Starfall.MinPrice and amount <= tiers.Starfall.MaxPrice then
			return "Starfall", tiers.Starfall.WaitTime or 25
		end
	end

	return nil
end

local function getEffectTier(amount)
	if not MegaEffectsConfig.GLOBAL_ENABLED or not MegaEffectsConfig.SAWERIA_ENABLED then
		return nil
	end

	local tiers = MegaEffectsConfig.SAWERIA_TIERS
	local effects = MegaEffectsConfig.EFFECTS_ENABLED

	if tiers.Nuke and tiers.Nuke.Enabled and effects.Nuke then
		if amount >= tiers.Nuke.MinPrice and amount <= tiers.Nuke.MaxPrice then
			return "Nuke", tiers.Nuke.WaitTime or 10
		end
	end

	if tiers.Smite and tiers.Smite.Enabled and effects.Smite then
		if amount >= tiers.Smite.MinPrice and amount <= tiers.Smite.MaxPrice then
			return "Smite", tiers.Smite.WaitTime or 15
		end
	end

	if tiers.BlackHole and tiers.BlackHole.Enabled and effects.BlackHole then
		if amount >= tiers.BlackHole.MinPrice and amount <= tiers.BlackHole.MaxPrice then
			return "BlackHole", tiers.BlackHole.WaitTime or 20
		end
	end

	if tiers.Starfall and tiers.Starfall.Enabled and effects.Starfall then
		if amount >= tiers.Starfall.MinPrice and amount <= tiers.Starfall.MaxPrice then
			return "Starfall", tiers.Starfall.WaitTime or 25
		end
	end

	return nil
end

local function processQueue()
	if isPlayingEffect then return end
	isPlayingEffect = true

	while #effectQueue > 0 do
		local data = table.remove(effectQueue, 1)
		local effectType, waitTime
		if data.currencyType == "Robux" then
			effectType, waitTime = getRobuxEffectTier(data.amount)
		else
			effectType, waitTime = getEffectTier(data.amount)
		end

		if effectType then
			local currency = data.currencyType or "Rupiah"
			local recipient = data.recipientName or (currency == "Robux" and "SERVER" or "SAWERIA")

			print(string.format("[SaweriaEffectHandler] 💥 Memutar Efek: %s | Donatur: %s (UserId: %d) | %s %d", 
				effectType, data.donorName, data.userId, currency, data.amount))

			-- 1. Tembak ke EffectsRemotes.EffectsEvent (Sistem Utama - 1x tembak agar tidak muncul dobel!)
			effectsEvent:FireAllClients(effectType, data.donorName, recipient, data.amount, data.userId, currency)

			task.wait(waitTime or 10)
		end
	end

	isPlayingEffect = false
end

-- Listener dari DonasiSaweria
SaweriaEffectEvent.Event:Connect(function(donorName, amount)
	donorName = tostring(donorName or "Anonymous")
	amount = tonumber(amount) or 0

	local effectType = getEffectTier(amount)
	if not effectType then
		return
	end

	task.spawn(function()
		local userId = getUserId(donorName)
		while #effectQueue >= MAX_QUEUE_LIMIT do
			table.remove(effectQueue, 1)
		end
		table.insert(effectQueue, {
			donorName = donorName,
			amount = amount,
			userId = userId,
			currencyType = "Rupiah",
			recipientName = "SAWERIA",
		})
		processQueue()
	end)
end)

-- Listener dari Donasi Robux (1k - 10k Robux)
RobuxEffectEvent.Event:Connect(function(playerOrName, amount)
	local donorName = "Anonymous"
	local userId = 1
	amount = tonumber(amount) or 0

	if typeof(playerOrName) == "Instance" and playerOrName:IsA("Player") then
		donorName = playerOrName.DisplayName or playerOrName.Name
		userId = playerOrName.UserId
	elseif type(playerOrName) == "string" then
		donorName = playerOrName
		userId = getUserId(playerOrName)
	end

	local effectType = getRobuxEffectTier(amount)
	if not effectType then
		return
	end

	task.spawn(function()
		while #effectQueue >= MAX_QUEUE_LIMIT do
			table.remove(effectQueue, 1)
		end
		table.insert(effectQueue, {
			donorName = donorName,
			amount = amount,
			userId = userId,
			currencyType = "Robux",
			recipientName = "SERVER",
		})
		processQueue()
	end)
end)

-- Global helper untuk trigger efek Robux dari script lain / console
_G.TriggerRobuxEffect = function(playerOrName, amount)
	local event = ServerStorage:FindFirstChild("RobuxEffectEvent")
	if event then
		event:Fire(playerOrName, amount)
	end
end

-- Global helper untuk trigger efek langsung (misal untuk testing dari command bar Studio)
_G.TestMegaEffect = function(effectType, donorName, amount, currency)
	donorName = donorName or "MegaTester"
	amount = tonumber(amount) or 1000
	currency = currency or "Robux"
	local recipient = (currency == "Robux" and "SERVER" or "SAWERIA")
	local userId = getUserId(donorName)

	print(string.format("[SaweriaEffectHandler] 🧪 Test Direct: %s | %s | %s %d", effectType, donorName, currency, amount))

	effectsEvent:FireAllClients(effectType, donorName, recipient, amount, userId, currency)
end

-- Global helper untuk on/off efek panggung secara dinamis
_G.SetMegaEffectEnabled = function(effectName, isEnabled)
	if MegaEffectsConfig.EFFECTS_ENABLED[effectName] ~= nil then
		MegaEffectsConfig.EFFECTS_ENABLED[effectName] = (isEnabled == true)
		print(string.format("[MegaEffectsConfig] Efek '%s' status: %s", effectName, tostring(isEnabled)))
		return true
	elseif effectName == "Robux" then
		MegaEffectsConfig.ROBUX_ENABLED = (isEnabled == true)
		print("[MegaEffectsConfig] Robux effects status:", tostring(isEnabled))
		return true
	elseif effectName == "Saweria" then
		MegaEffectsConfig.SAWERIA_ENABLED = (isEnabled == true)
		print("[MegaEffectsConfig] Saweria effects status:", tostring(isEnabled))
		return true
	elseif effectName == "Global" or effectName == "All" then
		MegaEffectsConfig.GLOBAL_ENABLED = (isEnabled == true)
		print("[MegaEffectsConfig] Global effects status:", tostring(isEnabled))
		return true
	end
	warn("[MegaEffectsConfig] Target tidak valid (Gunakan: Nuke, Smite, BlackHole, Starfall, Robux, Saweria, Global)")
	return false
end

print("✅ [SaweriaEffectHandler] Siap menerima efek donasi Saweria & Robux (Configurable Driven)!")
