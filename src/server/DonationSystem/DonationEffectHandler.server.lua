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
	MIN_DONATION_FOR_FX   = 100,  -- Minimal donasi untuk menyalakan panggung otomatis
}

local PRICE_RANGES = {
	--{ name = "Level 1", minPrice = 13, maxPrice = 99, templateName = "Level1", useCinematic = false },
	{ name = "Level 2", minPrice = 100, maxPrice = 499, templateName = "Level2", useCinematic = false },
	{ name = "Level 3", minPrice = 500, maxPrice = 999, templateName = "Level3", useCinematic = false },
	{
		name              = "Level 4",
		minPrice          = 1000,
		maxPrice          = 9999999,
		templateName      = "Level4",
		useCinematic      = true,
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

-- ============================================================
-- STAGE FX HANDLER (CONFETTI & SMOKE)
-- ============================================================
local function triggerStageEffects(duration)
	if isStageFiring then return end
	isStageFiring = true

	local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
	if not stageEffectsFolder then
		warn("[DonationEffect] Folder StageEffects tidak ditemukan di Workspace!")
		isStageFiring = false
		return
	end

	-- 1. NYALAKAN SEMUA EFEK
	for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
		if stageFX:IsA("BasePart") then
			local sound = stageFX:FindFirstChild("HissSound")
			if sound then sound:Play() end

			for _, fx in ipairs(stageFX:GetChildren()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx.Enabled = true
				end
			end
		end
	end

	-- 2. TUNGGU DURASI
	task.wait(duration)

	-- 3. MATIKAN DENGAN "SMOOTH"
	for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
		if stageFX:IsA("BasePart") then
			for _, fx in ipairs(stageFX:GetChildren()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx.Enabled = false
				end
			end
		end
	end

	isStageFiring = false
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
	task.delay(CONFIG.DONATION_STORAGE_TIME, function()
		local cutoff = tick() - CONFIG.DONATION_STORAGE_TIME
		for i = #recentDonations, 1, -1 do
			if recentDonations[i].timestamp < cutoff then
				table.remove(recentDonations, i)
			end
		end
	end)
end

local function fireToPlayer(targetPlayer, donationData)
	if not targetPlayer or not targetPlayer.Parent then return end
	pcall(function() CinematicRemote:FireClient(targetPlayer, donationData) end)
end

local function fireToAllPlayers(donationData)
	for _, p in ipairs(Players:GetPlayers()) do
		fireToPlayer(p, donationData)
	end
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

	task.spawn(function()
		spawnDonationObject(player, range.templateName, duration)
	end)

	if price >= CONFIG.MIN_DONATION_FOR_FX then
		task.spawn(function()
			triggerStageEffects(CONFIG.STAGE_FX_DURATION)
		end)
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
Players.PlayerAdded:Connect(function(player)
	-- Sync untuk Late Joiners
	task.wait(3)
	if #recentDonations == 0 then return end
	for _, data in ipairs(recentDonations) do
		fireToPlayer(player, data)
		task.wait(0.1)
	end
end)

local RequestDonationState = RS:FindFirstChild("RequestDonationState")
	or (function()
		local r  = Instance.new("RemoteEvent")
		r.Name   = "RequestDonationState"
		r.Parent = RS
		return r
	end)()

RequestDonationState.OnServerEvent:Connect(function(player)
	if not canRequestState(player) then return end
	task.wait(0.5)
	for _, data in ipairs(recentDonations) do
		fireToPlayer(player, data)
		task.wait(0.1)
	end
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
	{ name = "Level 1", minPrice = 5000,    maxPrice = 49999,     templateName = "Level1", useCinematic = false },
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
	return nil
end

local function grantSaweriaEffect(player, rpAmount)
	local range = getSaweriaRangeByPrice(rpAmount)
	if not range then return false end

	local duration = range.useCinematic
		and (range.cinematicDuration or CONFIG.LEVEL4_DURATION)
		or  CONFIG.DISPLAY_DURATION

	task.spawn(function()
		spawnDonationObject(player, range.templateName, duration)
	end)

	if rpAmount >= 10000 then
		task.spawn(function()
			triggerStageEffects(CONFIG.STAGE_FX_DURATION)
		end)
	end

	local donationData = {
		donorName         = player.DisplayName,
		donorUserId       = player.UserId,
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
SaweriaEffectEvent.Event:Connect(function(player, rpAmount)
	grantSaweriaEffect(player, rpAmount)
end)