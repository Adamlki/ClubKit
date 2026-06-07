local CustomTeams = {}

local Players           = game:GetService("Players")
local Teams             = game:GetService("Teams")
local ServerStorage     = game:GetService("ServerStorage")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

--[[
  DataStore key:
    "teamlist"         → array nama custom team
    "team:<nama>"      → { ColorName=string, PaletteIndex=int, Index=int }
    "player:<userId>"  → "<namaTeam>"  (override admin)
                         nil = tidak ada override, ikut role

  CATATAN ARSITEKTUR:
  - player.Team ditrack Roblox via TeamColor (BrickColor/palette index), BUKAN nama.
  - Palette index WAJIB unik per team agar tracking Roblox tidak konflik.
  - Dua team boleh punya warna display sama — yang penting palette index beda.
  - Lookup di kode ini selalu by NAME (findTeamByName), tidak pernah by warna.
  - ExactColorR/G/B attribute hanya untuk display (overhead, admin panel UI).

  FIX UTAMA (v3):
  - showCustomTeam sekarang return team object, dan doMovePlayer pakai langsung
    tanpa memanggil findTeamByName ulang → tidak ada jeda antara show & assign.
  - doMovePlayer tidak lagi bergantung pada findTeamByName setelah showCustomTeam,
    karena team object sudah ada di tangan.
  - AssignNewPlayer menunggu role final (gamepass async) sebelum assign ulang.
  - scheduleRefresh debounce dinaikkan ke 1 detik agar tidak spam saat server penuh.
  - showCustomTeam null-safe: cek player.Parent sebelum assign.
]]

local store             = DataStoreService:GetDataStore(CustomTeams.Config.DATASTORE_NAME)
local customTeamObjects = {}  -- { [name] = { ColorName, PaletteIndex, Index, TeamObj } }
local playerOverrides   = {}  -- { [userId] = teamName }
local teamsByName       = {}  -- { [nameLower] = { exactName, teamObj } }
local notifyRemote      = nil

-- hiddenTeams: custom team yang object-nya dihapus sementara (tidak ada player)
local hiddenTeams      = {}   -- { [teamName] = { ColorName, PaletteIndex, Index } }
local refreshScheduled = false

local function debugPrint(...)
	if CustomTeams.Config.DEBUG_ENABLED then print("[CustomTeams]", ...) end
end

-- ====================================
-- DATASTORE
-- ====================================
local function dsGet(key)
	for i = 1, CustomTeams.Config.DATASTORE_RETRY do
		local ok, r = pcall(function() return store:GetAsync(key) end)
		if ok then return r end
		if i < CustomTeams.Config.DATASTORE_RETRY then task.wait(CustomTeams.Config.DATASTORE_DELAY) end
	end
	return nil
end

local function dsSet(key, val)
	for i = 1, CustomTeams.Config.DATASTORE_RETRY do
		local ok = pcall(function() store:SetAsync(key, val) end)
		if ok then return true end
		if i < CustomTeams.Config.DATASTORE_RETRY then task.wait(CustomTeams.Config.DATASTORE_DELAY) end
	end
	return false
end

local function dsRemove(key)
	for i = 1, CustomTeams.Config.DATASTORE_RETRY do
		local ok = pcall(function() store:RemoveAsync(key) end)
		if ok then return true end
		if i < CustomTeams.Config.DATASTORE_RETRY then task.wait(CustomTeams.Config.DATASTORE_DELAY) end
	end
	return false
end

local function teamKey(n)   return "team:" .. n end
local function playerKey(u) return "player:" .. tostring(u) end

-- ====================================
-- PERSISTENCE
-- ====================================
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

-- ====================================
-- TEAM REGISTRY
-- ====================================
local function registerTeam(team)
	teamsByName[team.Name:lower()] = { exactName = team.Name, teamObj = team }
end

local function makeAndRegisterTeam(teamName, colorName, paletteIndex)
	-- ✅ GANTI GetTemplateColor menjadi GetTemplateColorName
	local displayColor = TeamGroups.GetTemplateColorName(colorName) 
	local team = TeamGroups.MakeTeam(teamName, displayColor, paletteIndex)
	registerTeam(team)
	return team
end

-- ====================================
-- TEAM LOOKUP — by exact name only
-- FIX: fallback scan hanya dilakukan jika cache miss, dan tetap exact match.
-- ====================================
local function findTeamByName(name)
	if not name or name == "" then return nil, "Nama team kosong!" end
	name = name:match("^%s*(.-)%s*$")
	local key = name:lower()
	local e = teamsByName[key]
	if e and e.teamObj and e.teamObj.Parent then return e.teamObj, e.exactName end
	-- Fallback: scan Teams service (exact match)
	for _, t in ipairs(Teams:GetTeams()) do
		if t.Name:lower() == key then
			teamsByName[key] = { exactName = t.Name, teamObj = t }
			return t, t.Name
		end
	end
	return nil, string.format("Team '%s' tidak ditemukan!", name)
end

-- ====================================
-- ASSIGN PLAYER
-- ====================================
local function assignPlayer(player)
	local ov = playerOverrides[player.UserId]
	if ov then
		local team, name = findTeamByName(ov)
		if team then
			player.Team = team
			debugPrint("Assigned", player.Name, "-> override", name)
			return
		end
		-- Override menunjuk team yang sudah tidak ada, bersihkan
		clearPlayerOverride(player.UserId)
	end
	TeamGroups.AssignPlayer(player)
end

-- ====================================
-- HIDE / SHOW CUSTOM TEAM OBJECT
-- FIX: showCustomTeam sekarang RETURN team object yang baru dibuat,
--      sehingga doMovePlayer bisa langsung pakai tanpa findTeamByName ulang.
--      Ini menghilangkan jeda antara show dan assign yang bisa bikin salah team.
-- ====================================

local function countPlayersInTeam(teamObj)
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team == teamObj then count += 1 end
	end
	return count
end

local function hideCustomTeam(teamName)
	local info = customTeamObjects[teamName]
	if not info then return end
	if hiddenTeams[teamName] then return end

	if not info.TeamObj or not info.TeamObj.Parent then
		hiddenTeams[teamName] = {
			ColorName    = info.ColorName,
			PaletteIndex = info.PaletteIndex,
			Index        = info.Index,
		}
		info.TeamObj = nil
		return
	end

	debugPrint("Hiding custom team (empty):", teamName)
	hiddenTeams[teamName] = {
		ColorName    = info.ColorName,
		PaletteIndex = info.PaletteIndex,
		Index        = info.Index,
	}

	teamsByName[teamName:lower()] = nil
	info.TeamObj:Destroy()
	info.TeamObj = nil
	TeamGroups.RefreshTeamObjects()
end

-- FIX: return team object agar caller tidak perlu findTeamByName lagi
local function showCustomTeam(teamName)
	if not hiddenTeams[teamName] then
		-- Tidak sedang hidden, tapi pastikan terdaftar di teamsByName
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

	-- FIX: spawn per player + cek player masih online sebelum assign
	for _, p in ipairs(Players:GetPlayers()) do
		if playerOverrides[p.UserId] == teamName then
			task.spawn(function()
				if p and p.Parent then
					p.Team = team
					debugPrint("Reassigned", p.Name, "-> restored team", teamName)
				end
			end)
		end
	end

	return team  -- return untuk doMovePlayer
end

local function customTeamHasPlayer(teamName)
	local info = customTeamObjects[teamName]
	if info and info.TeamObj and info.TeamObj.Parent then
		if countPlayersInTeam(info.TeamObj) > 0 then
			return true
		end
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

-- FIX: debounce dinaikkan ke 1 detik agar tidak spam saat server penuh
local function scheduleRefresh()
	if refreshScheduled then return end
	refreshScheduled = true
	task.delay(1.0, function()
		refreshScheduled = false
		refreshCustomTeamVisibility()
	end)
end

-- ====================================
-- NOTIFY
-- ====================================
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

-- ====================================
-- HELPERS
-- ====================================
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

-- ====================================
-- INTERNAL MOVE
-- FIX UTAMA: doMovePlayer sekarang memakai team object yang dikembalikan
-- langsung oleh showCustomTeam, bukan memanggil findTeamByName setelah show.
-- Ini memastikan tidak ada race condition antara "show team" dan "assign player".
-- ====================================
local function doMovePlayer(invoker, target, teamName)
	teamName = teamName:match("^%s*(.-)%s*$")

	local foundTeam, exactName

	if hiddenTeams[teamName] then
		-- Team sedang hidden: restore dulu, langsung pakai return value-nya
		local restoredTeam = showCustomTeam(teamName)
		if restoredTeam then
			foundTeam = restoredTeam
			exactName = teamName
		end
	end

	-- Jika bukan hidden (atau showCustomTeam gagal), cari via registry
	if not foundTeam then
		foundTeam, exactName = findTeamByName(teamName)
	end

	if not foundTeam then
		return false, string.format("Team '%s' tidak ditemukan!", teamName)
	end

	-- VALIDASI: hanya role Owner yang boleh masuk team Owner
	if exactName == "Owner" then
		local targetRole = RoleSystem:GetPlayerRole(target)
		if targetRole ~= "Owner" then
			return false, string.format(
				"%s tidak bisa masuk ke team Owner! Hanya role Owner yang diizinkan.", target.Name
			)
		end
	end

	-- FIX: verifikasi team object masih valid sebelum assign
	if not foundTeam.Parent then
		return false, string.format("Team '%s' tidak valid (sudah dihapus?).", exactName)
	end

	target.Team = foundTeam

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

-- ====================================
-- INIT FLOW
-- ====================================
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
	end
	local t0 = tick()
	while loaded < #teamList and (tick() - t0) < 10 do task.wait(0.05) end
	debugPrint(string.format("LoadFromDataStore: %d/%d loaded", loaded, #teamList))
end

function CustomTeams.Init()
	setupNotifyRemote()

	for _, p in ipairs(Players:GetPlayers()) do
		p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
	end
	Players.PlayerAdded:Connect(function(p)
		p.Chatted:Connect(function(msg) handleCommand(p, msg) end)
		task.delay(2, scheduleRefresh)
		p:GetPropertyChangedSignal("Team"):Connect(function()
			scheduleRefresh()
		end)
	end)

	Players.PlayerRemoving:Connect(function(p)
		playerOverrides[p.UserId] = nil
		task.delay(0.5, scheduleRefresh)
	end)
end

-- ====================================
-- PUBLIC API
-- ====================================
function CustomTeams.HasOverride(userId)
	return playerOverrides[userId] ~= nil
end

-- FIX: AssignNewPlayer menunggu gamepass async selesai sebelum re-assign final.
-- Ini mencegah player dapat team "Tamu" sementara gamepass-nya belum terverifikasi.
function CustomTeams.AssignNewPlayer(player)
	RoleSystem:CachePlayerOwnership(player)

	-- Load override dari DS jika belum ada di cache
	if not playerOverrides[player.UserId] then
		local saved = dsGet(playerKey(player.UserId))
		if saved and player and player.Parent then
			playerOverrides[player.UserId] = saved
			if hiddenTeams[saved] then
				showCustomTeam(saved)
			end
		end
	end

	-- Assign segera dengan role yang sudah tersedia (mungkin belum final jika gamepass async)
	assignPlayer(player)

	-- Tunggu gamepass async selesai (RoleSystem GAMEPASS_CHECK_TIMEOUT = 15s + buffer)
	-- lalu re-assign jika player tidak punya custom override
	task.spawn(function()
		task.wait(16)
		if player and player.Parent then
			if not playerOverrides[player.UserId] then
				-- Tidak ada override admin, assign ulang berdasarkan role final
				TeamGroups.AssignPlayer(player)
				debugPrint("Re-assigned after gamepass check:", player.Name)
			end
		end
	end)

	task.delay(0.5, scheduleRefresh)
end

-- ====================================
-- CHAT COMMANDS
-- ====================================
local function cmdCreate(player, args)
	if #args < 2 then
		notify(player,
			"Usage: ;create (nama) (warna)\nContoh: ;create Founder Merah\nWarna: Merah, Biru, Hijau, Emas, dll.",
			"Syntax Error")
		return
	end
	local teamName  = args[1]
	local colorName = args[2]

	if teamsByName[teamName:lower()] or hiddenTeams[teamName] then
		notify(player, string.format("Team '%s' sudah ada!", teamName), "Gagal"); return
	end

	local template = TeamGroups.templateByName[colorName:lower()]
	if not template then
		local names = {}
		for _, t in ipairs(TeamGroups.COLOR_TEMPLATES) do table.insert(names, t.name) end
		notify(player,
			string.format("Warna '%s' tidak valid!\nPilihan: %s", colorName, table.concat(names, ", ")),
			"Warna Tidak Valid")
		return
	end

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
	debugPrint("New custom team created (hidden until player assigned):", teamName, "| palette:", paletteIndex)

	task.spawn(function() saveTeamDS(teamName, info); saveTeamList() end)
	notify(player,
		string.format(
			"Team '%s' (%s) berhasil dibuat! Team akan muncul saat ada player yang bergabung.",
			teamName, template.name
		),
		"Sukses", 6)
end

local function cmdUncreate(player, args)
	if #args < 1 then notify(player, "Usage: ;uncreate (nama_team)", "Syntax Error"); return end
	local teamName = args[1]
	local info = customTeamObjects[teamName]
	if not info then
		notify(player, string.format("Custom team '%s' tidak ditemukan!", teamName), "Gagal"); return
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
	notify(player, string.format("Team '%s' dihapus. %d player dikembalikan.", teamName, #affected), "Sukses", 6)
end

local function cmdMoveTeam(player, args)
	if #args < 2 then notify(player, "Usage: ;moveteam (player) (team)", "Syntax Error"); return end
	local target, err = findPlayer(args[1])
	if not target then notify(player, err, "Player Tidak Ditemukan"); return end
	local ok, msg = doMovePlayer(player, target, args[2])
	notify(player, msg, ok and "Sukses" or "Gagal")
end

function handleCommand(player, message)
	local prefix = CustomTeams.Config.PREFIX
	if message:sub(1, #prefix) ~= prefix then return end
	if not isAllowed(player) then
		notify(player, "Akses ditolak! Minimal role: Admin", "Akses Ditolak"); return
	end
	local parts = {}
	for p in message:sub(#prefix + 1):gmatch("%S+") do table.insert(parts, p) end
	if #parts == 0 then return end
	local cmd  = parts[1]:lower()
	local args = {}
	for i = 2, #parts do table.insert(args, parts[i]) end
	if     cmd == "create"   then cmdCreate(player, args)
	elseif cmd == "uncreate" then cmdUncreate(player, args)
	elseif cmd == "moveteam" then cmdMoveTeam(player, args)
	end
end

-- ====================================
-- PUBLIC API untuk AdminPanelServer
-- ====================================
function CustomTeams.MovePlayer(invoker, target, teamName)
	if not invoker or not target or not teamName then return false, "Parameter tidak lengkap!" end
	return doMovePlayer(invoker, target, teamName)
end

function CustomTeams.CreateTeam(invoker, teamName, colorName)
	if not invoker or not teamName or teamName == "" then return false, "Nama team kosong!" end
	teamName = teamName:match("^%s*(.-)%s*$")
	if #teamName > 30 then return false, "Nama team max 30 karakter!" end

	if teamsByName[teamName:lower()] or hiddenTeams[teamName] then
		return false, string.format("Team '%s' sudah ada!", teamName)
	end

	colorName = colorName or "Abu-abu"
	local template = TeamGroups.templateByName[colorName:lower()]
	if not template then
		colorName = "Abu-abu"
		template  = TeamGroups.templateByName["abu-abu"]
	end

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
		return false, string.format(
			"Hanya custom team yang bisa dihapus. '%s' tidak ditemukan.", teamName
		)
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

function CustomTeams.GetTeamList()
	local result = {}

	for _, team in ipairs(Teams:GetTeams()) do
		if team.Name == "Owner" then continue end

		local r = team:GetAttribute("ExactColorR") or 200
		local g = team:GetAttribute("ExactColorG") or 200
		local b = team:GetAttribute("ExactColorB") or 200
		table.insert(result, {
			name     = team.Name,
			r = r, g = g, b = b,
			isCustom = customTeamObjects[team.Name] ~= nil,
			isHidden = false,
		})
	end

	for teamName, hInfo in pairs(hiddenTeams) do
		if customTeamObjects[teamName] then
			local template = TeamGroups.templateByName[hInfo.ColorName:lower()]
			local r, g, b = 200, 200, 200
			if template then r, g, b = template.r, template.g, template.b end
			table.insert(result, {
				name     = teamName,
				r = r, g = g, b = b,
				isCustom = true,
				isHidden = true,
			})
		end
	end

	return result
end

function CustomTeams.GetColorTemplates()
	return TeamGroups.COLOR_TEMPLATES
end

return CustomTeams
