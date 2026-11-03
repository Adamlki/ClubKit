--!optimize 2

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local ENABLED = true
if not ENABLED then
	return
end

local warningCount = 0

local function warnSetup(message)
	warningCount = warningCount + 1
	warn("[SETUP] " .. message)
end

local function safeRequire(instance, label)
	local ok, result = pcall(require, instance)
	if not ok then
		warnSetup("Gagal memuat " .. label .. ": " .. tostring(result))
		return nil
	end
	return result
end

local privateConfig = safeRequire(
	ServerStorage:WaitForChild("Modules"):WaitForChild("PrivateConfig"),
	"PrivateConfig"
)
local gameConfig = safeRequire(
	ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"),
	"GameConfig"
)
local assetConfig = safeRequire(
	ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"),
	"AssetConfig"
)
local buildInfo = safeRequire(
	ReplicatedStorage:WaitForChild("Config"):WaitForChild("BuildInfo"),
	"BuildInfo"
)
local serverConfig = safeRequire(
	ServerScriptService:WaitForChild("Config"):WaitForChild("ServerConfig"),
	"ServerConfig"
)
local donationConfig = safeRequire(
	ServerScriptService:WaitForChild("DonationSystem"):WaitForChild("DonationServerHandler"):WaitForChild("DonationConfig"),
	"DonationConfig"
)

-- ============================================
-- IDENTITAS & AKSES
-- ============================================
if privateConfig then
	local owners = privateConfig.OwnerIds or {}
	if #owners == 0 or (owners[1] or 0) <= 0 then
		warnSetup("OwnerIds masih kosong. Isi dengan UserId pemilik experience.")
	end

	if (privateConfig.GroupId or 0) <= 0 then
		warnSetup("PrivateConfig.GroupId masih 0. Isi dengan GroupId komunitas pembeli.")
	end

	if gameConfig and (gameConfig.GroupId or 0) ~= (privateConfig.GroupId or 0) then
		warnSetup("GameConfig.GroupId dan PrivateConfig.GroupId berbeda. Samakan keduanya.")
	end

	if buildInfo and (privateConfig.ConfigSchema or 0) ~= buildInfo.CONFIG_SCHEMA then
		warnSetup(
			"ConfigSchema tidak cocok: PrivateConfig="
				.. tostring(privateConfig.ConfigSchema)
				.. ", Core="
				.. tostring(buildInfo.CONFIG_SCHEMA)
				.. ". Ikuti panduan migrasi config."
		)
	end

	local webhook = tostring(privateConfig.SaweriaWebhookURL or "")
	if webhook == "" then
		warnSetup("SaweriaWebhookURL kosong. Isi URL Apps Script pembeli atau matikan fitur Saweria.")
	elseif not webhook:match("^https://") then
		warnSetup("SaweriaWebhookURL harus diawali https://.")
	end

	local gamepasses = privateConfig.GamePasses or {}
	local vipPasses = gamepasses.VIP
	if type(vipPasses) ~= "table" or #vipPasses == 0 or (vipPasses[1] or 0) <= 0 then
		warnSetup("GamePasses.VIP belum diisi dengan GamePass pembeli.")
	end

	local activePasses = privateConfig.ActiveGamepasses or {}
	if (activePasses.VIP or 0) <= 0 then
		warnSetup("ActiveGamepasses.VIP belum diisi dengan GamePass pembeli.")
	end

	if (privateConfig.GiftProducts and privateConfig.GiftProducts.VIP or 0) <= 0 then
		warnSetup("GiftProducts.VIP belum diisi dengan Developer Product pembeli.")
	end
end

-- ============================================
-- PRODUK DONASI
-- ============================================
if donationConfig then
	local products = donationConfig.PRODUCTS or {}
	if #products == 0 then
		warnSetup("DonationConfig.PRODUCTS kosong.")
	else
		for index, product in ipairs(products) do
			if (product.id or 0) <= 0 then
				warnSetup("DonationConfig.PRODUCTS[" .. index .. "].id belum diisi.")
			end
			if (product.price or 0) <= 0 then
				warnSetup("DonationConfig.PRODUCTS[" .. index .. "].price belum diisi.")
			end
		end
	end
end

-- ============================================
-- ASET WAJIB
-- ============================================
if assetConfig then
	if assetConfig.Sounds == nil or assetConfig.Images == nil or assetConfig.Animations == nil then
		warnSetup("AssetConfig tidak lengkap. Periksa Sounds, Images, dan Animations.")
	end
end

-- ============================================
-- INSTANCE WAJIB
-- ============================================
local requiredInstances = {
	{ StarterGui, "PlayerMenuHandler" },
	{ StarterGui, "SettingGui" },
	{ StarterGui, "MusicPlayer" },
	{ StarterGui, "EmoteGui" },
	{ StarterGui, "SaweriaDonationGui" },
	{ StarterGui, "GamepassShop" },
	{ StarterGui, "DonationBoard" },
	{ StarterGui, "AdminPanel" },
	{ Workspace, "Leaderboard" },
	{ Workspace, "StageEffects" },
	{ Workspace, "ActiveEffects" },
	{ Workspace, "ScreenText" },
	{ ServerStorage, "Items" },
	{ ReplicatedStorage, "UI" },
	{ ReplicatedStorage, "Emotes" },
	{ ReplicatedStorage, "Sounds" },
	{ ReplicatedStorage, "VFX" },
	{ ReplicatedStorage, "Modules" },
}

for _, entry in ipairs(requiredInstances) do
	local parent, name = entry[1], entry[2]
	if parent:FindFirstChild(name) == nil then
		warnSetup("Instance wajib tidak ditemukan: " .. name)
	end
end

if Workspace:FindFirstChild("Kohl's Admin") == nil
	and ServerScriptService:FindFirstChild("Kohl's Admin") == nil then
	warnSetup("Kohl's Admin tidak ditemukan di Workspace maupun ServerScriptService.")
end

-- ============================================
-- HTTP
-- ============================================
local httpOk, httpEnabled = pcall(function()
	return HttpService.HttpEnabled
end)
if httpOk and not httpEnabled then
	warnSetup("HttpService.HttpEnabled masih false. Aktifkan HTTP Requests untuk Saweria/roproxy.")
end

local versionLabel = buildInfo
	and (
		"Core v"
			.. tostring(buildInfo.CORE_VERSION)
			.. " | "
			.. tostring(buildInfo.DEV_LABEL)
			.. " | Config schema "
			.. tostring(buildInfo.CONFIG_SCHEMA)
	)
	or "Core version tidak diketahui"

if warningCount == 0 then
	print("[SETUP] " .. versionLabel .. " - konfigurasi terlihat lengkap.")
else
	print(
		"[SETUP] "
			.. versionLabel
			.. " - pemeriksaan selesai: "
			.. warningCount
			.. " warning harus diperbaiki sebelum publish."
	)
end
