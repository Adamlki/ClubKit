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
-- Tidak ada loop, tidak ada tween per-frame
-- Efek ganti warna: redup ke hitam dulu → lalu nyala warna baru
-- Semua pakai TweenService — nol Heartbeat loop, nol beban HP
-- ============================================================
local FADE_OUT_TIME = 0.10  -- seberapa cepat redup ke hitam (detik)
local FADE_IN_TIME  = 0.20  -- seberapa cepat nyala warna baru (detik)
local BLACK = Color3.new(0, 0, 0)

local TWEEN_OUT = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TWEEN_IN  = TweenInfo.new(FADE_IN_TIME,  Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local activeTweens = {}  -- [obj] = tween aktif saat ini
local pendingColor  = nil -- warna terakhir yang diminta (buat skip kalau ganti cepat)

local function cancelAll()
	for obj, tw in pairs(activeTweens) do
		tw:Cancel()
		activeTweens[obj] = nil
	end
end

-- Tween semua objek ke target warna, simpan tween-nya
local function tweenAllTo(color, tweenInfo)
	for neon in pairs(daftarNeon) do
		if neon.Parent then
			local tw = TweenService:Create(neon, tweenInfo, { Color = color })
			activeTweens[neon] = tw
			tw:Play()
		end
	end
	for screen in pairs(daftarScreen) do
		if screen.Parent then
			local tw = TweenService:Create(screen, tweenInfo, { Color = color })
			activeTweens[screen] = tw
			tw:Play()
		end
	end
	-- Lampu: langsung set brightness (tidak perlu tween, tidak keliatan artifak)
	for lampu, origBright in pairs(daftarLampu) do
		if lampu.Parent then
			lampu.Color = color
			lampu.Brightness = (color == BLACK) and 0 or origBright
		end
	end
end

-- Efek utama: redup → nyala warna baru
-- Kalau warna ganti lagi sebelum selesai, tween lama di-cancel dan mulai dari posisi saat ini
local colorTransitionActive = false

local function applyColorWithFlash(color)
	pendingColor = color
	if colorTransitionActive then return end -- biarkan yang aktif selesai fade out, lalu ambil warna terbaru

	colorTransitionActive = true
	task.spawn(function()
		-- FASE 1: Redup ke hitam
		cancelAll()
		tweenAllTo(BLACK, TWEEN_OUT)
		task.wait(FADE_OUT_TIME)

		-- Ambil warna terbaru (kalau ganti lagi saat fade out)
		local targetColor = pendingColor

		-- FASE 2: Nyala warna baru
		cancelAll()
		tweenAllTo(targetColor, TWEEN_IN)

		colorTransitionActive = false
	end)
end

local function turnOffAll()
	pendingColor = BLACK
	cancelAll()
	tweenAllTo(BLACK, TWEEN_OUT)
	colorTransitionActive = false
end

-- ============================================================
-- 🔥 ARCHITECT FIX: 100% LOCAL BEAT DETECTION (0 PING SERVER)
-- ============================================================
local SoundService = game:GetService("SoundService")
local RunService   = game:GetService("RunService")

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

local lastBeatTime = 0
local beatCount = 0
local FALLBACK_INTV = 2
local isMusicPlaying = false

local function pickRandomColor()
	-- Trik AAA: Gunakan ServerTime sebagai "benih" acak. 
	-- Hasilnya: Walau dihitung sendiri-sendiri oleh 100 HP pemain, 
	-- warna yang muncul di 100 layar HP akan SELALU SAMA PERSIS detik itu juga!
	local timeSeed = math.floor(workspace:GetServerTimeNow() * 2) 
	local rng = Random.new(timeSeed)
	return stageColors[rng:NextInteger(1, #stageColors)]
end

RunService.RenderStepped:Connect(function()
	-- 1. Pastikan lagu ada dan sedang diputar
	if not sound or not sound.IsPlaying then 
		if isMusicPlaying then
			isMusicPlaying = false
			turnOffAll() -- Matikan lampu panggung jika lagu dijeda/berhenti
		end
		return 
	end

	isMusicPlaying = true

	-- 2. BACA BASS LANGSUNG DARI SPEAKER HP PEMAIN!
	local loudness = sound.PlaybackLoudness / 1000
	local now = tick()

	-- 3. LOGIKA DENTUMAN BASS
	if loudness > 0.25 then
		-- Cooldown anti-epilepsi (maksimal ganti warna 4 kali per detik)
		if now - lastBeatTime > 0.25 then 
			lastBeatTime = now
			local interval = (loudness > 0.55) and 1 or 2
			beatCount = beatCount + 1

			if beatCount >= interval then
				beatCount = 0
				applyColorWithFlash(pickRandomColor())
			end
		end

		-- 4. LOGIKA LAGU SEPI (Misal intro lagu atau vokalnya saja)
	elseif now - lastBeatTime >= FALLBACK_INTV then
		lastBeatTime = now
		applyColorWithFlash(pickRandomColor())
	end
end)
