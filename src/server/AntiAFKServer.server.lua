--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local RemoteEventManager = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("RemoteEventManager"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local antiAFKRejoinEvent = remotesFolder:FindFirstChild("AntiAFKRejoin")
if not antiAFKRejoinEvent then
	antiAFKRejoinEvent = Instance.new("RemoteEvent")
	antiAFKRejoinEvent.Name = "AntiAFKRejoin"
	antiAFKRejoinEvent.Parent = remotesFolder
end

-- MEMORYSTORE FOR SECURE SERVER-SIDE POSITION CACHING
local afkPositionsMap = nil
local isMemoryStoreAvailable = false
local AFK_POSITION_TTL = 180 
local MAX_MAP_BOUND = 10000 
local MIN_Y_BOUND = -50  
local MAX_Y_BOUND = 2000  

local function initMemoryStore()
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap("AFK_Positions_v1")
	end)
	if ok and map then
		afkPositionsMap = map
		isMemoryStoreAvailable = true
	else
		isMemoryStoreAvailable = false
	end
end

initMemoryStore()

local function saveServerPosition(userId: number, components: {number})
	if not isMemoryStoreAvailable or not afkPositionsMap then return end
	local key = string.format("pos_%d", userId)
	pcall(function()
		afkPositionsMap:SetAsync(key, components, AFK_POSITION_TTL)
	end)
end

local function popServerPosition(userId: number): {number}?
	if not isMemoryStoreAvailable or not afkPositionsMap then return nil end
	local key = string.format("pos_%d", userId)
	local ok, data = pcall(function()
		return afkPositionsMap:GetAsync(key)
	end)
	if not ok or type(data) ~= "table" or #data ~= 12 then
		return nil
	end
	pcall(function()
		afkPositionsMap:RemoveAsync(key)
	end)
	return data
end

local function validateCFrameComponents(comp: any): CFrame?
	if type(comp) ~= "table" or #comp ~= 12 then return nil end
	for i = 1, 12 do
		local v = comp[i]
		if type(v) ~= "number" or v ~= v or math.abs(v) > MAX_MAP_BOUND then
			return nil
		end
	end
	local cf = CFrame.new(table.unpack(comp))
	local pos = cf.Position
	if pos.Magnitude > MAX_MAP_BOUND or pos.Y < MIN_Y_BOUND or pos.Y > MAX_Y_BOUND then
		return nil
	end
	return cf
end

-- POSITION RESTORATION ON REJOIN
local function handlePlayerJoin(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData

	if teleportData and type(teleportData) == "table" and teleportData.isAfkRejoin then
		player:SetAttribute("IsAfkRejoin", true)
	end

	local targetCFrame: CFrame? = nil
	if teleportData and type(teleportData) == "table" and teleportData.isAfkRejoin then
		local savedComponents = popServerPosition(player.UserId)
		if savedComponents then
			targetCFrame = validateCFrameComponents(savedComponents)
		end
	end

	if targetCFrame then
		local connection: RBXScriptConnection?
		connection = player.CharacterAdded:Connect(function(character)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			task.wait(0.5)
			local rootPart = character:WaitForChild("HumanoidRootPart", 8)
			if rootPart and character.Parent then
				character:PivotTo(targetCFrame)
				print(string.format("[AntiAFKServer] 📍 Sukses mengembalikan posisi AFK %s ke (%d, %d, %d)",
					player.Name,
					math.floor(targetCFrame.Position.X),
					math.floor(targetCFrame.Position.Y),
					math.floor(targetCFrame.Position.Z)
				))
			end
		end)

		player.AncestryChanged:Connect(function(_, parent)
			if not parent and connection then
				connection:Disconnect()
				connection = nil
			end
		end)

		if player.Character then
			task.spawn(function()
				task.wait(0.5)
				local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
				if rootPart and player.Character.Parent then
					player.Character:PivotTo(targetCFrame)
				end
			end)
		end
	end
end

Players.PlayerAdded:Connect(handlePlayerJoin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(handlePlayerJoin, p)
end

-- AUTO-REJOIN REQUEST HANDLER
antiAFKRejoinEvent.OnServerEvent:Connect(function(player: Player)
	if not RemoteEventManager.checkRateLimit(player, "antiAfkRejoin") then return end
	print(string.format("[AntiAFKServer] 🔄 Permintaan Auto-Rejoin diterima dari %s", player.Name))

	if RunService:IsStudio() then
		warn(string.format("[AntiAFKServer] (Roblox Studio) Simulasi Rejoin untuk %s berhasil dicatat. Teleportasi fisik dinonaktifkan di Studio.", player.Name))
		return
	end

	local cframeComponents: {number}? = nil
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			cframeComponents = { rootPart.CFrame:GetComponents() }
		end
	end

	if cframeComponents then
		saveServerPosition(player.UserId, cframeComponents)
	end

	local teleportData = {
		isAfkRejoin = true,
		rejoinTimestamp = os.time(),
		originalJobId = game.JobId,
	}

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData(teleportData)

	if #Players:GetPlayers() > 1 and game.JobId ~= "" then
		teleportOptions.ServerInstanceId = game.JobId
	end

	local success, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, teleportOptions)
	end)

	if not success then
		warn(string.format("[AntiAFKServer] TeleportAsync gagal untuk %s: %s. Mencoba fallback...", player.Name, tostring(err)))
		pcall(function()
			if #Players:GetPlayers() > 1 and game.JobId ~= "" then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player, nil, teleportData)
			else
				TeleportService:Teleport(game.PlaceId, player, teleportData)
			end
		end)
	else
		print(string.format("[AntiAFKServer] 🚀 TeleportAsync berhasil diinisiasi untuk %s", player.Name))
	end
end)

print("[AntiAFKServer] ✅ Anti-AFK Server & Restore Position Handler initialized.")
