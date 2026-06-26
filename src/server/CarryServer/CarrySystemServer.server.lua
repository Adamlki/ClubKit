--!native
--!optimize 2
-- CarrySystemServer.lua (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- 🛡️ Rate Limiter
local RateLimiter = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RateLimiter"))

-- ============================================
-- REMOTES SETUP
-- ============================================

local remoteFolder = ReplicatedStorage:FindFirstChild(CarryConfig.REMOTE_FOLDER)
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = CarryConfig.REMOTE_FOLDER
	remoteFolder.Parent = ReplicatedStorage
end

local function createRemote(name)
	local remote = remoteFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote
end

local RequestRemote  = createRemote("CarryRequest")
local ResponseRemote = createRemote("CarryResponse")
local EndRemote      = createRemote("CarryEnd")

-- ============================================
-- STATE
-- ============================================

local pendingRequests = {} -- [targetUserId] = {carrier, style, time}
local activeCarries   = {} -- bidirectional: [userId] = partnerUserId
local savedPhysics    = {} -- [userId] = { [part] = {CanCollide, Massless} }
local savedHumanoidStates = {} -- [userId] = {WalkSpeed, JumpPower, ...}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function getCharHRP(p)
	if not p or not p.Character then return nil end
	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	local hum = p.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return nil end
	return p.Character, hrp, hum
end

local function getRigType(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum and (hum.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6") or "R15"
end

local function getAttachmentPart(character)
	if getRigType(character) == "R15" then
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
	else
		return character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	end
end

-- A character is "in a carry" when Carryable is false
local function isInCarry(character)
	if not character then return false end
	local carryable = character:FindFirstChild("Carryable")
	return carryable and carryable.Value == false
end

local function canAcceptRequest(player)
	local flag = player:FindFirstChild("CanAskCarry")
	return flag and flag.Value == true
end

-- ============================================
-- WELD MANAGEMENT
-- ============================================

local function clearCarryWeld(char)
	if not char then return end
	for _, desc in ipairs(char:GetDescendants()) do
		if (desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Motor6D"))
			and (desc.Name == "CarryWeld" or desc.Name:find("Carry")) then
			desc:Destroy()
		end
	end
end

local function createCarryWeld(carrierChar, targetChar, offset)
	local carrierPart = getAttachmentPart(carrierChar)
	local targetHRP   = targetChar:FindFirstChild("HumanoidRootPart")

	if not carrierPart or not targetHRP then
		warn("[CARRY] Failed to get attachment parts")
		return nil
	end

	local adjustedOffset = offset

	-- UpperTorso sits higher than HRP; compensate so the carried player aligns correctly
	if getRigType(carrierChar) == "R15" and carrierPart.Name == "UpperTorso" then
		local hrp = carrierChar:FindFirstChild("HumanoidRootPart")
		if hrp then
			local heightDiff = carrierPart.Position.Y - hrp.Position.Y
			adjustedOffset = CFrame.new(0, -heightDiff, 0) * offset
		end
	end

	local weld = Instance.new("Weld")
	weld.Name  = "CarryWeld"
	weld.Part0 = carrierPart
	weld.Part1 = targetHRP
	weld.C0    = adjustedOffset
	weld.C1    = CFrame.new(0, 0, 0)
	weld.Parent = targetHRP

	CarryConfig.debugPrint("WELD", "Created:", carrierPart.Name, "->", targetHRP.Name, "Rig:", getRigType(carrierChar))
	return weld
end

-- ============================================
-- PHYSICS MANAGEMENT
-- ============================================

local function makeCarriedWeightless(char, userId, carrierPlayer)
	local properties = {}
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			properties[part] = { 
				CanCollide = part.CanCollide, 
				Massless = part.Massless,
				RootPriority = part.RootPriority
			}
			part.CanCollide = false
			part.Massless   = true
			part.RootPriority = -1
			
			if carrierPlayer and part:CanSetNetworkOwnership() then
				pcall(function()
					part:SetNetworkOwner(carrierPlayer)
				end)
			end
		end
	end
	savedPhysics[userId] = properties
end

local function restorePhysics(userId)
	local properties = savedPhysics[userId]
	if not properties then return end
	for part, props in pairs(properties) do
		if part and part.Parent then
			part.CanCollide = props.CanCollide
			part.Massless   = props.Massless
			if props.RootPriority then
				part.RootPriority = props.RootPriority
			end
			if part:CanSetNetworkOwnership() then
				pcall(function()
					part:SetNetworkOwnershipAuto()
				end)
			end
		end
	end
	savedPhysics[userId] = nil
end

-- ============================================
-- HUMANOID STATE MANAGEMENT
-- ============================================

local function saveHumanoidState(userId, hum)
	local actualWalkSpeed = hum.WalkSpeed

	savedHumanoidStates[userId] = {
		WalkSpeed   = actualWalkSpeed,
		JumpPower   = hum.JumpPower,
		JumpHeight  = hum.JumpHeight,
		UseJumpPower = hum.UseJumpPower,
		AutoRotate  = hum.AutoRotate
	}
end

local function applyCarriedState(hum)
	hum.WalkSpeed  = 0
	hum.AutoRotate = false
	hum.PlatformStand = true

	if hum.UseJumpPower then
		hum.JumpPower = 0
	else
		hum.JumpHeight = 0
	end

	-- Matikan SEMUA State yang bisa memberi gaya gesek/berat (Physics fix)
	local statesToDisable = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Freefall
	}
	for _, state in ipairs(statesToDisable) do
		hum:SetStateEnabled(state, false)
	end
	
	hum:ChangeState(Enum.HumanoidStateType.Physics)
end

local function restoreHumanoidState(userId, hum)
	local state = savedHumanoidStates[userId]

	if state then
		hum.WalkSpeed  = state.WalkSpeed
		hum.AutoRotate = state.AutoRotate
		if state.UseJumpPower then
			hum.JumpPower = state.JumpPower
		else
			hum.JumpHeight = state.JumpHeight
		end
		savedHumanoidStates[userId] = nil
	else
		-- Fallback defaults
		hum.WalkSpeed  = 16
		hum.AutoRotate = true
		if hum.UseJumpPower then
			hum.JumpPower = 50
		else
			hum.JumpHeight = 7.2
		end
	end

	hum.PlatformStand = false -- [FIX FISIKA]: Kembalikan keseimbangan saat diturunkan
	
	local statesToEnable = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Freefall
	}
	for _, state in ipairs(statesToEnable) do
		hum:SetStateEnabled(state, true)
	end
	
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
end

-- ============================================
-- START CARRY
-- ============================================

local function startCarry(carrier, target, style)
	CarryConfig.debugPrint("START", carrier.Name, "->", target.Name, "Style:", style)

	if not CarryConfig.isValidStyle(style) then
		return false, "Invalid style"
	end

	local cChar, cHRP, cHum = getCharHRP(carrier)
	local tChar, tHRP, tHum = getCharHRP(target)

	if not (cChar and cHRP and cHum and tChar and tHRP and tHum) then
		return false, "Character not found"
	end

	if (cHRP.Position - tHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		return false, "Too far"
	end

	if isInCarry(cChar) or isInCarry(tChar) then
		return false, "Player busy"
	end

	if carrier:GetAttribute("GlobalEffectAirborne") or target:GetAttribute("GlobalEffectAirborne") then
		return false, "Cannot carry while floating/flying"
	end

	local success, err = pcall(function()
		makeCarriedWeightless(tChar, target.UserId, carrier)
		saveHumanoidState(target.UserId, tHum)
		applyCarriedState(tHum)

		local offset       = CarryConfig.getStyleOffset(style)
		local carrierPart  = getAttachmentPart(cChar)

		tHRP.CFrame = (carrierPart or cHRP).CFrame * offset

		createCarryWeld(cChar, tChar, offset)

		cChar.Carryable.Value = false
		tChar.Carryable.Value = false
		carrier.CanAskCarry.Value = true
		target.CanAskCarry.Value  = true

		activeCarries[carrier.UserId] = target.UserId
		activeCarries[target.UserId]  = carrier.UserId

		-- Cleanup on death or character removal
		local cleanupDone = false
		local function cleanup()
			if cleanupDone then return end
			cleanupDone = true

			task.defer(function()
				activeCarries[carrier.UserId] = nil
				activeCarries[target.UserId]  = nil

				clearCarryWeld(cChar)
				clearCarryWeld(tChar)

				if cChar and cChar:FindFirstChild("Carryable") then
					cChar.Carryable.Value = true
				end
				if tChar and tChar:FindFirstChild("Carryable") then
					tChar.Carryable.Value = true
				end

				if tHum and tHum.Parent then
					restoreHumanoidState(target.UserId, tHum)
				end

				restorePhysics(target.UserId)

				EndRemote:FireClient(carrier, { cmd = "CarryEnded" })
				EndRemote:FireClient(target,  { cmd = "CarryEnded" })

				CarryConfig.debugPrint("CLEANUP", "Complete")
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
			clearCarryWeld(tChar)
			if tChar:FindFirstChild("Carryable") then tChar.Carryable.Value = true end
		end
		if cChar and cChar:FindFirstChild("Carryable") then
			cChar.Carryable.Value = true
		end
		restorePhysics(target.UserId)
		if tHum then restoreHumanoidState(target.UserId, tHum) end

		return false, tostring(err)
	end

	RequestRemote:FireClient(carrier, {
		cmd        = "CarryStarted",
		targetId   = target.UserId,
		targetName = target.DisplayName,
		style      = style
	})
	RequestRemote:FireClient(target, {
		cmd         = "BeingCarried",
		carrierId   = carrier.UserId,
		carrierName = carrier.DisplayName,
		style       = style
	})

	CarryConfig.debugPrint("SUCCESS", "Carry started successfully")
	return true
end

-- ============================================
-- END CARRY
-- ============================================

local function endCarry(player1, player2)
	-- Helper to robustly clean up a single player
	local function cleanupSinglePlayer(player)
		if not player then return end
		activeCarries[player.UserId] = nil
		
		local char, _, hum = getCharHRP(player)
		if char then
			clearCarryWeld(char)
			local carryable = char:FindFirstChild("Carryable")
			if carryable then carryable.Value = true end
		end
		
		if hum then restoreHumanoidState(player.UserId, hum) end
		restorePhysics(player.UserId)
		
		if player.Parent == Players then
			EndRemote:FireClient(player, { cmd = "CarryEnded" })
		end
	end

	cleanupSinglePlayer(player1)
	cleanupSinglePlayer(player2)

	CarryConfig.debugPrint("CLEANUP", "Robust manual end complete")
end

-- ============================================
-- PLAYER SETUP
-- ============================================

local function onPlayerAdded(plr)
	local canAskCarry = Instance.new("BoolValue")
	canAskCarry.Name   = "CanAskCarry"
	canAskCarry.Value  = true
	canAskCarry.Parent = plr

	plr.CharacterAdded:Connect(function(character)
		local carryable = Instance.new("BoolValue")
		carryable.Name   = "Carryable"
		carryable.Value  = true
		carryable.Parent = character

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			clearCarryWeld(character)
			carryable.Value   = true
			canAskCarry.Value = true
			restorePhysics(plr.UserId)
			savedHumanoidStates[plr.UserId] = nil
		end)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, plr)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- ============================================
-- PENDING REQUESTS TIMEOUT
-- ============================================

task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()

		for targetId, data in pairs(pendingRequests) do
			if now - data.time > CarryConfig.REQUEST_TIMEOUT then
				local target = Players:GetPlayerByUserId(targetId)

				if data.carrier and data.carrier.Parent == Players then
					RequestRemote:FireClient(data.carrier, { cmd = "RequestExpired" })
				end

				if target and target.Parent == Players then
					ResponseRemote:FireClient(target, { cmd = "RequestExpired" })
					target.CanAskCarry.Value = true
				end

				pendingRequests[targetId] = nil
				CarryConfig.debugPrint("TIMEOUT", "Request expired for:", targetId)
			end
		end
	end
end)

-- ============================================
-- REMOTE HANDLERS (Dengan Rate Limiting)
-- ============================================

RequestRemote.OnServerEvent:Connect(function(carrier, data)
	-- 🛡️ Rate limit check
	local allowed = RateLimiter.check(carrier, "carryRequest")
	if not allowed then return end
	
	if not data or type(data) ~= "table" then return end
	if data.cmd ~= "RequestCarry" then return end

	local targetId = data.targetId
	local style    = data.style

	if not targetId or not style then return end

	local function failRequest(reason)
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

	if not canAcceptRequest(target) or isInCarry(target.Character) or isInCarry(carrier.Character) then
		return failRequest("Player busy")
	end

	if carrier:GetAttribute("GlobalEffectAirborne") or target:GetAttribute("GlobalEffectAirborne") then
		return failRequest("Cannot carry while floating/flying")
	end

	local _, cHRP = getCharHRP(carrier)
	local _, tHRP = getCharHRP(target)
	if not (cHRP and tHRP) then
		return failRequest("Character not ready")
	end

	if (cHRP.Position - tHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		return failRequest("Too far")
	end

	if pendingRequests[target.UserId] then
		return failRequest("Target has pending request")
	end

	target.CanAskCarry.Value = false
	pendingRequests[target.UserId] = {
		carrier = carrier,
		style   = style,
		time    = os.clock()
	}

	ResponseRemote:FireClient(target, {
		cmd         = "ShowRequest",
		carrierId   = carrier.UserId,
		carrierName = carrier.DisplayName,
		style       = style
	})

	CarryConfig.debugPrint("PENDING", "Request sent to", target.Name)
end)

ResponseRemote.OnServerEvent:Connect(function(target, data)
	-- 🛡️ Rate limit check
	local allowed = RateLimiter.check(target, "carryResponse")
	if not allowed then return end
	
	if not data or type(data) ~= "table" then return end

	local pending = pendingRequests[target.UserId]
	if not pending then return end

	if data.cmd == "AcceptCarry" then
		local carrier = pending.carrier
		local style   = pending.style
		pendingRequests[target.UserId] = nil

		local success, err = startCarry(carrier, target, style)
		if not success then
			target.CanAskCarry.Value = true
			RequestRemote:FireClient(carrier, { cmd = "RequestFailed", reason = err })
			ResponseRemote:FireClient(target,  { cmd = "CarryFailed",  reason = err })
		end

	elseif data.cmd == "RejectCarry" then
		local carrier = pending.carrier
		pendingRequests[target.UserId] = nil
		target.CanAskCarry.Value = true

		RequestRemote:FireClient(carrier, {
			cmd        = "RequestRejected",
			targetName = target.DisplayName
		})
	end
end)

EndRemote.OnServerEvent:Connect(function(player, _data)
	-- 🛡️ Rate limit check
	local allowed = RateLimiter.check(player, "carryEnd")
	if not allowed then return end
	
	local char = player.Character
	if not char or not isInCarry(char) then return end

	local partnerUserId = activeCarries[player.UserId]
	if not partnerUserId then
		CarryConfig.debugPrint("ERROR", "No active carry found for", player.Name)
		return
	end

	local partner = Players:GetPlayerByUserId(partnerUserId)
	if not partner then
		-- Partner has left the game, but we must still clean up ourselves!
		activeCarries[player.UserId] = nil
		clearCarryWeld(char)
		if char:FindFirstChild("Carryable") then char.Carryable.Value = true end
		local _, _, hum = getCharHRP(player)
		if hum then restoreHumanoidState(player.UserId, hum) end
		restorePhysics(player.UserId)
		EndRemote:FireClient(player, { cmd = "CarryEnded" })
		return
	end

	endCarry(player, partner)
end)

-- ============================================
-- PLAYER EVENTS
-- ============================================

Players.PlayerRemoving:Connect(function(player)
	pendingRequests[player.UserId] = nil

	-- 🔥 ARCHITECT FIX: Jika pemain yang keluar adalah carrier dari request pending orang lain
	for targetId, data in pairs(pendingRequests) do
		if data.carrier and data.carrier.UserId == player.UserId then
			local target = Players:GetPlayerByUserId(targetId)
			if target and target.Parent == Players then
				target.CanAskCarry.Value = true
			end
			pendingRequests[targetId] = nil
		end
	end

	local partnerUserId = activeCarries[player.UserId]
	if partnerUserId then
		local partner = Players:GetPlayerByUserId(partnerUserId)
		if partner then
			endCarry(player, partner)
		else
			activeCarries[player.UserId]  = nil
			activeCarries[partnerUserId]  = nil
		end
	end

	if player.Character then
		clearCarryWeld(player.Character)
	end

	restorePhysics(player.UserId)
	savedHumanoidStates[player.UserId] = nil
end)

-- ============================================
-- GLOBAL BINDABLES
-- ============================================
local ServerStorage = game:GetService("ServerStorage")
local CarryEventsFolder = ServerStorage:FindFirstChild("CarryEvents")
if not CarryEventsFolder then
	CarryEventsFolder = Instance.new("Folder")
	CarryEventsFolder.Name = "CarryEvents"
	CarryEventsFolder.Parent = ServerStorage
end

local ForceEndCarryFunc = CarryEventsFolder:FindFirstChild("ForceEndCarryFunc")
if not ForceEndCarryFunc then
	ForceEndCarryFunc = Instance.new("BindableFunction")
	ForceEndCarryFunc.Name = "ForceEndCarryFunc"
	ForceEndCarryFunc.Parent = CarryEventsFolder
end

ForceEndCarryFunc.OnInvoke = function(player)
	if not player then return false end
	local partnerUserId = activeCarries[player.UserId]
	if not partnerUserId then return false end
	local partner = Players:GetPlayerByUserId(partnerUserId)
	if partner then
		endCarry(player, partner)
		return true
	end
	return false
end

-- ============================================
-- INITIALIZATION
-- ============================================

CarryConfig.debugPrint("SERVER", "Carry System Initialized")