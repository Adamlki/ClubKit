local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")

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

local GetSpotlightSettingsRemote    = ensureRF("GetSpotlightSettings")
local UpdateSpotlightSettingsRemote = ensureRF("UpdateSpotlightSettings")

-- Remote untuk trigger animasi kamera sorot donor ke semua client
local DonorSpotlightRemote = ReplicatedStorage:FindFirstChild("DonorSpotlightRemote")
if not DonorSpotlightRemote then
	DonorSpotlightRemote = Instance.new("RemoteEvent")
	DonorSpotlightRemote.Name = "DonorSpotlightRemote"
	DonorSpotlightRemote.Parent = ReplicatedStorage
end

-- =========================================================
-- FOLDER SETTING KAMERA SOROT DONOR (PER-SERVER SESSION)
-- =========================================================
local spotlightFolder = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
if not spotlightFolder then
	spotlightFolder = Instance.new("Folder")
	spotlightFolder.Name = "DonationSpotlightSettings"
	spotlightFolder.Parent = ReplicatedStorage
end

if spotlightFolder:GetAttribute("Enabled") == nil then
	spotlightFolder:SetAttribute("Enabled", false) -- Default NONAKTIF (OFF)
end
if spotlightFolder:GetAttribute("MinRobux") == nil then
	spotlightFolder:SetAttribute("MinRobux", 500)
end
if spotlightFolder:GetAttribute("MinSaweria") == nil then
	spotlightFolder:SetAttribute("MinSaweria", 50000)
end

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

-- =========================================================
-- HANDLER PENGATURAN SOROT KAMERA DONOR (ADMIN PANEL)
-- =========================================================
GetSpotlightSettingsRemote.OnServerInvoke = function(sender)
	if not sender or isSpamming(sender, "GetSpotlight") or not isAdminOrMod(sender) then
		return {
			Enabled = spotlightFolder:GetAttribute("Enabled") == true,
			MinRobux = spotlightFolder:GetAttribute("MinRobux") or 500,
			MinSaweria = spotlightFolder:GetAttribute("MinSaweria") or 50000,
		}
	end
	return {
		Enabled = spotlightFolder:GetAttribute("Enabled") == true,
		MinRobux = spotlightFolder:GetAttribute("MinRobux") or 500,
		MinSaweria = spotlightFolder:GetAttribute("MinSaweria") or 50000,
	}
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
		)
	}
end