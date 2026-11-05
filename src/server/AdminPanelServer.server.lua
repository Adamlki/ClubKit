local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")

local RoleSystem  = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))
local CustomTeams = require(ServerStorage:WaitForChild("Modules"):WaitForChild("CustomTeams"))
local TeamGroups  = require(ServerStorage:WaitForChild("Modules"):WaitForChild("TeamGroups"))

local COOLDOWN_TIME = 1
local playerCooldowns = {}

local function isSpamming(player, actionName)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then return true end

	local userCooldowns = playerCooldowns[player.UserId]
	if not userCooldowns then
		userCooldowns = {}
		playerCooldowns[player.UserId] = userCooldowns
	end

	local now = os.clock()
	if now - (userCooldowns[actionName] or 0) < COOLDOWN_TIME then
		return true
	end
	userCooldowns[actionName] = now
	return false
end

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)

local adminPanelRemotes = ReplicatedStorage:FindFirstChild("AdminPanelRemotes")
if not adminPanelRemotes then
	adminPanelRemotes = Instance.new("Folder")
	adminPanelRemotes.Name = "AdminPanelRemotes"
	adminPanelRemotes.Parent = ReplicatedStorage
end

local function ensureRemote(className, name)
	local r = adminPanelRemotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = adminPanelRemotes
	end
	return r
end

local GetTeamListRemote             = ensureRemote("RemoteFunction", "GetTeamList")
local GetColorTemplatesRemote         = ensureRemote("RemoteFunction", "GetColorTemplates")
local TeamActionRemote                = ensureRemote("RemoteEvent", "TeamAction")
local TeamActionResultRemote          = ensureRemote("RemoteEvent", "TeamActionResult")
local GetSpotlightSettingsRemote    = ensureRemote("RemoteFunction", "GetSpotlightSettings")
local UpdateSpotlightSettingsRemote = ensureRemote("RemoteFunction", "UpdateSpotlightSettings")

local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
if not DonorSpotlightRemote then
	DonorSpotlightRemote = Instance.new("RemoteEvent")
	DonorSpotlightRemote.Name = "DonorSpotlightRemote"
	DonorSpotlightRemote.Parent = ReplicatedStorage
end

local spotlightFolder = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
if not spotlightFolder then
	spotlightFolder = Instance.new("Folder")
	spotlightFolder.Name = "DonationSpotlightSettings"
	spotlightFolder.Parent = ReplicatedStorage
end

if spotlightFolder:GetAttribute("Enabled") == nil then spotlightFolder:SetAttribute("Enabled", false) end
if spotlightFolder:GetAttribute("MinRobux") == nil then spotlightFolder:SetAttribute("MinRobux", 500) end
if spotlightFolder:GetAttribute("MinSaweria") == nil then spotlightFolder:SetAttribute("MinSaweria", 50000) end

local function isOwnerOrAdmin(p)
	if RunService:IsStudio() then return true end
	local r = RoleSystem:GetPlayerRole(p)
	return r == "Owner" or r == "Admin"
end

local function isAdminOrMod(p)
	if RunService:IsStudio() then return true end
	local r = RoleSystem:GetPlayerRole(p)
	return r == "Owner" or r == "Admin" or r == "Moderator"
end

GetColorTemplatesRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetColors") then return {} end

	local templates = {}
	for _, tmpl in ipairs(TeamGroups.COLOR_TEMPLATES) do
		table.insert(templates, {
			name = tmpl.name,
			brickColorName = tmpl.brickColorName,
		})
	end
	return templates
end

GetTeamListRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetTeams") or not isAdminOrMod(sender) then return {} end
	return CustomTeams.GetTeamList()
end

local ACTION_HANDLERS = {
	MovePlayer = function(sender, data)
		local targetId = tonumber(data.targetUserId)
		if not targetId then return false, "ID Player tidak valid!" end
		local target = Players:GetPlayerByUserId(targetId)
		if not target then return false, "Player tidak ditemukan!" end
		return CustomTeams.MovePlayer(sender, target, data.teamName)
	end,
	CreateTeam = function(sender, data)
		if not data.teamName or data.teamName:match("^%s*$") then
			return false, "Nama team kosong!"
		end
		return CustomTeams.CreateTeam(sender, data.teamName, data.colorName)
	end,
	DeleteTeam = function(sender, data)
		if not data.teamName or data.teamName:match("^%s*$") then
			return false, "Nama team kosong!"
		end
		return CustomTeams.DeleteTeam(sender, data.teamName)
	end,
}

TeamActionRemote.OnServerEvent:Connect(function(sender, data)
	if isSpamming(sender, "Action") then
		TeamActionResultRemote:FireClient(sender, { success = false, message = "Tunggu 1 detik! Jangan spam klik." })
		return
	end

	if not data or type(data) ~= "table" then return end
	if not isOwnerOrAdmin(sender) then
		TeamActionResultRemote:FireClient(sender, { success = false, message = "Akses ditolak!" })
		return
	end

	local handler = ACTION_HANDLERS[data.action]
	if not handler then
		TeamActionResultRemote:FireClient(sender, { success = false, message = "Aksi tidak dikenal." })
		return
	end

	local ok, msg = handler(sender, data)
	TeamActionResultRemote:FireClient(sender, { success = ok, message = msg })
end)

local function getSpotlightData()
	return {
		Enabled = spotlightFolder:GetAttribute("Enabled") == true,
		MinRobux = spotlightFolder:GetAttribute("MinRobux") or 500,
		MinSaweria = spotlightFolder:GetAttribute("MinSaweria") or 50000,
	}
end

GetSpotlightSettingsRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetSpotlight") then
		return getSpotlightData()
	end
	return getSpotlightData()
end

UpdateSpotlightSettingsRemote.OnServerInvoke = function(sender, newSettings)
	if not sender or isSpamming(sender, "UpdateSpotlight") then
		return { success = false, message = "Tunggu 1 detik! Jangan spam." }
	end
	if not isOwnerOrAdmin(sender) then
		return { success = false, message = "Akses ditolak! Hanya Admin/Owner yang dapat mengubah konfigurasi ini." }
	end
	if type(newSettings) ~= "table" then
		return { success = false, message = "Format data tidak valid." }
	end

	local enabled = (newSettings.Enabled == true)
	local minRobux = math.max(1, math.floor(tonumber(newSettings.MinRobux) or 500))
	local minSaweria = math.max(1, math.floor(tonumber(newSettings.MinSaweria) or 50000))

	spotlightFolder:SetAttribute("Enabled", enabled)
	spotlightFolder:SetAttribute("MinRobux", minRobux)
	spotlightFolder:SetAttribute("MinSaweria", minSaweria)

	return {
		success = true,
		message = string.format("Pengaturan server tersimpan: %s | Min Robux: %d | Min Saweria: Rp %d",
			enabled and "AKTIF" or "NONAKTIF", minRobux, minSaweria
		),
	}
end
