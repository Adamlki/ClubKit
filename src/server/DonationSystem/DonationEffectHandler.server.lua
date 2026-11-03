local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local SS                = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local DebugHooks = require(SS:WaitForChild("Modules"):WaitForChild("DebugHooks"))
local EffectService = require(SS:WaitForChild("Modules"):WaitForChild("EffectService"))

local CinematicRemote = RS:FindFirstChild("CinematicRemote")
if not CinematicRemote then
	CinematicRemote = Instance.new("RemoteEvent")
	CinematicRemote.Name = "CinematicRemote"
	CinematicRemote.Parent = RS
end

CinematicRemote.OnServerEvent:Connect(function(player)
	player:Kick("Unauthorized remote invocation.")
end)

local RequestDonationState = RS:FindFirstChild("RequestDonationState")
if not RequestDonationState then
	RequestDonationState = Instance.new("RemoteEvent")
	RequestDonationState.Name = "RequestDonationState"
	RequestDonationState.Parent = RS
end

RequestDonationState.OnServerEvent:Connect(function(player)
	-- CinematicRemote is live-only
end)

local CONFIG = {
	DISPLAY_DURATION      = 10,
	LEVEL4_DURATION       = 10,
	MAX_STORED_DONATIONS  = 10,
	DONATION_STORAGE_TIME = 30,
	STAGE_FX_DURATION     = 15,
	MIN_DONATION_FOR_FX   = 1,
}

local PRICE_RANGES = {
	{ name = "Level 1", minPrice = 1,   maxPrice = 399,     templateName = "Level1", useCinematic = false },
	{ name = "Level 2", minPrice = 400, maxPrice = 799,     templateName = "Level2", useCinematic = false },
	{ name = "Level 3", minPrice = 800, maxPrice = 1999,    templateName = "Level3", useCinematic = false },
	{
		name              = "Level 4",
		minPrice          = 2000,
		maxPrice          = 9999999,
		templateName      = "Level4",
		useCinematic      = false,
		cinematicColor    = { r = 255, g = 215, b = 0 },
		cinematicDuration = 10,
	},
}

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

local recentDonations  = {}
local isStageFiring    = false
local stageFireEndTime = 0

local function setStageEffectsEnabled(enabled)
	local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
	if not stageEffectsFolder then return end

	for _, stageFX in ipairs(stageEffectsFolder:GetDescendants()) do
		if stageFX:IsA("ParticleEmitter") or stageFX:IsA("Smoke") then
			stageFX.Enabled = enabled
		end
	end
end

local function stopStageEffects()
	isStageFiring = false
	stageFireEndTime = 0
	setStageEffectsEnabled(false)
end

local function triggerStageEffects(duration)
	duration = duration or CONFIG.STAGE_FX_DURATION
	stageFireEndTime = math.max(stageFireEndTime, tick() + duration)

	local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
	if not stageEffectsFolder then
		warn("[DonationEffect] Folder StageEffects tidak ditemukan di Workspace!")
		return
	end

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

	if isStageFiring then return end
	isStageFiring = true

	while tick() < stageFireEndTime and isStageFiring do
		task.wait(0.25)
	end

	if stageEffectsFolder and stageEffectsFolder.Parent then
		setStageEffectsEnabled(false)
	end

	isStageFiring = false
	stageFireEndTime = 0
end

local function findRange(ranges, price)
	for _, range in ipairs(ranges) do
		if price >= range.minPrice and price <= range.maxPrice then
			return range
		end
	end
	return price and price > 0 and ranges[1] or nil
end

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
		local weld  = Instance.new("WeldConstraint")
		weld.Part0  = hrp
		weld.Part1  = obj.PrimaryPart
		weld.Parent = obj
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

task.spawn(function()
	while true do
		task.wait(30)
		local cutoff = tick() - CONFIG.DONATION_STORAGE_TIME
		for i = #recentDonations, 1, -1 do
			if recentDonations[i].timestamp < cutoff then
				table.remove(recentDonations, i)
			end
		end
	end
end)

local function fireToAllPlayers(donationData)
	pcall(function()
		CinematicRemote:FireAllClients(donationData)
	end)
end

local function broadcastDonation(currencyType, donorPlayer, donorDisplayName, donorUserId, amount, range, shouldSpotlight)
	local duration = range.useCinematic
		and (range.cinematicDuration or CONFIG.LEVEL4_DURATION)
		or  CONFIG.DISPLAY_DURATION

	if donorPlayer and not shouldSpotlight then
		task.spawn(function()
			spawnDonationObject(donorPlayer, range.templateName, duration)
		end)
	end

	task.spawn(function()
		triggerStageEffects(CONFIG.STAGE_FX_DURATION)
	end)

	local donationData = {
		donorName         = donorDisplayName,
		donorUserId       = donorUserId,
		price             = amount,
		currencyType      = currencyType,
		levelName         = range.name,
		useCinematic      = range.useCinematic,
		cinematicColor    = range.cinematicColor,
		cinematicDuration = duration,
		timestamp         = tick(),
	}

	storeDonation(donationData)
	fireToAllPlayers(donationData)
end

local function grantDonationEffect(player, price, shouldSpotlight)
	local range = findRange(PRICE_RANGES, price)
	if not range then return false end

	if price >= 400 then
		local robuxEffectEvent = SS:FindFirstChild("RobuxEffectEvent")
		if not robuxEffectEvent then
			robuxEffectEvent = Instance.new("BindableEvent")
			robuxEffectEvent.Name = "RobuxEffectEvent"
			robuxEffectEvent.Parent = SS
		end
		robuxEffectEvent:Fire(player, price)
	end

	broadcastDonation("Robux", player, player.DisplayName, player.UserId, price, range, shouldSpotlight)
	return true
end

local function grantSaweriaEffect(playerOrName, rpAmount, shouldSpotlight)
	local range = findRange(SAWERIA_RANGES, rpAmount)
	if not range then return false end

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
			pcall(function() donorUserId = Players:GetUserIdFromNameAsync(playerOrName) end)
		end
	end

	broadcastDonation("Rupiah", donorPlayer, donorDisplayName, donorUserId or 1, rpAmount, range, shouldSpotlight)
	return true
end

local RobuxDonationEffectEvent = SS:FindFirstChild("RobuxDonationEffectEvent")
if not RobuxDonationEffectEvent then
	RobuxDonationEffectEvent = Instance.new("BindableEvent")
	RobuxDonationEffectEvent.Name = "RobuxDonationEffectEvent"
	RobuxDonationEffectEvent.Parent = SS
end

RobuxDonationEffectEvent.Event:Connect(function(playerOrName, robuxAmount, shouldSpotlight)
	local donorPlayer = nil
	if typeof(playerOrName) == "Instance" and playerOrName:IsA("Player") then
		donorPlayer = playerOrName
	elseif type(playerOrName) == "string" then
		donorPlayer = Players:FindFirstChild(playerOrName)
	end

	if donorPlayer then
		local ok, err = pcall(grantDonationEffect, donorPlayer, robuxAmount, shouldSpotlight)
		if not ok then warn("[DonationEffect] Error:", err) end
	else
		task.spawn(function() triggerStageEffects(CONFIG.STAGE_FX_DURATION) end)
		if robuxAmount and robuxAmount >= 400 then
			local robuxEffectEvent = SS:FindFirstChild("RobuxEffectEvent")
			if robuxEffectEvent then robuxEffectEvent:Fire(playerOrName, robuxAmount) end
		end
	end
end)

local SaweriaEffectEvent = SS:FindFirstChild("SaweriaEffectEvent")
if not SaweriaEffectEvent then
	SaweriaEffectEvent = Instance.new("BindableEvent")
	SaweriaEffectEvent.Name = "SaweriaEffectEvent"
	SaweriaEffectEvent.Parent = SS
end

SaweriaEffectEvent.Event:Connect(function(playerOrName, rpAmount, shouldSpotlight)
	grantSaweriaEffect(playerOrName, rpAmount, shouldSpotlight)
end)

local StageEffectEvent = SS:FindFirstChild("StageEffectEvent")
if not StageEffectEvent then
	StageEffectEvent = Instance.new("BindableEvent")
	StageEffectEvent.Name = "StageEffectEvent"
	StageEffectEvent.Parent = SS
end

StageEffectEvent.Event:Connect(function(action, duration)
	if action == "stop" then
		stopStageEffects()
	else
		task.spawn(function() triggerStageEffects(duration or CONFIG.STAGE_FX_DURATION) end)
	end
end)

local function publicTriggerStageEffects(duration)
	task.spawn(function() triggerStageEffects(duration or CONFIG.STAGE_FX_DURATION) end)
end

local function getStageFXDuration()
	return CONFIG.STAGE_FX_DURATION
end

local function isStageFiringPublic()
	return isStageFiring
end

EffectService.Register("TriggerStageEffects", publicTriggerStageEffects)
EffectService.Register("StopStageEffects", stopStageEffects)
EffectService.Register("GetStageFXDuration", getStageFXDuration)
EffectService.Register("IsStageFiring", isStageFiringPublic)

local function triggerTestDonation(donatorName, amount, message)
	amount = tonumber(amount) or 100
	local p = Players:FindFirstChild(donatorName or "") or Players:GetPlayers()[1]
	if p then
		grantDonationEffect(p, amount)
	else
		local range = findRange(PRICE_RANGES, amount)
		task.spawn(function() triggerStageEffects(CONFIG.STAGE_FX_DURATION) end)

		if amount >= 400 then
			local robuxEffectEvent = SS:FindFirstChild("RobuxEffectEvent")
			if not robuxEffectEvent then
				robuxEffectEvent = Instance.new("BindableEvent")
				robuxEffectEvent.Name = "RobuxEffectEvent"
				robuxEffectEvent.Parent = SS
			end
			robuxEffectEvent:Fire(donatorName or "TestDonor", amount)
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

DebugHooks.Register("TriggerTestDonation", triggerTestDonation)