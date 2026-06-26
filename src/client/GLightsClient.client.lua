--!native
--!optimize 2
-- GLightsClient (Client) — Versi Baru Tanpa Beat Detection
-- Tidak ada Heartbeat loop, tidak ada sampling audio.
-- Hanya listen RemoteEvent GLightColorSync dari server,
-- lalu update neon + screen seketika saat warna ganti.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- ============================================================
-- SETUP GLIGHT CORE (tidak berubah dari versi lama)
-- ============================================================
local mainFolder = workspace:WaitForChild("GLights", 15)
if not mainFolder then
	warn("[GLights] Folder GLights tidak ditemukan di Workspace!")
	return
end

local function waitForEverythingToLoadIn()
	local folders = { "Custom", "FollowPoints", "Lights", "ResetButtons", "Scripts", "Whitelist" }
	for _, folderName in folders do
		mainFolder:WaitForChild(folderName, 10)
	end
end
waitForEverythingToLoadIn()

local coreFolder = mainFolder:WaitForChild("Scripts"):WaitForChild("Core")
local Core = require(coreFolder:WaitForChild("Main"))
local cores = {}

local function main()
	local currentData = coreFolder.Events.GetCurrentData:InvokeServer()
	for _, data in currentData do
		task.spawn(function()
			local core = Core.new(data.Settings, data.ID, data.IndexerIDs)
			cores[data.ID] = core
			core.Changer.State = data.State
			for _, id in cores[data.ID].Indexer.Motors.All do
				core.Changer:ApplySingleLightState(id)
			end
			for _, id in cores[data.ID].Indexer.All do
				core.Changer:ApplySingleLensState(id)
			end
			core.Changer:ApplyGenericState()
		end)
	end
	for _, event in coreFolder.Events:GetChildren() do
		if event:IsA("RemoteEvent") then
			local name = event.Name
			event.OnClientEvent:Connect(function(id, ...)
				if cores[id] and cores[id].Changer[name] then
					cores[id].Changer[name](cores[id].Changer, ...)
				end
			end)
		end
	end
end
main()

-- ============================================================
-- NEON & LAMPU (tag "LampuDJ")
-- ============================================================
local daftarNeon  = {} -- [BasePart/MeshPart] = true
local daftarLampu = {} -- [Light] = originalBrightness

local function registerNeon(obj)
	if obj:IsA("BasePart") or obj:IsA("MeshPart") then
		obj.Material = Enum.Material.Neon
		daftarNeon[obj] = true
	elseif obj:IsA("Light") then
		daftarLampu[obj] = obj.Brightness
	end
end

for _, obj in ipairs(CollectionService:GetTagged("LampuDJ")) do
	registerNeon(obj)
end
CollectionService:GetInstanceAddedSignal("LampuDJ"):Connect(registerNeon)
CollectionService:GetInstanceRemovedSignal("LampuDJ"):Connect(function(obj)
	daftarNeon[obj]  = nil
	daftarLampu[obj] = nil
end)

-- ============================================================
-- SCREEN (tag "ScreenDJ")
-- Semua BasePart/SurfaceGui bertag ScreenDJ ikut warna glight
-- ============================================================
local daftarScreen = {} -- [BasePart] = true

local function registerScreen(obj)
	if obj:IsA("BasePart") or obj:IsA("MeshPart") then
		daftarScreen[obj] = true
	end
end

for _, obj in ipairs(CollectionService:GetTagged("ScreenDJ")) do
	registerScreen(obj)
end
CollectionService:GetInstanceAddedSignal("ScreenDJ"):Connect(registerScreen)
CollectionService:GetInstanceRemovedSignal("ScreenDJ"):Connect(function(obj)
	daftarScreen[obj] = nil
end)

-- ============================================================
-- APPLY WARNA — dipanggil SEKALI saat warna ganti
-- Efek ganti warna secara INSTAN untuk mengurangi lag drastis.
-- Tidak menggunakan TweenService agar tidak mengubah ratusan part setiap frame.
-- ============================================================
local BLACK = Color3.new(0, 0, 0)

local function setColors(newColor)
	for neon in pairs(daftarNeon) do
		if neon.Parent then
			neon.Color = newColor
		end
	end
	for screen in pairs(daftarScreen) do
		if screen.Parent then
			screen.Color = newColor
		end
	end
	for lampu, origBright in pairs(daftarLampu) do
		if lampu.Parent then
			lampu.Color = newColor
			lampu.Brightness = (newColor == BLACK) and 0 or origBright
		end
	end
end

local function applyColor(color)
	setColors(color)
end

local function turnOffAll()
	setColors(BLACK)
end

-- ============================================================
-- 🔥 LIGHTWEIGHT COLOR LOOP (Super Ringan 0% FPS Drop)
-- ============================================================
local SoundService = game:GetService("SoundService")

-- Cari sumber lagu yang diputar oleh server
local sound = SoundService:WaitForChild("ServerMusicSound", 30)

-- Palet Warna Panggung
local stageColors = {
	Color3.fromRGB(255, 0, 50),   -- Merah Neon
	Color3.fromRGB(0, 255, 100),  -- Hijau Neon
	Color3.fromRGB(50, 100, 255), -- Biru Neon
	Color3.fromRGB(255, 0, 255),  -- Pink/Ungu
	Color3.fromRGB(255, 200, 0),  -- Emas/Kuning
	Color3.fromRGB(0, 255, 255),  -- Cyan
	Color3.fromRGB(255, 255, 255) -- Putih Terang
}

local isMusicPlaying = false

local function pickRandomColor()
	-- Trik AAA: Gunakan ServerTime agar warna selalu sama persis
	-- di semua HP pemain (Sync tanpa server lag).
	local timeSeed = math.floor(workspace:GetServerTimeNow() / 1.5) 
	local rng = Random.new(timeSeed)
	return stageColors[rng:NextInteger(1, #stageColors)]
end

task.spawn(function()
	while true do
		task.wait(1.5) -- Ganti warna dengan santai setiap 1.5 detik
		
		if not sound or not sound.IsPlaying then 
			if isMusicPlaying then
				isMusicPlaying = false
				turnOffAll() -- Matikan lampu panggung jika lagu dijeda/berhenti
			end
		else
			isMusicPlaying = true
			applyColor(pickRandomColor())
		end
	end
end)

-- Dummy listener for GLights Color event to prevent Remote Event Queue Exhausted error
task.spawn(function()
	local coreScripts = mainFolder:WaitForChild("Scripts", 5)
	if coreScripts then
		local core = coreScripts:WaitForChild("Core", 5)
		if core then
			local events = core:WaitForChild("Events", 5)
			if events then
				local colorEvent = events:WaitForChild("Color", 5)
				if colorEvent and colorEvent:IsA("RemoteEvent") then
					colorEvent.OnClientEvent:Connect(function()
						-- do nothing
					end)
				end
			end
		end
	end
end)
