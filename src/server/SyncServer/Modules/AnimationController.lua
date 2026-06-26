--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimatorUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimatorUtils"))
local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local ServerModules = SyncServer:WaitForChild("Modules")
local SyncController = require(ServerModules:WaitForChild("SyncController"))

local module = {}

-- ============================================
-- CONFIG & ANTI-SPAM
-- ============================================
local FADE_OUT = 0.5
local DANCE_WALK_SPEED = 5
local ANIMATION_PRIORITY = Enum.AnimationPriority.Action4

local processingRequests = {}
local lastRequestTime = {}
local MIN_REQUEST_INTERVAL = 0.03

local function canProcessRequest(player)
	if processingRequests[player] then return false end
	local lastTime = lastRequestTime[player] or 0
	if (tick() - lastTime) < MIN_REQUEST_INTERVAL then return false end
	return true
end

local function startProcessing(player)
	processingRequests[player] = true
	lastRequestTime[player] = tick()
end

local function endProcessing(player)
	processingRequests[player] = false
end

-- ============================================
-- EXECUTE ANIMATION
-- ============================================
function module.executeAnimation(player, animation, shouldPlay, speed, loadedAnimations, isSpam, clientStartTime)
	if not canProcessRequest(player) then return "rate_limited" end -- Berlaku untuk Play DAN Stop!
	startProcessing(player)

	local animator = AnimatorUtils.getAnimator(player)
	if not animator or not animator.Parent or not animator.Parent.Parent then
		endProcessing(player) return "error"
	end

	speed = math.clamp(tonumber(speed) or 1, 0.1, 3)
	local character = player.Character

	if character then
		local syncTarget = character:GetAttribute("Syncing")
		if syncTarget and syncTarget ~= "" then
			character:SetAttribute("Syncing", nil)
			character:SetAttribute("CurrentDanceID", nil)
			--AnimatorUtils.stopAllDances(animator, loadedAnimations, FADE_OUT)
			task.delay(FADE_OUT, function() SyncController.updateLeaderStatus(player) end)
		end
	end

	-- === STOP LOGIC ===
	if not shouldPlay then
		--AnimatorUtils.stopAllDances(animator, loadedAnimations, FADE_OUT)
		if character then
			character:SetAttribute("Syncing", nil)
			character:SetAttribute("CurrentDanceID", nil)
			character:SetAttribute("DanceStartTime", nil)
			character:SetAttribute("DanceSpeed", nil)
		end
		SyncController.stopAllFollowers(player, loadedAnimations)
		SyncController.updateLeaderStatus(player)
		endProcessing(player)
		return "stopped"
	end

	-- === PLAY & SPAM LOGIC ===
	if character then
		if character:GetAttribute("GlobalEffectActive") then
			local GlobalEffectRemotes = ReplicatedStorage:FindFirstChild("GlobalEffectRemotes")
			if GlobalEffectRemotes then
				local NotificationEvent = GlobalEffectRemotes:FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(player, "Efek Aktif", "Kamu tidak bisa menari saat terbang/melayang!", 3)
				end
			end
			endProcessing(player)
			return "blocked"
		end
		
		local carryable = character:FindFirstChild("Carryable")
		if carryable and carryable.Value == false then
			local GlobalEffectRemotes = ReplicatedStorage:FindFirstChild("GlobalEffectRemotes")
			if GlobalEffectRemotes then
				local NotificationEvent = GlobalEffectRemotes:FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(player, "Gagal", "Kamu tidak bisa menari saat sedang digendong/menggendong!", 3)
				end
			end
			endProcessing(player)
			return "blocked"
		end
		
		character:SetAttribute("Syncing", nil)

		if animation then
			character:SetAttribute("CurrentDanceID", animation.AnimationId)
		end

		character:SetAttribute("DanceStartTime", clientStartTime or workspace:GetServerTimeNow())
		character:SetAttribute("DanceSpeed", speed)

		if isSpam then
			local currentNonce = character:GetAttribute("SpamNonce") or 0
			character:SetAttribute("SpamNonce", currentNonce + 1)
		end
	end

	endProcessing(player)
	return "playing"
end

-- ============================================
-- ADJUST ANIMATION SPEED (PURE MATH TIME-WARP FIX)
-- ============================================
function module.adjustAnimationSpeed(player, speed, loadedAnimations)
	local character = player.Character
	if not character or character:GetAttribute("Syncing") then return "syncing" end

	speed = math.clamp(tonumber(speed) or 1, 0.1, 3)

	local oldSpeed = character:GetAttribute("DanceSpeed") or 1
	local oldStartTime = character:GetAttribute("DanceStartTime") or workspace:GetServerTimeNow()

	local elapsed = workspace:GetServerTimeNow() - oldStartTime
	local exactTimePosition = elapsed * oldSpeed
	local compensatedStartTime = workspace:GetServerTimeNow() - (exactTimePosition / speed)

	local animator = AnimatorUtils.getAnimator(player)
	if animator then
		local track = AnimatorUtils.getPlayingDanceTrack(animator, loadedAnimations)
		if track then pcall(function() track:AdjustSpeed(speed) end) end
	end

	character:SetAttribute("DanceSpeed", speed)
	character:SetAttribute("DanceStartTime", compensatedStartTime)

	return "speed_changed"
end

Players.PlayerRemoving:Connect(function(player)
	processingRequests[player] = nil
	lastRequestTime[player] = nil
end)

return module