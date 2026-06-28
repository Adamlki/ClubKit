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
-- CORE INITIALIZATION DIHAPUS (Bypass Penuh)
-- ============================================================

-- ============================================================
-- NEON & LAMPU (tag "LampuDJ")
-- ============================================================
local daftarNeon  = {} -- [BasePart/MeshPart] = true
local daftarLampu = {} -- [Light] = originalBrightness
local daftarBeam  = {} -- [Beam] = true

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
-- FALLBACK GLIGHTS INITIALIZER (BYPASS CORE.MAIN)
-- Mencari manual semua lampu GLights tanpa menjalankan mesin Physics Motor
-- ============================================================
local function setupFallbackGLights()
	local lightsFolder = workspace:FindFirstChild("GLights")
	if not lightsFolder then return end
	lightsFolder = lightsFolder:FindFirstChild("Lights")
	if not lightsFolder then return end

	for _, descendant in ipairs(lightsFolder:GetDescendants()) do
		if descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
			descendant.Enabled = true
			daftarLampu[descendant] = descendant.Brightness > 0 and descendant.Brightness or 2
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
			daftarBeam[descendant] = true
		elseif descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			-- Biasa namanya "Lens", "Neon", atau "Light"
			if name:find("lens") or name:find("neon") then
				descendant.Material = Enum.Material.Neon
				daftarNeon[descendant] = true
			end
		end
	end
end
setupFallbackGLights()

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
	local beamColorSequence = ColorSequence.new(newColor)
	for beam in pairs(daftarBeam) do
		if beam.Parent then
			beam.Color = beamColorSequence
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

-- Dummy listener dihapus karena server tidak lagi mengirim event jika GLights dihapus
