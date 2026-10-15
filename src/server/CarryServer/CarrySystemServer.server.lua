--!native
--!optimize 2
-- ============================================================
-- CarrySystemServer (Server Controller)
-- Coordinates carry requests, responses, and session lifecycles
-- Refactored for SOLID (SRP) using CarryState & CarryPhysics
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))
local RateLimiter = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local CarryState = require(script.Parent:WaitForChild("Modules"):WaitForChild("CarryState"))
local CarryPhysics = require(script.Parent:WaitForChild("Modules"):WaitForChild("CarryPhysics"))

-- ============================================
-- REMOTES SETUP
-- ============================================
local remoteFolder = ReplicatedStorage:FindFirstChild(CarryConfig.REMOTE_FOLDER)
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = CarryConfig.REMOTE_FOLDER
	remoteFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remote = remoteFolder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote :: RemoteEvent
end

local RequestRemote = getOrCreateRemote("CarryRequest")
local ResponseRemote = getOrCreateRemote("CarryResponse")
local EndRemote = getOrCreateRemote("CarryEnd")

-- ============================================
-- CORE CARRY ACTIONS
-- ============================================

local function endCarry(player1: Player?, player2: Player?)
	local function cleanupPlayer(p: Player?)
		if not p then return end
		CarryState.clearActiveCarry(p.UserId)
		CarryPhysics.detachAntiWeightListener(p.UserId)

		local char, _, hum = CarryPhysics.getCharHRP(p)
		if char then
			CarryPhysics.clearCarryWeld(char)
			local carryable = char:FindFirstChild("Carryable") :: BoolValue?
			if carryable then carryable.Value = true end
		end

		if hum then CarryPhysics.restoreHumanoidState(p.UserId, hum) end
		CarryPhysics.restorePhysics(p.UserId)

		if p.Parent == Players then
			EndRemote:FireClient(p, { cmd = "CarryEnded" })
		end
	end

	cleanupPlayer(player1)
	cleanupPlayer(player2)
	CarryConfig.debugPrint("CLEANUP", "Carry session ended cleanly")
end

local function startCarry(carrier: Player, target: Player, style: string): (boolean, string?)
	CarryConfig.debugPrint("START", carrier.Name, "->", target.Name, "Style:", style)

	if not CarryConfig.isValidStyle(style) then
		return false, "Invalid style"
	end

	local cChar, cHRP, cHum = CarryPhysics.getCharHRP(carrier)
	local tChar, tHRP, tHum = CarryPhysics.getCharHRP(target)

	if not (cChar and cHRP and cHum and tChar and tHRP and tHum) then
		return false, "Character not found"
	end

	if (cHRP.Position - tHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		return false, "Too far"
	end

	if CarryState.isInCarry(cChar) or CarryState.isInCarry(tChar) then
		return false, "Player busy"
	end

	if carrier:GetAttribute("GlobalEffectAirborne") or target:GetAttribute("GlobalEffectAirborne") then
		return false, "Cannot carry while floating/flying"
	end

	local success, err = pcall(function()
		CarryPhysics.makeCarriedWeightless(tChar, target.UserId, carrier)
		CarryPhysics.saveHumanoidState(target.UserId, tHum)
		CarryPhysics.applyCarriedState(tHum)
		CarryPhysics.attachAntiWeightListener(target.UserId, tChar)

		local offset = CarryConfig.getStyleOffset(style, cChar, tChar)
		local carrierPart = CarryPhysics.getAttachmentPart(cChar)

		tHRP.CFrame = (carrierPart or cHRP).CFrame * offset
		CarryPhysics.createCarryWeld(cChar, tChar, offset)

		local cCarryable = cChar:FindFirstChild("Carryable") :: BoolValue?
		local tCarryable = tChar:FindFirstChild("Carryable") :: BoolValue?
		if cCarryable then cCarryable.Value = false end
		if tCarryable then tCarryable.Value = false end

		local cAsk = carrier:FindFirstChild("CanAskCarry") :: BoolValue?
		local tAsk = target:FindFirstChild("CanAskCarry") :: BoolValue?
		if cAsk then cAsk.Value = true end
		if tAsk then tAsk.Value = true end

		CarryState.setActiveCarry(carrier.UserId, target.UserId)

		local cleanupDone = false
		local function cleanup()
			if cleanupDone then return end
			if CarryState.getActivePartner(carrier.UserId) ~= target.UserId then return end
			cleanupDone = true

			task.defer(function()
				endCarry(carrier, target)
			end)
		end

		cHum.Died:Once(cleanup)
		tHum.Died:Once(cleanup)
		cChar.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
		tChar.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() end end)
	end)

	if not success then
		CarryConfig.debugPrint("ERROR", "Start failed:", err)
		if tChar then
			CarryPhysics.clearCarryWeld(tChar)
			local tCarryable = tChar:FindFirstChild("Carryable") :: BoolValue?
			if tCarryable then tCarryable.Value = true end
		end
		if cChar then
			local cCarryable = cChar:FindFirstChild("Carryable") :: BoolValue?
			if cCarryable then cCarryable.Value = true end
		end
		CarryPhysics.restorePhysics(target.UserId)
		if tHum then CarryPhysics.restoreHumanoidState(target.UserId, tHum) end

		return false, tostring(err)
	end

	RequestRemote:FireClient(carrier, {
		cmd = "CarryStarted",
		targetId = target.UserId,
		targetName = target.DisplayName,
		style = style,
	})
	RequestRemote:FireClient(target, {
		cmd = "BeingCarried",
		carrierId = carrier.UserId,
		carrierName = carrier.DisplayName,
		style = style,
	})

	CarryConfig.debugPrint("SUCCESS", "Carry started successfully")
	return true
end

-- ============================================
-- PLAYER SETUP
-- ============================================

local function onPlayerAdded(plr: Player)
	local canAskCarry = plr:FindFirstChild("CanAskCarry") :: BoolValue? or Instance.new("BoolValue")
	canAskCarry.Name = "CanAskCarry"
	canAskCarry.Value = true
	canAskCarry.Parent = plr

	local function onCharacter(character: Model)
		local carryable = character:FindFirstChild("Carryable") :: BoolValue? or Instance.new("BoolValue")
		carryable.Name = "Carryable"
		carryable.Value = true
		carryable.Parent = character

		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				CarryPhysics.clearCarryWeld(character)
				carryable.Value = true
				canAskCarry.Value = true
				CarryPhysics.restorePhysics(plr.UserId)
			end)
		end
	end

	if plr.Character then
		task.spawn(onCharacter, plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacter)
end

for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, plr)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- ============================================
-- PENDING REQUESTS TIMEOUT LOOP
-- ============================================

task.spawn(function()
	while true do
		task.wait(5)
		CarryState.cleanupExpiredRequests(CarryConfig.REQUEST_TIMEOUT, function(targetId, data)
			local target = Players:GetPlayerByUserId(targetId)
			if data.carrier and data.carrier.Parent == Players then
				RequestRemote:FireClient(data.carrier, { cmd = "RequestExpired" })
			end
			if target and target.Parent == Players then
				ResponseRemote:FireClient(target, { cmd = "RequestExpired" })
				local canAsk = target:FindFirstChild("CanAskCarry") :: BoolValue?
				if canAsk then canAsk.Value = true end
			end
			CarryConfig.debugPrint("TIMEOUT", "Request expired for:", targetId)
		end)
	end
end)

-- ============================================
-- REMOTE EVENT LISTENERS
-- ============================================

RequestRemote.OnServerEvent:Connect(function(carrier, data)
	local allowed = RateLimiter.check(carrier, "carryRequest")
	if not allowed then return end

	if not data or type(data) ~= "table" then return end
	if data.cmd ~= "RequestCarry" then return end

	local targetId = data.targetId
	local style = data.style
	if not targetId or not style then return end

	local function failRequest(reason: string)
		RequestRemote:FireClient(carrier, { cmd = "RequestFailed", reason = reason })
	end

	if not CarryConfig.isValidStyle(style) then
		return failRequest("Invalid style")
	end

	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == carrier then
		return failRequest("Invalid target")
	end

	if not carrier.Character or not target.Character then
		return failRequest("Character not ready")
	end

	if not CarryState.canAcceptRequest(target) or CarryState.isInCarry(target.Character) or CarryState.isInCarry(carrier.Character) then
		return failRequest("Player busy")
	end

	if carrier:GetAttribute("GlobalEffectAirborne") or target:GetAttribute("GlobalEffectAirborne") then
		return failRequest("Cannot carry while floating/flying")
	end

	local _, cHRP = CarryPhysics.getCharHRP(carrier)
	local _, tHRP = CarryPhysics.getCharHRP(target)
	if not (cHRP and tHRP) then
		return failRequest("Character not ready")
	end

	if (cHRP.Position - tHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		return failRequest("Too far")
	end

	if CarryState.getPending(target.UserId) then
		return failRequest("Target has pending request")
	end

	local targetCanAsk = target:FindFirstChild("CanAskCarry") :: BoolValue?
	if targetCanAsk then targetCanAsk.Value = false end

	CarryState.setPending(target.UserId, carrier, style)

	ResponseRemote:FireClient(target, {
		cmd = "ShowRequest",
		carrierId = carrier.UserId,
		carrierName = carrier.DisplayName,
		style = style,
	})

	CarryConfig.debugPrint("PENDING", "Request sent to", target.Name)
end)

ResponseRemote.OnServerEvent:Connect(function(target, data)
	local allowed = RateLimiter.check(target, "carryResponse")
	if not allowed then return end

	if not data or type(data) ~= "table" then return end

	local pending = CarryState.getPending(target.UserId)
	if not pending then return end

	local targetCanAsk = target:FindFirstChild("CanAskCarry") :: BoolValue?

	if data.cmd == "AcceptCarry" then
		local carrier = pending.carrier
		local style = pending.style
		CarryState.removePending(target.UserId)

		local success, err = startCarry(carrier, target, style)
		if not success then
			if targetCanAsk then targetCanAsk.Value = true end
			RequestRemote:FireClient(carrier, { cmd = "RequestFailed", reason = err })
			ResponseRemote:FireClient(target, { cmd = "CarryFailed", reason = err })
		end

	elseif data.cmd == "RejectCarry" then
		local carrier = pending.carrier
		CarryState.removePending(target.UserId)
		if targetCanAsk then targetCanAsk.Value = true end

		RequestRemote:FireClient(carrier, {
			cmd = "RequestRejected",
			targetName = target.DisplayName,
		})
	end
end)

EndRemote.OnServerEvent:Connect(function(player, _data)
	local allowed = RateLimiter.check(player, "carryEnd")
	if not allowed then return end

	local char = player.Character
	if not char or not CarryState.isInCarry(char) then return end

	local partnerUserId = CarryState.getActivePartner(player.UserId)
	if not partnerUserId then
		CarryConfig.debugPrint("ERROR", "No active carry found for", player.Name)
		return
	end

	local partner = Players:GetPlayerByUserId(partnerUserId)
	if not partner then
		CarryState.clearActiveCarry(player.UserId)
		CarryPhysics.clearCarryWeld(char)
		local carryable = char:FindFirstChild("Carryable") :: BoolValue?
		if carryable then carryable.Value = true end

		local _, _, hum = CarryPhysics.getCharHRP(player)
		if hum then CarryPhysics.restoreHumanoidState(player.UserId, hum) end
		CarryPhysics.restorePhysics(player.UserId)

		EndRemote:FireClient(player, { cmd = "CarryEnded" })
		return
	end

	endCarry(player, partner)
end)

-- ============================================
-- PLAYER REMOVING & CLEANUP
-- ============================================

Players.PlayerRemoving:Connect(function(player)
	CarryState.removePending(player.UserId)
	CarryState.clearPendingForCarrier(player.UserId, function(target)
		local canAsk = target:FindFirstChild("CanAskCarry") :: BoolValue?
		if canAsk then canAsk.Value = true end
	end)

	local partnerUserId = CarryState.getActivePartner(player.UserId)
	if partnerUserId then
		local partner = Players:GetPlayerByUserId(partnerUserId)
		if partner then
			endCarry(player, partner)
		else
			CarryState.clearActiveCarry(player.UserId)
		end
	end

	if player.Character then
		CarryPhysics.clearCarryWeld(player.Character)
	end

	CarryPhysics.cleanupPlayer(player.UserId)
end)

-- ============================================
-- GLOBAL BINDABLES
-- ============================================
local CarryEventsFolder = ServerStorage:FindFirstChild("CarryEvents")
if not CarryEventsFolder then
	CarryEventsFolder = Instance.new("Folder")
	CarryEventsFolder.Name = "CarryEvents"
	CarryEventsFolder.Parent = ServerStorage
end

local ForceEndCarryFunc = CarryEventsFolder:FindFirstChild("ForceEndCarryFunc") :: BindableFunction?
if not ForceEndCarryFunc then
	ForceEndCarryFunc = Instance.new("BindableFunction")
	ForceEndCarryFunc.Name = "ForceEndCarryFunc"
	ForceEndCarryFunc.Parent = CarryEventsFolder
end

ForceEndCarryFunc.OnInvoke = function(player: Player?)
	if not player then return false end
	local partnerUserId = CarryState.getActivePartner(player.UserId)
	if not partnerUserId then return false end
	local partner = Players:GetPlayerByUserId(partnerUserId)
	if partner then
		endCarry(player, partner)
		return true
	end
	return false
end

CarryConfig.debugPrint("SERVER", "Carry System Initialized (Modular)")