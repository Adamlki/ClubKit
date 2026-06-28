local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local RoleSystem  = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))
local CustomTeams = require(ServerStorage:WaitForChild("Modules"):WaitForChild("CustomTeams"))
-- [TAMBAHAN] Panggil modul TeamGroups untuk mengambil template warnanya
local TeamGroups  = require(ServerStorage:WaitForChild("Modules"):WaitForChild("TeamGroups"))

local DEBUG = false
local function log(...) if DEBUG then print("[AdminPanelServer]", ...) end end

-- ==========================================
-- 🔥 ARCHITECT FIX: SISTEM ANTI-SPAM (RATE LIMITER)
-- ==========================================
local COOLDOWN_TIME = 1 -- Jeda 1 detik untuk setiap perintah admin
local playerCooldowns = {}

local function isSpamming(player, actionName)
	-- 🔥 SECURITY FIX: Validasi tipe data sender untuk mencegah Error Crash
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then return true end

	if not playerCooldowns[player.UserId] then
		playerCooldowns[player.UserId] = {}
	end

	local lastRequest = playerCooldowns[player.UserId][actionName] or 0
	local now = os.clock()
	if now - lastRequest < COOLDOWN_TIME then
		return true 
	end
	playerCooldowns[player.UserId][actionName] = now
	return false
end

-- Bersihkan memori saat admin keluar server agar tidak bocor
Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)
-- ==========================================

local adminPanelRemotes = ReplicatedStorage:FindFirstChild("AdminPanelRemotes")
if not adminPanelRemotes then
	adminPanelRemotes        = Instance.new("Folder")
	adminPanelRemotes.Name   = "AdminPanelRemotes"
	adminPanelRemotes.Parent = ReplicatedStorage
end

local function ensureRE(name)
	local r = adminPanelRemotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = adminPanelRemotes end
	return r
end
local function ensureRF(name)
	local r = adminPanelRemotes:FindFirstChild(name)
	if not r then r = Instance.new("RemoteFunction"); r.Name = name; r.Parent = adminPanelRemotes end
	return r
end

local GetTeamListRemote       = ensureRF("GetTeamList")
local GetColorTemplatesRemote = ensureRF("GetColorTemplates")
local TeamActionRemote        = ensureRE("TeamAction")
local TeamActionResultRemote  = ensureRE("TeamActionResult")

local function isOwnerOrAdmin(p)
	local r = RoleSystem:GetPlayerRole(p)
	return r == "Owner" or r == "Admin"
end
local function isAdminOrMod(p)
	local r = RoleSystem:GetPlayerRole(p)
	return r == "Owner" or r == "Admin" or r == "Moderator"
end

-- =========================================================
-- [PERBAIKAN] MENGIRIM TEMPLATE WARNA KE CLIENT (ADMIN PANEL)
-- =========================================================
GetColorTemplatesRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetColors") then return {} end

	local templates = {}
	-- Langsung ambil dari TeamGroups dan kirim format brickColorName
	for _, tmpl in ipairs(TeamGroups.COLOR_TEMPLATES) do
		table.insert(templates, {
			name = tmpl.name,
			brickColorName = tmpl.brickColorName
		})
	end

	return templates
end

GetTeamListRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetTeams") or not isAdminOrMod(sender) then return {} end
	return CustomTeams.GetTeamList()
end

TeamActionRemote.OnServerEvent:Connect(function(sender, data)
	-- 🔥 ARCHITECT FIX: BLOKIR JIKA SPAM!
	if isSpamming(sender, "Action") then
		TeamActionResultRemote:FireClient(sender, { success=false, message="Tunggu 1 detik! Jangan spam klik." })
		return
	end

	if not data or type(data) ~= "table" then return end
	if not isOwnerOrAdmin(sender) then
		TeamActionResultRemote:FireClient(sender, { success=false, message="Akses ditolak!" })
		return
	end

	local action = data.action

	if action == "MovePlayer" then
		-- 🔥 SECURITY FIX: Validasi type data agar tidak crash saat di-exploit
		local targetId = tonumber(data.targetUserId)
		if not targetId then
			TeamActionResultRemote:FireClient(sender, { success=false, message="ID Player tidak valid!" })
			return
		end
		
		local target = Players:GetPlayerByUserId(targetId)
		if not target then
			TeamActionResultRemote:FireClient(sender, { success=false, message="Player tidak ditemukan!" })
			return
		end
		local ok, msg = CustomTeams.MovePlayer(sender, target, data.teamName)
		TeamActionResultRemote:FireClient(sender, { success=ok, message=msg })

	elseif action == "CreateTeam" then
		if not data.teamName or data.teamName:match("^%s*$") then
			TeamActionResultRemote:FireClient(sender, { success=false, message="Nama team kosong!" })
			return
		end
		-- colorName = nama template: "Merah", "Biru", dll. (bukan RGB)
		local ok, msg = CustomTeams.CreateTeam(sender, data.teamName, data.colorName)
		TeamActionResultRemote:FireClient(sender, { success=ok, message=msg })

	elseif action == "DeleteTeam" then
		if not data.teamName or data.teamName:match("^%s*$") then
			TeamActionResultRemote:FireClient(sender, { success=false, message="Nama team kosong!" })
			return
		end
		local ok, msg = CustomTeams.DeleteTeam(sender, data.teamName)
		TeamActionResultRemote:FireClient(sender, { success=ok, message=msg })

	else
		TeamActionResultRemote:FireClient(sender, { success=false, message="Aksi tidak dikenal." })
	end
end)