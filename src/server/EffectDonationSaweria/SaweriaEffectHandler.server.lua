-- ==========================================
-- SAWERIA EFFECT HANDLER (SERVER)
-- Menghubungkan SaweriaEffectEvent ke Efek 3D
-- Mendukung EffectsEvent & Remote Legacy (FireSmite, FireNuke, FireBlackHole)
-- ==========================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

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

local function getEffectTier(amount)
	if amount < 10000 then
		return nil -- Hanya notif UI biasa, tidak ada efek 3D map
	elseif amount < 50000 then
		return "Nuke", 10 -- Nama efek & jeda antrean (detik)
	elseif amount < 200000 then
		return "Smite", 15 -- Giant Hammer
	elseif amount < 500000 then
		return "BlackHole", 20 -- Black Hole
	else
		return "Starfall", 25 -- Winged Giant 10M
	end
end

local function processQueue()
	if isPlayingEffect then return end
	isPlayingEffect = true

	while #effectQueue > 0 do
		local data = table.remove(effectQueue, 1)
		local effectType, waitTime = getEffectTier(data.amount)

		if effectType then
			print(string.format("[SaweriaEffectHandler] 💥 Memutar Efek: %s | Donatur: %s (UserId: %d) | Rp %d", 
				effectType, data.donorName, data.userId, data.amount))

			-- 1. Tembak ke EffectsRemotes.EffectsEvent (Sistem Baru)
			effectsEvent:FireAllClients(effectType, data.donorName, "SAWERIA", data.amount, data.userId)

			-- 2. Tembak juga ke Remote Event legacy jika ada script yang masih memakainya
			if effectType == "Smite" and FireSmite then
				FireSmite:FireAllClients(data.donorName, "SAWERIA", data.amount, data.userId)
			elseif effectType == "Nuke" and FireNuke then
				FireNuke:FireAllClients(data.donorName, "SAWERIA", data.amount)
			elseif effectType == "BlackHole" and FireBlackHole then
				FireBlackHole:FireAllClients(data.donorName, "SAWERIA", data.amount)
			end

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
			userId = userId
		})
		processQueue()
	end)
end)

print("✅ [SaweriaEffectHandler] Siap menerima efek donasi Saweria!")
