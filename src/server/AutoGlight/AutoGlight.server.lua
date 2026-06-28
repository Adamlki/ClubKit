-- AutoGlight (Server) — Server-Side Beat Detection (Config Lengkap)
-- Semua deteksi beat jalan di SERVER, 1 instance untuk seluruh server.
-- HP client tidak ngapa-ngapain selain terima warna → tidak lag sama sekali.

local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local glightsFolder = game.Workspace:FindFirstChild("GLights")
if not glightsFolder then return end
local Panel = require(glightsFolder:WaitForChild("Scripts"):WaitForChild("Panels"):WaitForChild("Panel"))
local sound = SoundService:WaitForChild("ServerMusicSound", 30)
if not sound then return end

-- ============================================================
-- REMOTE
-- ============================================================
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
remotes.Name = "Remotes"

local colorSyncRE = remotes:FindFirstChild("GLightColorSync")
if not colorSyncRE then
	colorSyncRE = Instance.new("RemoteEvent")
	colorSyncRE.Name = "GLightColorSync"
	colorSyncRE.Parent = remotes
end

-- ============================================================
-- GLIGHT PANEL SETUP
-- ============================================================
local MISSING_FOLDERS = {}
local foldersReady = false
local function folderExists(name) return Panel._ByFolderName[name] ~= nil end
local function safeRun(folder, func, ...)
	if not foldersReady or MISSING_FOLDERS[folder] then return end
	if not folderExists(folder) then MISSING_FOLDERS[folder] = true return end
	if Panel and typeof(Panel.Run) == "function" then
		pcall(Panel.Run, folder, func, ...)
	end
end
task.defer(function() task.wait(2); foldersReady = true end)

-- ============================================================
-- WARNA & MOTOR
-- ============================================================
local CHASE_RAINBOW = {
	Color3.fromRGB(255, 30,  30),
	Color3.fromRGB(255, 120,  0),
	Color3.fromRGB(240, 240,  0),
	Color3.fromRGB(0,   220, 60),
	Color3.fromRGB(0,   180, 255),
	Color3.fromRGB(30,   60, 255),
	Color3.fromRGB(160,   0, 255),
	Color3.fromRGB(255,   0, 180),
}

local PHASE_CONFIGS = {
	[1] = { odd = 0.004, even = 0.023 },
	[2] = { odd = 0.009, even = 0.023 },
	[3] = { odd = 0.018, even = 0.023 },
}

-- ============================================================
-- STATE
-- ============================================================
local isPlaying       = false
local soundPlaying    = false
local colorChaseStep  = 0
local currentStagePhase = 0

-- ============================================================
-- MOTOR & PHASE
-- ============================================================
local function setStagePhase(phase)
	if currentStagePhase == phase then return end
	currentStagePhase = phase
	local cfg = PHASE_CONFIGS[phase]
	if not cfg then return end
	-- OPTIMASI: Matikan eksekusi motor GLights yang berat
	-- safeRun("Heads", "Gobo", 0, "All")
	-- safeRun("Heads", "MotorSpeed", cfg.odd,  "Odd")
	-- safeRun("Heads", "MotorSpeed", cfg.even, "Even")
end

-- ============================================================
-- APPLY WARNA
-- ============================================================
local function applyColor(color)
	-- OPTIMASI: Client merender warna kelap-kelip secara independen (0 Lag)
	-- safeRun("Heads", "Color", color, "All")
	-- colorSyncRE:FireAllClients(color, true) -- Dihapus karena Client sudah memakai 100% Local Beat Detection
	lastColorTime = os.clock()
end

local function nextColor()
	colorChaseStep = (colorChaseStep % #CHASE_RAINBOW) + 1
	applyColor(CHASE_RAINBOW[colorChaseStep])
end

-- ============================================================
-- START / STOP
-- ============================================================
local function startAutoMove()
	-- OPTIMASI: Motor dimatikan sepenuhnya
	-- safeRun("Heads", "FadeOn", "All")
	-- safeRun("Heads", "Color", CHASE_RAINBOW[1], "All")
	-- safeRun("Heads", "Cue", "Position.Circle", true, "Odd")
	-- safeRun("Heads", "Cue", "Position.Circle", true, "Even")
	currentStagePhase = 0
	setStagePhase(1)
end

local function stopAutoMove()
	-- OPTIMASI: Motor dimatikan sepenuhnya
	-- safeRun("Heads", "Cue", "Position.Circle", false, "Odd")
	-- safeRun("Heads", "Cue", "Position.Circle", false, "Even")
	-- safeRun("Heads", "Pan", 0, "All")
	-- safeRun("Heads", "Tilt", 0, "All")
	-- safeRun("Heads", "FadeOff", "All")
	-- colorSyncRE:FireAllClients(nil, false) -- Dihapus karena tidak ada listener di client
end

-- ============================================================
-- STATIC COLOR LOOP — PENGGANTI BEAT LOOP (Sangat Ringan)
-- ============================================================
local loopVersion = 0
local function simpleColorLoop(version)
	while isPlaying and loopVersion == version do
		task.wait(0.5) -- Ganti warna setiap setengah detik secara konstan
		if sound.IsPlaying and loopVersion == version then
			nextColor()
		end
	end
end

-- ============================================================
-- MUSIC EVENTS
-- ============================================================
local function onMusicStarted()
	isPlaying = true
	colorChaseStep = 0
	currentStagePhase = 0
	
	-- 🔥 FIX: Gunakan Loop Version agar thread lama otomatis mati jika musik di-restart cepat
	loopVersion = loopVersion + 1
	local version = loopVersion
	
	task.delay(0.3, function()
		if isPlaying and loopVersion == version then
			startAutoMove()
			task.spawn(simpleColorLoop, version) 
		end
	end)
end

local function onMusicStopped()
	isPlaying = false
	stopAutoMove()
end

sound.Played:Connect(function()
	if soundPlaying then onMusicStopped(); task.wait(0.05) end
	soundPlaying = true; onMusicStarted()
end)
sound.Stopped:Connect(function()
	if not soundPlaying then return end
	soundPlaying = false; onMusicStopped()
end)
sound.Ended:Connect(function()
	if not soundPlaying then return end
	soundPlaying = false; onMusicStopped()
end)
task.defer(function()
	if sound.IsPlaying then soundPlaying = true; onMusicStarted() end
end)
