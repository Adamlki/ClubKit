local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local SS            = game:GetService("ServerStorage")
local Workspace     = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ProcessReceiptHandler = require(script.Parent.DonationServerHandler.ProcessReceiptHandler)

-- ============================================================
-- REMOTE — satu-satunya jembatan server ke client
-- ============================================================
local CinematicRemote = RS:FindFirstChild("CinematicRemote")
	or (function()
		local r  = Instance.new("RemoteEvent")
		r.Name   = "CinematicRemote"
		r.Parent = RS
		return r
	end)()

CinematicRemote.OnServerEvent:Connect(function(player)
	player:Kick("Unauthorized remote invocation.")
end)

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	DISPLAY_DURATION      = 10,
	LEVEL4_DURATION       = 10,
	MAX_STORED_DONATIONS  = 10,
	DONATION_STORAGE_TIME = 30,
	STATE_REQUEST_COOLDOWN = 5,

	STAGE_FX_DURATION     = 15,    -- Durasi semburan panggung
	MIN_DONATION_FOR_FX   = 1,     -- Minimal donasi untuk menyalakan panggung otomatis (semua nominal)
}

local PRICE_RANGES = {
	{ name = "Level 1", minPrice = 1,   maxPrice = 89,      templateName = "Level1", useCinematic = false },
	{ name = "Level 2", minPrice = 90,  maxPrice = 449,     templateName = "Level2", useCinematic = false },
	{ name = "Level 3", minPrice = 450, maxPrice = 899,     templateName = "Level3", useCinematic = false },
	{
		name              = "Level 4",
		minPrice          = 900,
		maxPrice          = 9999999,
		templateName      = "Level4",
		useCinematic      = false,
		cinematicColor    = { r = 255, g = 215, b = 0 },
		cinematicDuration = 10,
	},
}

-- ============================================================
-- STATE
-- ============================================================
local recentDonations  = {}
local requestCooldowns = {}
local isStageFiring    = false -- Mencegah tumpang tindih semprotan panggung
local stageFireEndTime = 0

-- ============================================================
-- STAGE FX HANDLER (CONFETTI & SMOKE)
-- ============================================================
local function triggerStageEffects(duration)
	duration = duration or CONFIG.STAGE_FX_DURATION
	stageFireEndTime = math.max(stageFireEndTime, tick() + duration)

	local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
	if not stageEffectsFolder then
		warn("[DonationEffect] Folder StageEffects tidak ditemukan di Workspace!")
		return
	end

	-- 1. NYALAKAN SEMUA EFEK PANGGUNG
	for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
		if stageFX:IsA("BasePart") then
			local sound = stageFX:FindFirstChild("HissSound")
			if sound and not sound.IsPlaying then
				pcall(function() sound:Play() end)
			end

			for _, fx in ipairs(stageFX:GetChildren()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx.Enabled = true
				end
			end
		end
	end

	if isStageFiring then
		-- Jika sedang menyala, perpanjang timer agar donasi baru tetap menikmati efek penuh
		return
	end
	isStageFiring = true

	-- 2. TUNGGU DURASI (Bisa diperpanjang jika ada donasi berturut-turut)
	while tick() < stageFireEndTime and isStageFiring do
		task.wait(0.25)
	end

	-- 3. MATIKAN SEMUA EFEK DENGAN "SMOOTH"
	if stageEffectsFolder and stageEffectsFolder.Parent then
		for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
			if stageFX:IsA("BasePart") then
				for _, fx in ipairs(stageFX:GetChildren()) do
					if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
						fx.Enabled = false
					end
				end
			end
		end
	end

	isStageFiring = false
	stageFireEndTime = 0
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getRangeByPrice(price)
	for _, range in ipairs(PRICE_RANGES) do
		if price >= range.minPrice and price <= range.maxPrice then
			return range
		end
	end
	if price and price > 0 then
		return PRICE_RANGES[1] -- Fallback agar donasi nominal berapapun tetap dapat efek
	end
	return nil
end

local function canRequestState(player)
	local last = requestCooldowns[player.UserId] or 0
	if tick() - last < CONFIG.STATE_REQUEST_COOLDOWN then return false end
	requestCooldowns[player.UserId] = tick()
	return true
end

-- Spawn objek 3D di atas kepala donor
local function spawnDonationObject(player, templateName, duration)
	local template = SS.TemplateDonation:FindFirstChild(templateName)
	if not template then return end

	local character
	for _ = 1, 20 do
		character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then break end
		task.wait(0.15)
	end
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local ok, obj = pcall(function() return template:Clone() end)
	if not ok or not obj then return end

	if obj:IsA("Model") then
		if not obj.PrimaryPart then obj:Destroy() return end
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored   = false
			end
		end
		obj:SetPrimaryPartCFrame(hrp.CFrame * CFrame.new(0, 3, 0))
		local weld       = Instance.new("WeldConstraint")
		weld.Part0       = hrp
		weld.Part1       = obj.PrimaryPart
		weld.Parent      = obj

	elseif obj:IsA("BasePart") then
		obj.CanCollide = false
		obj.Anchored   = false
		obj.CFrame     = hrp.CFrame * CFrame.new(0, 3, 0)
		local weld     = Instance.new("WeldConstraint")
		weld.Part0     = hrp
		weld.Part1     = obj
		weld.Parent    = obj
	end

	CollectionService:AddTag(obj, "DonationEffect")
	obj.Parent = workspace

	task.delay(duration, function()
		if obj and obj.Parent then obj:Destroy() end
	end)
end

local function storeDonation(data)
	table.insert(recentDonations, data)
	while #recentDonations > CONFIG.MAX_STORED_DONATIONS do
		table.remove(recentDonations, 1)
	end
end

-- 🔥 PERBAIKAN: Background Garbage Collection (1 loop per server, bukan per donasi)
task.spawn(function()
	while true do
		task.wait(10)
		local cutoff = tick() - CONFIG.DONATION_STORAGE_TIME
		for i = #recentDonations, 1, -1 do
			if recentDonations[i].timestamp < cutoff then
				table.remove(recentDonations, i)
			end
		end
	end
end)

local function fireToPlayer(targetPlayer, donationData)
	if not targetPlayer or not targetPlayer.Parent then return end
	pcall(function() CinematicRemote:FireClient(targetPlayer, donationData) end)
end

local function fireToAllPlayers(donationData)
	-- 🔥 OPTIMASI 50+ PLAYERS: Native C++ Engine Multicast (1 call tanpa 50x pcall loop)
	pcall(function()
		CinematicRemote:FireAllClients(donationData)
	end)
end

-- ============================================================
-- MAIN DONATION GRANT (ROBUX)
-- ============================================================
local function grantDonationEffect(player, price)
	local range = getRangeByPrice(price)
	if not range then return false end

	local duration = range.useCinematic
		and (range.cinematicDuration or CONFIG.LEVEL4_DURATION)
		or  CONFIG.DISPLAY_DURATION

	-- 1. Efek 3D di atas kepala donor
	task.spawn(function()
		spawnDonationObject(player, range.templateName, duration)
	end)

	-- 2. Efek semburan api panggung StageFX (selalu aktif berapapun nominal donasinya)
	task.spawn(function()
		triggerStageEffects(CONFIG.STAGE_FX_DURATION)
	end)

	-- 3. Efek Mega Panggung (500-999: Nuke, 1000+: Palu/Smite & Ava Clone)
	if price >= 500 then
		local RobuxEffectEvent = SS:FindFirstChild("RobuxEffectEvent")
		if not RobuxEffectEvent then
			RobuxEffectEvent = Instance.new("BindableEvent")
			RobuxEffectEvent.Name = "RobuxEffectEvent"
			RobuxEffectEvent.Parent = SS
		end
		RobuxEffectEvent:Fire(player, price)
	end

	local donationData = {
		donorName         = player.DisplayName,
		donorUserId       = player.UserId,
		price             = price,
		currencyType      = "Robux", -- 🔥 TAMBAHAN: Tanda kalau ini Robux
		levelName         = range.name,
		useCinematic      = range.useCinematic,
		cinematicColor    = range.cinematicColor,
		cinematicDuration = duration,
		timestamp         = tick(),
	}

	storeDonation(donationData)
	fireToAllPlayers(donationData)

	return true
end

-- ============================================================
-- EVENT LISTENERS (LATE JOINERS)
-- ============================================================
-- 🔥 FIX: Jangan kirim CinematicRemote ke Late Joiner. 
-- Efek donasi (Popup UI/Cinematic) bersifat live/real-time. 
-- Mengirim histori masa lalu ke pemain yang baru masuk akan membuat 
-- mereka mengira ada donasi hantu, padahal itu donasi lama.

Players.PlayerAdded:Connect(function(player)
	-- Tidak perlu sync Cinematic UI untuk late joiners.
end)

local RequestDonationState = RS:FindFirstChild("RequestDonationState")
	or (function()
		local r  = Instance.new("RemoteEvent")
		r.Name   = "RequestDonationState"
		r.Parent = RS
		return r
	end)()

RequestDonationState.OnServerEvent:Connect(function(player)
	-- Jika ada UI History khusus, gunakan remote lain. 
	-- CinematicRemote HANYA untuk efek live!
end)

Players.PlayerRemoving:Connect(function(player)
	requestCooldowns[player.UserId] = nil
end)

-- ============================================================
-- INTEGRATE PROCESSRECEIPTHANDLER
-- ============================================================
local waited = 0
while not ProcessReceiptHandler:IsInitialized() and waited < 10 do
	task.wait(0.5)
	waited += 0.5
end

if not ProcessReceiptHandler:IsInitialized() then
	warn("[DonationEffectHandler] ProcessReceiptHandler belum siap!")
else
	ProcessReceiptHandler:RegisterCallback("DonationEffect", function(player, productId, amount)
		local ok, err = pcall(grantDonationEffect, player, amount)
		if not ok then warn("[DonationEffect] Error:", err) end
		return ok
	end)
end

-- ============================================================
-- INTEGRASI EFEK SAWERIA (RUPIAH)
-- ============================================================
-- 🔥 PERBAIKAN TYPO DI LEVEL 2
local SAWERIA_RANGES = {
	{ name = "Level 1", minPrice = 1,       maxPrice = 49999,     templateName = "Level1", useCinematic = false },
	{ name = "Level 2", minPrice = 50000,   maxPrice = 499999,    templateName = "Level2", useCinematic = false },
	{ name = "Level 3", minPrice = 500000,  maxPrice = 999999,    templateName = "Level3", useCinematic = false },
	{
		name              = "Level 4",
		minPrice          = 1000000,
		maxPrice          = 999999999,
		templateName      = "Level4",
		useCinematic      = true,
		cinematicColor    = { r = 255, g = 215, b = 0 },
		cinematicDuration = 8,
	},
}

local function getSaweriaRangeByPrice(price)
	for _, range in ipairs(SAWERIA_RANGES) do
		if price >= range.minPrice and price <= range.maxPrice then
			return range
		end
	end
	if price and price > 0 then
		return SAWERIA_RANGES[1] -- Fallback agar donasi nominal berapapun tetap dapat efek
	end
	return nil
end

local function grantSaweriaEffect(playerOrName, rpAmount)
	local range = getSaweriaRangeByPrice(rpAmount)
	if not range then return false end

	local duration = range.useCinematic
		and (range.cinematicDuration or CONFIG.LEVEL4_DURATION)
		or  CONFIG.DISPLAY_DURATION

	local donorPlayer = nil
	local donorDisplayName = "Saweria Donator"
	local donorUserId = 1

	if typeof(playerOrName) == "Instance" and playerOrName:IsA("Player") then
		donorPlayer = playerOrName
		donorDisplayName = playerOrName.DisplayName
		donorUserId = playerOrName.UserId
	elseif type(playerOrName) == "string" then
		donorDisplayName = playerOrName
		donorPlayer = Players:FindFirstChild(playerOrName)
		if donorPlayer then
			donorUserId = donorPlayer.UserId
		else
			pcall(function()
				donorUserId = Players:GetUserIdFromNameAsync(playerOrName)
			end)
		end
	end

	-- 1. Efek 3D di atas kepala donor
	if donorPlayer then
		task.spawn(function()
			spawnDonationObject(donorPlayer, range.templateName, duration)
		end)
	end

	-- 2. Efek semburan api panggung StageFX (selalu aktif berapapun nominal donasinya)
	task.spawn(function()
		triggerStageEffects(CONFIG.STAGE_FX_DURATION)
	end)

	local donationData = {
		donorName         = donorDisplayName,
		donorUserId       = donorUserId or 1,
		price             = rpAmount, 
		currencyType      = "Rupiah", -- 🔥 TAMBAHAN: Tanda kalau ini Rupiah
		levelName         = range.name,
		useCinematic      = range.useCinematic,
		cinematicColor    = range.cinematicColor,
		cinematicDuration = duration,
		timestamp         = tick(),
	}

	storeDonation(donationData)
	fireToAllPlayers(donationData)

	return true
end

-- Membuat jembatan komunikasi antar script
local SaweriaEffectEvent = SS:FindFirstChild("SaweriaEffectEvent")
if not SaweriaEffectEvent then
	SaweriaEffectEvent = Instance.new("BindableEvent")
	SaweriaEffectEvent.Name = "SaweriaEffectEvent"
	SaweriaEffectEvent.Parent = SS
end

-- Menjalankan efek saat ada sinyal dari script DonasiSaweria
SaweriaEffectEvent.Event:Connect(function(playerOrName, rpAmount)
	grantSaweriaEffect(playerOrName, rpAmount)
end)

-- ============================================================
-- GLOBAL STAGE EFFECTS CONTROLLER (ADMIN & SCRIPT ACCESS)
-- ============================================================
local StageEffectEvent = SS:FindFirstChild("StageEffectEvent")
if not StageEffectEvent then
	StageEffectEvent = Instance.new("BindableEvent")
	StageEffectEvent.Name = "StageEffectEvent"
	StageEffectEvent.Parent = SS
end

StageEffectEvent.Event:Connect(function(action, duration)
	if action == "stop" then
		isStageFiring = false
		local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
		if stageEffectsFolder then
			for _, fx in ipairs(stageEffectsFolder:GetDescendants()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx.Enabled = false
				end
			end
		end
	else
		task.spawn(function()
			triggerStageEffects(duration or CONFIG.STAGE_FX_DURATION)
		end)
	end
end)

_G.TriggerStageEffects = function(duration)
	task.spawn(function()
		triggerStageEffects(duration or CONFIG.STAGE_FX_DURATION)
	end)
end

_G.StopStageEffects = function()
	isStageFiring = false
	stageFireEndTime = 0
	local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
	if stageEffectsFolder then
		for _, fx in ipairs(stageEffectsFolder:GetDescendants()) do
			if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
				fx.Enabled = false
			end
		end
	end
end

_G.GetStageFXDuration = function()
	return CONFIG.STAGE_FX_DURATION
end

_G.IsStageFiring = function()
	return isStageFiring
end

-- ============================================================
-- TEST HELPER (STUDIO & ADMIN COMMANDS)
-- ============================================================
_G.TriggerTestDonation = function(donatorName, amount, message)
	amount = tonumber(amount) or 100
	local p = Players:FindFirstChild(donatorName or "")
	if not p then
		p = Players:GetPlayers()[1]
	end
	if p then
		grantDonationEffect(p, amount)
	else
		local range = getRangeByPrice(amount)
		task.spawn(function()
			triggerStageEffects(CONFIG.STAGE_FX_DURATION)
		end)

		-- Trigger Efek Mega Panggung jika >= 500 (Nuke / Palu)
		if amount >= 500 then
			local RobuxEffectEvent = SS:FindFirstChild("RobuxEffectEvent")
			if not RobuxEffectEvent then
				RobuxEffectEvent = Instance.new("BindableEvent")
				RobuxEffectEvent.Name = "RobuxEffectEvent"
				RobuxEffectEvent.Parent = SS
			end
			RobuxEffectEvent:Fire(donatorName or "TestDonor", amount)
		end

		local duration = range and (range.useCinematic and (range.cinematicDuration or CONFIG.LEVEL4_DURATION) or CONFIG.DISPLAY_DURATION) or 10
		local donationData = {
			donorName         = donatorName or "TestDonor",
			donorUserId       = 1,
			price             = amount,
			currencyType      = "Robux",
			levelName         = range and range.name or "Level 1",
			useCinematic      = range and range.useCinematic or false,
			cinematicColor    = range and range.cinematicColor or nil,
			cinematicDuration = duration,
			timestamp         = tick(),
		}
		storeDonation(donationData)
		fireToAllPlayers(donationData)
	end
end