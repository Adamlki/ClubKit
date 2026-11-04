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

-- CONFIG & ANTI-SPAM
local FADE_OUT = 0.1
local DANCE_WALK_SPEED = 5
local ANIMATION_PRIORITY = Enum.AnimationPriority.Action4

local processingRequests = setmetatable({}, { __mode = "k" })
local lastRequestTime = setmetatable({}, { __mode = "k" })
local spamNonceCooldown = {}
local MIN_REQUEST_INTERVAL = 0.05

Players.PlayerRemoving:Connect(function(player)
	spamNonceCooldown[player.UserId] = nil
end)

-- Set attribute hanya jika nilainya berubah untuk menghemat replikasi.
local function safeSetAttr(obj, key, value)
	if obj:GetAttribute(key) ~= value then
		obj:SetAttribute(key, value)
	end
end

local function clearDanceState(character)
	safeSetAttr(character, "CurrentDanceID", nil)
	safeSetAttr(character, "DanceStartTime", nil)
	safeSetAttr(character, "DanceSpeed", nil)
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

-- EXECUTE ANIMATION
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
			safeSetAttr(character, "Syncing", nil)
			safeSetAttr(character, "CurrentDanceID", nil)
			task.delay(FADE_OUT, function() SyncController.updateLeaderStatus(player) end)
		end
	end

	-- === STOP LOGIC ===
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
		
		safeSetAttr(character, "Syncing", nil)

		local currentDanceId = character:GetAttribute("CurrentDanceID")
		local sameDance = animation ~= nil and currentDanceId == animation.AnimationId
		local spamOnSameDance = isSpam == true and sameDance

		if animation and not sameDance then
			safeSetAttr(character, "CurrentDanceID", animation.AnimationId)
		end

		-- Spam on the same dance must not rewrite the start time every click.
		-- That was replicating 3-4 attributes to every client per request.
		if not spamOnSameDance then
			local validStartTime = workspace:GetServerTimeNow()
			if type(clientStartTime) == "number" and clientStartTime == clientStartTime and math.abs(validStartTime - clientStartTime) <= 10 then
				validStartTime = clientStartTime
			end
			character:SetAttribute("DanceStartTime", validStartTime)
		end

		if character:GetAttribute("DanceSpeed") ~= speed then
			safeSetAttr(character, "DanceSpeed", speed)
		end

		if spamOnSameDance then
			local now = os.clock()
			local lastSpam = spamNonceCooldown[player.UserId] or 0
			if now - lastSpam >= 0.25 then
				spamNonceCooldown[player.UserId] = now
				local currentNonce = character:GetAttribute("SpamNonce") or 0
				character:SetAttribute("SpamNonce", currentNonce + 1)
			end
		end
	end

	endProcessing(player)
	return "playing"
end

-- ADJUST ANIMATION SPEED
function module.adjustAnimationSpeed(player, speed, loadedAnimations)
	if not canProcessRequest(player) then return "rate_limited" end
	startProcessing(player)

	local character = player.Character
	if not character or character:GetAttribute("Syncing") then 
		endProcessing(player)
		return "syncing" 
	end

	local numSpeed = tonumber(speed)
	if not numSpeed or numSpeed ~= numSpeed then
		numSpeed = 1
	end
	speed = math.clamp(numSpeed, 0.1, 3)

	-- Sesuaikan DanceStartTime agar posisi dance tetap presisi saat speed berubah.
	local oldSpeed = character:GetAttribute("DanceSpeed") or 1
	local oldStartTime = character:GetAttribute("DanceStartTime")
	if oldStartTime and oldSpeed > 0 and speed > 0 and oldSpeed ~= speed then
		local now = workspace:GetServerTimeNow()
		local elapsedPos = (now - oldStartTime) * oldSpeed
		character:SetAttribute("DanceStartTime", now - (elapsedPos / speed))
	end

	safeSetAttr(character, "DanceSpeed", speed)

	endProcessing(player)
	return "speed_changed"
end

Players.PlayerRemoving:Connect(function(player)
	processingRequests[player] = nil
	lastRequestTime[player] = nil
end)

return module
