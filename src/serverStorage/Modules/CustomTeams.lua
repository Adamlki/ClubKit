local CustomTeams = {}

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local ServerStorage     = game:GetService("ServerStorage")
local DataStoreEnv     = require(script.Parent:WaitForChild("DataStoreEnv"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService       = game:GetService("TextService")
local RunService        = game:GetService("RunService")

local ServerScriptService = game:GetService("ServerScriptService")
local ServerConfig       = require(ServerScriptService:WaitForChild("Config"):WaitForChild("ServerConfig"))
local RoleSystem = require(ServerStorage.Modules.RoleSystem)
local TeamGroups = require(ServerStorage.Modules.TeamGroups)

CustomTeams.Config = {
	DATASTORE_NAME  = "CustomTeamsData_v2",
	DATASTORE_RETRY = 3,
	DATASTORE_DELAY = 1,
	DEBUG_ENABLED   = false,
	ALLOWED_ROLES   = { "Owner", "Admin" },
	PREFIX          = ";",
	NOTIF_DURATION  = 5,
}

local store, writeStore  = DataStoreEnv.Get(CustomTeams.Config.DATASTORE_NAME)
local customTeamObjects = {}  
local playerOverrides   = {}  
local assignedPlayers   = {}
local teamsByName       = {}  
local notifyRemote      = nil

local hiddenTeams      = {} 
local refreshScheduled = false

local function debugPrint(...)
	if CustomTeams.Config.DEBUG_ENABLED then print("[CustomTeams]", ...) end
end

local function dsRetry(operation)
	for i = 1, CustomTeams.Config.DATASTORE_RETRY do
		local ok, result = pcall(operation)
		if ok then return true, result end
		if i < CustomTeams.Config.DATASTORE_RETRY then
			task.wait(CustomTeams.Config.DATASTORE_DELAY)
		end
	end
	return false, nil
end

local function dsGet(key)
	local ok, result = dsRetry(function() return store:GetAsync(key) end)
	if ok then return result end
	return nil
end

local function dsSet(key, val)
	local ok = dsRetry(function() writeStore:SetAsync(key, val) end)
	return ok
end

local function dsRemove(key)
	local ok = dsRetry(function() store:RemoveAsync(key) end)
	return ok
end

local function teamKey(n)   return "team:" .. n end
local function playerKey(u) return "player:" .. tostring(u) end

local function saveTeamList()
	local list = {}
	for n in pairs(customTeamObjects) do table.insert(list, n) end
	dsSet("teamlist", list)
end

local function saveTeamDS(name, info)
	dsSet(teamKey(name), {
		ColorName    = info.ColorName,
		PaletteIndex = info.PaletteIndex,
		Index        = info.Index,
	})
end

local function deleteTeamDS(name) dsRemove(teamKey(name)) end

local function savePlayerOverride(userId, teamName)
	playerOverrides[userId] = teamName
	task.spawn(function() dsSet(playerKey(userId), teamName) end)
end

local function clearPlayerOverride(userId)
	playerOverrides[userId] = nil
	task.spawn(function() dsRemove(playerKey(userId)) end)
end

local function registerTeam(team)
	teamsByName[team.Name:lower()] = { exactName = team.Name, teamObj = team }
end

local function makeAndRegisterTeam(teamName, colorName, paletteIndex)
	local displayColor = TeamGroups.GetTemplateColorName(colorName) 
	local team = TeamGroups.MakeTeam(teamName, displayColor, paletteIndex)
	registerTeam(team)
	return team
end

local function findTeamByName(name)
	if not name or name == "" then return nil, "Nama team kosong!" end
	name = name:match("^%s*(.-)%s*$")
	local key = name:lower()
	local e = teamsByName[key]
	if e and e.teamObj and e.teamObj.Parent then return e.teamObj, e.exactName end

	for _, t in ipairs(Teams:GetTeams()) do
		if t.Name:lower() == key then
			teamsByName[key] = { exactName = t.Name, teamObj = t }
			return t, t.Name
		end
	end
	return nil, string.format("Team '%s' tidak ditemukan!", name)
end

local function showCustomTeam(teamName)
	if not hiddenTeams[teamName] then
		local info = customTeamObjects[teamName]
		if info and info.TeamObj and info.TeamObj.Parent then
			registerTeam(info.TeamObj)
			return info.TeamObj
		end
		return nil
	end

	local info = customTeamObjects[teamName]
	if not info then
		hiddenTeams[teamName] = nil
		return nil
	end

	debugPrint("Showing custom team:", teamName)
	local savedInfo = hiddenTeams[teamName]
	hiddenTeams[teamName] = nil

	local team = makeAndRegisterTeam(teamName, savedInfo.ColorName, savedInfo.PaletteIndex)
	info.TeamObj = team
	TeamGroups.RefreshTeamObjects()

	for _, p in ipairs(Players:GetPlayers()) do
		if playerOverrides[p.UserId] == teamName and p and p.Parent then
			TeamGroups.SetPlayerTeam(p, team)
			debugPrint("Reassigned", p.Name, "-> restored team", teamName)
		end
	end

	return team
end

local function assignPlayer(player)
	local ov = playerOverrides[player.UserId]
	if ov then
		if hiddenTeams[ov] then
			showCustomTeam(ov)
		end
		local team, name = findTeamByName(ov)
		if team then
			TeamGroups.SetPlayerTeam(player, team)
			debugPrint("Assigned", player.Name, "-> override", name)
			return
		end
		clearPlayerOverride(player.UserId)
	end
	TeamGroups.AssignPlayer(player)
end

local function countPlayersInTeam(teamObj)
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team == teamObj then count += 1 end
	end
	return count
end

local function hideCustomTeam(teamName)
	local info = customTeamObjects[teamName]
	if not info or hiddenTeams[teamName] then return end

	local state = {
		ColorName    = info.ColorName,
		PaletteIndex = info.PaletteIndex,
		Index        = info.Index,
	}
	hiddenTeams[teamName] = state

	if not info.TeamObj or not info.TeamObj.Parent then
		info.TeamObj = nil
		return
	end

	debugPrint("Hiding custom team (empty):", teamName)
	teamsByName[teamName:lower()] = nil
	info.TeamObj:Destroy()
	info.TeamObj = nil
	TeamGroups.RefreshTeamObjects()
end

local function customTeamHasPlayer(teamName)
	local info = customTeamObjects[teamName]
	if info and info.TeamObj and info.TeamObj.Parent and countPlayersInTeam(info.TeamObj) > 0 then
		return true
	end
	for _, ov in pairs(playerOverrides) do
		if ov == teamName then return true end
	end
	return false
end

local function refreshCustomTeamVisibility()
	for teamName in pairs(customTeamObjects) do
		if customTeamHasPlayer(teamName) then
			showCustomTeam(teamName)
		else
			hideCustomTeam(teamName)
		end
	end
end

local function scheduleRefresh()
	if refreshScheduled then return end
	refreshScheduled = true
	task.delay(1.0, function()
		refreshScheduled = false
		refreshCustomTeamVisibility()
	end)
end

local function setupNotifyRemote()
	local folder = ReplicatedStorage:FindFirstChild("CustomTeamsRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CustomTeamsRemotes"
		folder.Parent = ReplicatedStorage
	end
	local r = folder:FindFirstChild("Notify")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "Notify"
		r.Parent = folder
	end
	notifyRemote = r
end

local function notify(player, msg, title, dur)
	if notifyRemote then
		notifyRemote:FireClient(player, {
			Title    = title or "Team System",
			Text     = msg,
			Duration = dur or CustomTeams.Config.NOTIF_DURATION,
		})
	end
end

local function isAllowed(player)
	local role = RoleSystem:GetPlayerRole(player)
	for _, r in ipairs(CustomTeams.Config.ALLOWED_ROLES) do
		if role == r then return true end
	end
	return false
end

local function findPlayer(q)
	if #q < 3 then return nil, "Nama minimal 3 huruf!" end
	q = q:lower()
	local exact, partial
	for _, p in ipairs(Players:GetPlayers()) do
		local dn, un = p.DisplayName:lower(), p.Name:lower()
		if dn == q or un == q then exact = p; break end
		if not partial and (dn:sub(1, #q) == q or un:sub(1, #q) == q) then partial = p end
	end
	local found = exact or partial
	return found, found and nil or ("Player '" .. q .. "' tidak ditemukan!")
end

local function doMovePlayer(invoker, target, teamName)
	teamName = teamName:match("^%s*(.-)%s*$")

	local foundTeam, exactName
	if hiddenTeams[teamName] then
		foundTeam = showCustomTeam(teamName)
		if foundTeam then exactName = teamName end
	end

	if not foundTeam then
		foundTeam, exactName = findTeamByName(teamName)
	end

	if not foundTeam then
		return false, string.format("Team '%s' tidak ditemukan!", teamName)
	end

	if exactName == "Owner" and RoleSystem:GetPlayerRole(target) ~= "Owner" then
		return false, string.format("%s tidak bisa masuk ke team Owner! Hanya role Owner yang diizinkan.", target.Name)
	end

	if not foundTeam.Parent then
		return false, string.format("Team '%s' tidak valid (sudah dihapus?).", exactName)
	end

	TeamGroups.SetPlayerTeam(target, foundTeam)

	if exactName == "Tamu" then
		clearPlayerOverride(target.UserId)
	else
		savePlayerOverride(target.UserId, exactName)
	end

	notify(target,
		string.format("Kamu dipindahkan ke team '%s' oleh %s.", exactName, invoker.DisplayName),
		"Team Diubah")

	task.delay(0.3, scheduleRefresh)

	return true, string.format("%s dipindahkan ke '%s'", target.DisplayName, exactName)
end

function CustomTeams.AppendCustomTeams()
	teamsByName = {}
	for _, t in ipairs(Teams:GetTeams()) do
		registerTeam(t)
	end

	local sorted = {}
	for name, info in pairs(customTeamObjects) do
		table.insert(sorted, { Name = name, Info = info })
	end
	table.sort(sorted, function(a, b) return a.Info.Index < b.Info.Index end)

	for _, ct in ipairs(sorted) do
		local team = makeAndRegisterTeam(ct.Name, ct.Info.ColorName, ct.Info.PaletteIndex)
		ct.Info.TeamObj = team
	end

	TeamGroups.RefreshTeamObjects()
	debugPrint(string.format("AppendCustomTeams: %d custom teams, %d total", #sorted, #Teams:GetTeams()))

	task.delay(3, refreshCustomTeamVisibility)
end

function CustomTeams.LoadFromDataStore()
	local teamList = dsGet("teamlist") or {}
	if #teamList == 0 then return end

	local loaded = 0
	for _, teamName in ipairs(teamList) do
		task.spawn(function()
			local data = dsGet(teamKey(teamName))
			if data then
				local paletteIndex = data.PaletteIndex
				if not paletteIndex or paletteIndex == 0 then
					paletteIndex = TeamGroups.NextFreePaletteIndex()
					warn(string.format(
						"[CustomTeams] Team '%s' tidak punya PaletteIndex di DS, generate baru: %d",
						teamName, paletteIndex
					))
				end
				customTeamObjects[teamName] = {
					ColorName    = data.ColorName or "Abu-abu",
					PaletteIndex = paletteIndex,
					Index        = data.Index or 1,
					TeamObj      = nil,
				}
			end
			loaded = loaded + 1
		end)
		task.wait(0.1) 
	end

	local t0 = tick()
	while loaded < #teamList and (tick() - t0) < 10 do task.wait(0.05) end
	debugPrint(string.format("LoadFromDataStore: %d/%d loaded", loaded, #teamList))
end

function CustomTeams.HasOverride(userId)
	return playerOverrides[userId] ~= nil
end

function CustomTeams.AssignNewPlayer(player)
	if not player or not player.Parent then return end
	if assignedPlayers[player] then return end
	assignedPlayers[player] = true

	RoleSystem:CachePlayerOwnership(player)

	if not playerOverrides[player.UserId] then
		local saved = dsGet(playerKey(player.UserId))
		if saved and player and player.Parent then
			playerOverrides[player.UserId] = saved
			if hiddenTeams[saved] then
				showCustomTeam(saved)
			end
		end
	end

	assignPlayer(player)

	task.spawn(function()
		task.wait(16)
		if player and player.Parent and not playerOverrides[player.UserId] then
			assignPlayer(player)
			debugPrint("Re-assigned after gamepass check:", player.Name)
		end
	end)

	task.delay(0.5, scheduleRefresh)
end

function CustomTeams.RefreshPlayerTeam(player)
	if not player or not player.Parent then return false end
	assignPlayer(player)
	return true
end

function CustomTeams.MovePlayer(invoker, target, teamName)
	if not invoker or not target or not teamName then return false, "Parameter tidak lengkap!" end
	return doMovePlayer(invoker, target, teamName)
end

function CustomTeams.CreateTeam(invoker, teamName, colorName)
	if not invoker or not teamName or teamName == "" then return false, "Nama team kosong!" end
	teamName = teamName:match("^%s*(.-)%s*$")
	if #teamName < 2 then return false, "Nama team minimal 2 karakter!" end
	if #teamName > 30 then return false, "Nama team max 30 karakter!" end

	if teamsByName[teamName:lower()] or hiddenTeams[teamName] then
		return false, string.format("Team '%s' sudah ada!", teamName)
	end

	local filteredTeamName = teamName
	if not RunService:IsStudio() then
		local filterOk, filterResult = pcall(function()
			local invokerId = (typeof(invoker) == "Instance" and invoker:IsA("Player")) and invoker.UserId or 0
			if invokerId <= 0 then
				local p1 = Players:GetPlayers()[1]
				invokerId = p1 and p1.UserId or ServerConfig.GetPrimaryOwnerId()
			end
			return TextService:FilterStringAsync(teamName, invokerId)
		end)

		if not filterOk or not filterResult then
			return false, "Layanan filter teks sedang gangguan. Silakan coba lagi nanti."
		end

		local broadcastOk, broadcastStr = pcall(function()
			return filterResult:GetNonChatStringForBroadcastAsync()
		end)

		if not broadcastOk or type(broadcastStr) ~= "string" or #broadcastStr == 0 then
			return false, "Gagal memproses filter nama team. Silakan coba lagi nanti."
		end

		filteredTeamName = broadcastStr

		-- Jangan pernah memakai nama mentah jika Roblox menyensor/mengubahnya.
		if filteredTeamName ~= teamName then
			return false, "Nama team tidak diizinkan atau mengandung kata yang disensor oleh Roblox!"
		end
	end

	teamName = filteredTeamName

	if teamsByName[teamName:lower()] or hiddenTeams[teamName] then
		return false, string.format("Team '%s' sudah ada!", teamName)
	end

	colorName = colorName or "Abu-abu"
	local template = TeamGroups.templateByName[colorName:lower()] or TeamGroups.templateByName["abu-abu"]

	local paletteIndex = TeamGroups.NextFreePaletteIndex()
	local nextIndex = 1
	for _, info in pairs(customTeamObjects) do
		if info.Index >= nextIndex then nextIndex = info.Index + 1 end
	end

	local info = { ColorName = template.name, PaletteIndex = paletteIndex, Index = nextIndex, TeamObj = nil }
	customTeamObjects[teamName] = info
	hiddenTeams[teamName] = {
		ColorName    = template.name,
		PaletteIndex = paletteIndex,
		Index        = nextIndex,
	}
	debugPrint("API CreateTeam (hidden):", teamName, "| warna:", template.name, "| palette:", paletteIndex)

	task.spawn(function() saveTeamDS(teamName, info); saveTeamList() end)
	return true, string.format(
		"Team '%s' (%s) berhasil dibuat! Team akan muncul saat ada player yang bergabung.",
		teamName, template.name
	)
end

function CustomTeams.DeleteTeam(invoker, teamName)
	if not invoker or not teamName or teamName == "" then return false, "Nama team kosong!" end
	local info = customTeamObjects[teamName]
	if not info then
		return false, string.format("Hanya custom team yang bisa dihapus. '%s' tidak ditemukan.", teamName)
	end

	local affected = {}
	if info.TeamObj then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Team == info.TeamObj then table.insert(affected, p) end
		end
	end

	teamsByName[teamName:lower()] = nil
	hiddenTeams[teamName] = nil
	customTeamObjects[teamName] = nil
	if info.TeamObj and info.TeamObj.Parent then info.TeamObj:Destroy() end
	TeamGroups.RefreshTeamObjects()

	for _, p in ipairs(affected) do
		clearPlayerOverride(p.UserId)
		TeamGroups.AssignPlayer(p)
		notify(p, string.format("Team '%s' dihapus.", teamName), "Team Dihapus", 6)
	end

	for uid, ov in pairs(playerOverrides) do
		if ov == teamName then clearPlayerOverride(uid) end
	end

	task.spawn(function() deleteTeamDS(teamName); saveTeamList() end)
	return true, string.format("Team '%s' dihapus! (%d player dikembalikan)", teamName, #affected)
end

local function toRGB(color)
	return math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)
end

function CustomTeams.GetTeamList()
	local result = {}

	for _, team in ipairs(Teams:GetTeams()) do
		if team.Name ~= "Owner" then
			local c = team.TeamColor.Color
			local defR, defG, defB = toRGB(c)
			table.insert(result, {
				name           = team.Name,
				brickColorName = team.TeamColor.Name,
				r              = team:GetAttribute("ExactColorR") or defR,
				g              = team:GetAttribute("ExactColorG") or defG,
				b              = team:GetAttribute("ExactColorB") or defB,
				isCustom       = customTeamObjects[team.Name] ~= nil,
				isHidden       = false,
			})
		end
	end

	for teamName, hInfo in pairs(hiddenTeams) do
		if customTeamObjects[teamName] then
			local template = TeamGroups.templateByName[hInfo.ColorName:lower()]
			local r, g, b = 200, 200, 200
			local brickColorName = nil
			if template and template.brickColorName then
				brickColorName = template.brickColorName
				r, g, b = toRGB(BrickColor.new(brickColorName).Color)
			end
			table.insert(result, {
				name           = teamName,
				brickColorName = brickColorName,
				r              = r,
				g              = g,
				b              = b,
				isCustom       = true,
				isHidden       = true,
			})
		end
	end

	return result
end

function CustomTeams.GetColorTemplates()
	return TeamGroups.COLOR_TEMPLATES
end

local function cmdCreate(player, args)
	if #args < 2 then
		notify(player,
			"Usage: ;create (nama) (warna)\nContoh: ;create Founder Merah\nWarna: Merah, Biru, Hijau, Emas, dll.",
			"Syntax Error")
		return
	end

	local teamName  = args[1]
	local colorName = args[2]

	local template = TeamGroups.templateByName[colorName:lower()]
	if not template then
		local names = {}
		for _, t in ipairs(TeamGroups.COLOR_TEMPLATES) do table.insert(names, t.name) end
		notify(player,
			string.format("Warna '%s' tidak valid!\nPilihan: %s", colorName, table.concat(names, ", ")),
			"Warna Tidak Valid")
		return
	end

	local ok, msg = CustomTeams.CreateTeam(player, teamName, colorName)
	notify(player, msg, ok and "Sukses" or "Gagal", 6)
end

local function cmdUncreate(player, args)
	if #args < 1 then notify(player, "Usage: ;uncreate (nama_team)", "Syntax Error"); return end
	local ok, msg = CustomTeams.DeleteTeam(player, args[1])
	notify(player, msg, ok and "Sukses" or "Gagal", 6)
end

local function cmdMoveTeam(player, args)
	if #args < 2 then notify(player, "Usage: ;moveteam (player) (team)", "Syntax Error"); return end
	local target, err = findPlayer(args[1])
	if not target then notify(player, err, "Player Tidak Ditemukan"); return end
	local ok, msg = CustomTeams.MovePlayer(player, target, args[2])
	notify(player, msg, ok and "Sukses" or "Gagal")
end

local CHAT_COMMANDS = {
	create   = cmdCreate,
	uncreate = cmdUncreate,
	moveteam = cmdMoveTeam,
}

local lastCustomTeamCmd = {} -- [userId] = { text = string, timestamp = number }

local function handleCommand(player, message)
	if not player or not player.Parent then return end
	local prefix = CustomTeams.Config.PREFIX
	if message:sub(1, #prefix) ~= prefix then return end
	if not isAllowed(player) then
		notify(player, "Akses ditolak! Minimal role: Admin", "Akses Ditolak")
		return
	end

	-- Deduplikasi perintah untuk mencegah eksekusi ganda jika dipicu Chatted + TextChatCommand bersamaan
	local now = os.clock()
	local last = lastCustomTeamCmd[player.UserId]
	if last and last.text == message and (now - last.timestamp) < 0.5 then
		return
	end
	lastCustomTeamCmd[player.UserId] = { text = message, timestamp = now }

	local parts = {}
	for p in message:sub(#prefix + 1):gmatch("%S+") do table.insert(parts, p) end
	if #parts == 0 then return end

	local handler = CHAT_COMMANDS[parts[1]:lower()]
	if handler then
		local args = {}
		for i = 2, #parts do table.insert(args, parts[i]) end
		handler(player, args)
	end
end

function CustomTeams.Init()
	setupNotifyRemote()

	-- [LOW-01] Integrasi TextChatCommand untuk TextChatService modern
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		local cmdFolder = TextChatService:FindFirstChild("TextChatCommands")
		if cmdFolder then
			local function registerTCC(name, primaryAlias)
				local cmd = cmdFolder:FindFirstChild(name)
				if not cmd then
					cmd = Instance.new("TextChatCommand")
					cmd.Name = name
					cmd.PrimaryAlias = primaryAlias
					cmd.Parent = cmdFolder
				end
				cmd.Triggered:Connect(function(textSource, rawMsg)
					local p = Players:GetPlayerByUserId(textSource.UserId)
					if p then handleCommand(p, rawMsg) end
				end)
			end
			registerTCC("CustomTeamCreate", ";create")
			registerTCC("CustomTeamUncreate", ";uncreate")
			registerTCC("CustomTeamMove", ";moveteam")
		end
	end)

	local function hookPlayer(p)
		p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
		p:GetPropertyChangedSignal("Team"):Connect(scheduleRefresh)
	end

	for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
	Players.PlayerAdded:Connect(function(p)
		hookPlayer(p)
		task.delay(2, scheduleRefresh)
	end)

	Players.PlayerRemoving:Connect(function(p)
		playerOverrides[p.UserId] = nil
		assignedPlayers[p] = nil
		task.delay(0.5, scheduleRefresh)
	end)
end

return CustomTeams