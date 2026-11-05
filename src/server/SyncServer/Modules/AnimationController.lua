--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SharedModules = ReplicatedStorage:WaitForChild("Modules")
local AnimatorUtils = require(SharedModules:WaitForChild("AnimatorUtils"))
local DanceState = require(SharedModules:WaitForChild("DanceState"))

local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local ServerModules = SyncServer:WaitForChild("Modules")
local SyncController = require(ServerModules:WaitForChild("SyncController"))

local module = {}

local FADE_OUT = 0.1
local MIN_REQUEST_INTERVAL = 0.01
local MAX_ANCHOR_POSITION = 600

local processingRequests = setmetatable({}, { __mode = "k" })
local lastRequestTime = setmetatable({}, { __mode = "k" })

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function safeSetAttr(obj, key, value)
	if obj:GetAttribute(key) ~= value then
		obj:SetAttribute(key, value)
	end
end

local function readSnapshot(character)
	return DanceState.decode(character:GetAttribute("DanceSnapshot"))
end

local function clearDanceState(character)
	safeSetAttr(character, "CurrentDanceID", nil)
	safeSetAttr(character, "DanceStartTime", nil)
	safeSetAttr(character, "DanceSpeed", nil)
	safeSetAttr(character, "DanceSnapshot", nil)
	safeSetAttr(character, "SpamNonce", nil)
end

local function canProcessRequest(player)
	if processingRequests[player] then return false end
	local lastTime = lastRequestTime[player] or 0
	if (os.clock() - lastTime) < MIN_REQUEST_INTERVAL then return false end
	return true
end

local function startProcessing(player)
	processingRequests[player] = true
	lastRequestTime[player] = os.clock()
end

local function endProcessing(player)
	processingRequests[player] = false
end

local function sanitizeAnchor(clientTime, clientPosition)
	local now = workspace:GetServerTimeNow()

	local anchorTime = now
	if finiteNumber(clientTime) and math.abs(now - clientTime) <= 10 then
		anchorTime = clientTime
	end

	local anchorPosition = 0
	if finiteNumber(clientPosition) then
		anchorPosition = math.clamp(clientPosition, 0, MAX_ANCHOR_POSITION)
	end

	return anchorTime, anchorPosition
end

local function writeSnapshot(character, animationId, anchorTime, anchorPosition, speed, isRestart)
	local current = readSnapshot(character)
	local restartSeq = current and current.restartSeq or 0
	if isRestart then
		restartSeq += 1
	end

	local version = (current and current.version or 0) + 1
	local snapshot = DanceState.encode(animationId, anchorTime, anchorPosition, speed, restartSeq, version)

	safeSetAttr(character, "CurrentDanceID", animationId)
	safeSetAttr(character, "DanceStartTime", anchorTime - (anchorPosition / speed))
	safeSetAttr(character, "DanceSpeed", speed)
	safeSetAttr(character, "DanceSnapshot", snapshot)

	return snapshot
end

function module.executeAnimation(player, animation, shouldPlay, speed, loadedAnimations, isSpam, clientStartTime, clientPosition)
	if not canProcessRequest(player) then return "rate_limited" end
	startProcessing(player)

	local animator = AnimatorUtils.getAnimator(player)
	if not animator or not animator.Parent or not animator.Parent.Parent then
		endProcessing(player)
		return "error"
	end

	speed = math.clamp(tonumber(speed) or 1, 0.1, 3)
	local character = player.Character

	if character then
		local syncTarget = character:GetAttribute("Syncing")
		if syncTarget and syncTarget ~= "" then
			safeSetAttr(character, "Syncing", nil)
			safeSetAttr(character, "CurrentDanceID", nil)
			safeSetAttr(character, "DanceSnapshot", nil)
			task.defer(function()
				if player and player.Parent then
					SyncController.updateLeaderStatus(player)
				end
			end)
		end
	end

	if not shouldPlay then
		if character then
			safeSetAttr(character, "Syncing", nil)
			clearDanceState(character)
		end
		SyncController.stopAllFollowers(player, loadedAnimations)
		SyncController.updateLeaderStatus(player)
		endProcessing(player)
		return "stopped"
	end

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

		if not animation then
			endProcessing(player)
			return "invalid_animation"
		end

		safeSetAttr(character, "Syncing", nil)

		local anchorTime, anchorPosition = sanitizeAnchor(clientStartTime, clientPosition)
		writeSnapshot(character, animation.AnimationId, anchorTime, anchorPosition, speed, true)

		if isSpam then
			local nonce = character:GetAttribute("SpamNonce") or 0
			character:SetAttribute("SpamNonce", nonce + 1)
		end
	end

	endProcessing(player)
	return "playing"
end

function module.adjustAnimationSpeed(player, speed, loadedAnimations, clientAnchorTime, clientPosition)
	if not canProcessRequest(player) then return "rate_limited" end
	startProcessing(player)

	local character = player.Character
	if not character or character:GetAttribute("Syncing") then
		endProcessing(player)
		return "syncing"
	end

	local numSpeed = tonumber(speed)
	if not finiteNumber(numSpeed) then
		endProcessing(player)
		return "invalid_speed"
	end
	speed = math.clamp(numSpeed, 0.1, 3)

	local snapshot = readSnapshot(character)
	if not snapshot then
		local currentDanceId = character:GetAttribute("CurrentDanceID")
		if not currentDanceId or currentDanceId == "" then
			endProcessing(player)
			return "no_dance"
		end
		snapshot = {
			animationId = currentDanceId,
			anchorTime = workspace:GetServerTimeNow(),
			anchorPosition = 0,
			speed = 1,
			restartSeq = 0,
			version = 0,
		}
	end

	local anchorTime, anchorPosition = sanitizeAnchor(clientAnchorTime, clientPosition)
	if not finiteNumber(clientAnchorTime) or not finiteNumber(clientPosition) then
		local now = workspace:GetServerTimeNow()
		anchorTime = now
		anchorPosition = math.max(0, snapshot.anchorPosition + (now - snapshot.anchorTime) * snapshot.speed)
	end

	writeSnapshot(character, snapshot.animationId, anchorTime, anchorPosition, speed, false)

	endProcessing(player)
	return "speed_changed"
end

Players.PlayerRemoving:Connect(function(player)
	processingRequests[player] = nil
	lastRequestTime[player] = nil
end)

return module
