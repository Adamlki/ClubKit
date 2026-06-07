local TeamGroups = {}

local Teams         = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

-- ====================================
-- COLOR TEMPLATES (MENGGUNAKAN NAMA WARNA ROBLOX)
-- ====================================
TeamGroups.COLOR_TEMPLATES = {
	{ name = "Merah",       brickColorName = "Bright red" },
	{ name = "Oranye",      brickColorName = "Deep orange" },
	{ name = "Kuning",      brickColorName = "New Yeller" },
	{ name = "Hijau",       brickColorName = "Dark green" },
	{ name = "Hijau Tua",   brickColorName = "Earth green" },
	{ name = "Cyan",        brickColorName = "Cyan" },
	{ name = "Biru",        brickColorName = "Bright blue" },
	{ name = "Biru Tua",    brickColorName = "Navy blue" },
	{ name = "Ungu",        brickColorName = "Royal purple" },
	{ name = "Pink",        brickColorName = "Hot pink" },
	{ name = "Putih",       brickColorName = "White" },
	{ name = "Abu-abu",     brickColorName = "Medium stone grey" },
	{ name = "Hitam",       brickColorName = "Really black" },
	{ name = "Emas",        brickColorName = "Bright yellow" },
	{ name = "Perak",       brickColorName = "Silver" },
	{ name = "Coklat",      brickColorName = "Brown" },
}

TeamGroups.templateByName = {}
for _, t in ipairs(TeamGroups.COLOR_TEMPLATES) do
	TeamGroups.templateByName[t.name:lower()] = t
end

-- ====================================
-- CONFIG
-- ====================================
TeamGroups.Config = {
	Teams = {
		Owner     = { TeamName = "Owner",      ColorName = "Merah",   PaletteIndex = 40, Order = 1 },
		Admin     = { TeamName = "Head Staff", ColorName = "Oranye",  PaletteIndex = 41, Order = 2 },
		Moderator = { TeamName = "Staff",      ColorName = "Biru",    PaletteIndex = 42, Order = 3 },
		-- Tim Sultan (Prioritas di atas VVIP)
		Sultan    = { TeamName = "Sultan",     ColorName = "Emas",    PaletteIndex = 46, Order = 4 }, 
		VVIP      = { TeamName = "VVIP",       ColorName = "Ungu",    PaletteIndex = 43, Order = 5 },
		VIP       = { TeamName = "VIP",        ColorName = "Hijau",   PaletteIndex = 44, Order = 6 },
		Player    = { TeamName = "Tamu",       ColorName = "Abu-abu", PaletteIndex = 45, Order = 7 },
	},
	TEAM_PALETTE_START   = 40,
	CUSTOM_PALETTE_START = 50,
	DEBUG_ENABLED        = false,
}

do
	local seen = {}
	for roleName, cfg in pairs(TeamGroups.Config.Teams) do
		if seen[cfg.PaletteIndex] then
			warn(string.format("[TeamGroups] DUPLICATE default PaletteIndex %d!", cfg.PaletteIndex))
		else
			seen[cfg.PaletteIndex] = roleName
		end
	end
end

local teamObjects = {}
local hasOverrideFn = nil

local function debugPrint(...)
	if TeamGroups.Config.DEBUG_ENABLED then print("[TeamGroups]", ...) end
end

-- ====================================
-- CORE: BUAT TEAM MENGGUNAKAN BRICKCOLOR
-- ====================================
local function makeTeam(teamName, brickColorName, paletteIndex)
	local bc = BrickColor.new(brickColorName)
	local team          = Instance.new("Team")
	team.Name           = teamName
	team.TeamColor      = bc
	team.AutoAssignable = false
	team.Parent         = Teams

	team:SetAttribute("PaletteIndex", paletteIndex)

	return team
end

TeamGroups.MakeTeam = makeTeam

function TeamGroups.NextFreePaletteIndex()
	local used = {}
	for _, t in ipairs(Teams:GetTeams()) do
		local idx = t:GetAttribute("PaletteIndex")
		if idx then used[idx] = true end
	end
	for _, cfg in pairs(TeamGroups.Config.Teams) do
		used[cfg.PaletteIndex] = true
	end

	local start = TeamGroups.Config.CUSTOM_PALETTE_START
	for i = start, 194 do
		if not used[i] then return i end
	end
	return start
end

function TeamGroups.GetTemplateColorName(colorName)
	local t = TeamGroups.templateByName[colorName:lower()]
	if t then return t.brickColorName end
	return "Medium stone grey"
end

-- ====================================
-- assignByRole (DENGAN LOGIKA SULTAN)
-- ====================================
local function assignByRole(player)
	local role = RoleSystem:GetPlayerRole(player)

	-- Petinggi tidak boleh turun kasta
	local isStaff = (role == "Owner" or role == "Admin" or role == "Moderator")

	-- Jika player Sultan DAN bukan Petinggi, timpa jadi tim Sultan
	if player:GetAttribute("IsSultan") and not isStaff then
		local team = teamObjects["Sultan"]
		if team and team.Parent then
			player.Team = team
			debugPrint(string.format("Assigned %s -> '%s' (Sultan Override)", player.Name, team.Name))
			return
		end
	end

	-- Logika normal (Untuk Staff, VVIP, VIP, atau Player biasa)
	local team = teamObjects[role] or teamObjects["Player"]
	if team and team.Parent then
		player.Team = team
		debugPrint(string.format("Assigned %s -> '%s' (role: %s)", player.Name, team.Name, role))
	else
		warn(string.format("[TeamGroups] Team tidak ditemukan untuk role: %s", role))
	end
end

function TeamGroups.CreateDefaultTeams()
	for _, t in ipairs(Teams:GetTeams()) do t:Destroy() end
	teamObjects = {}

	local sorted = {}
	for roleName, cfg in pairs(TeamGroups.Config.Teams) do
		table.insert(sorted, { RoleName = roleName, Config = cfg })
	end
	table.sort(sorted, function(a, b) return a.Config.Order < b.Config.Order end)

	for _, entry in ipairs(sorted) do
		local brickColorName = TeamGroups.GetTemplateColorName(entry.Config.ColorName)
		local team = makeTeam(entry.Config.TeamName, brickColorName, entry.Config.PaletteIndex)
		teamObjects[entry.RoleName] = team
	end
end

function TeamGroups.Init(hasOverride)
	hasOverrideFn = hasOverride
	TeamGroups.RefreshTeamObjects()

	RoleSystem.RoleChanged:Connect(function(player, _, _)
		if hasOverrideFn and hasOverrideFn(player.UserId) then
			return
		end
		assignByRole(player)
	end)
end

function TeamGroups.AssignPlayer(player)
	assignByRole(player)
end

function TeamGroups.RefreshTeamObjects()
	local teamNameToRole = {}
	for roleName, cfg in pairs(TeamGroups.Config.Teams) do
		teamNameToRole[cfg.TeamName] = roleName
	end
	teamObjects = {}
	for _, t in ipairs(Teams:GetTeams()) do
		local roleName = teamNameToRole[t.Name]
		if roleName then
			teamObjects[roleName] = t
		end
	end
end

TeamGroups.UpdatePlayer = TeamGroups.AssignPlayer

return TeamGroups