-- AutoGlight (Server) — Server-Side Beat Detection (Config Lengkap)
-- Semua deteksi beat jalan di SERVER, 1 instance untuk seluruh server.
-- HP client tidak ngapa-ngapain selain terima warna → tidak lag sama sekali.

local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local glightsFolder = game.Workspace:WaitForChild("GLights")
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
-- KONFIGURASI BEAT DETECTION (sama persis seperti versi client lama,
-- tapi sekarang jalan di SERVER — HP tidak kena beban sama sekali)
-- ============================================================
local SAMPLE_RATE       = 1 / 120  -- sample 120x per detik
local LOUDNESS_MAX      = 2000
local SMOOTHING_ALPHA   = 0.35
local HISTORY_SIZE      = 30
local BEAT_THRESHOLD    = 0.30
local BEAT_MIN_GAP      = 0.10
local ADAPTIVE_MULT     = 0.12
local ADAPTIVE_MIN      = 0.12
local ADAPTIVE_MAX      = 0.70
local BASS_SMOOTHING    = 0.30
local BASS_ENERGY_DECAY = 0.78
local BASS_PEAK_MULT    = 1.70
local BASS_LONG_SIZE    = 90

-- Ganti warna setiap N beat sesuai intensitas bass
-- (sama logikanya seperti GlightBeatDetecter lama)
local FALLBACK_INTV     = 0.45  -- ganti warna kalau lama tidak ada beat

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
-- RING BUFFER (sama persis seperti versi lama)
-- ============================================================
local function newRingBuffer(size)
	local data, head, count = table.create(size, 0), 1, 0
	return {
		push = function(v)
			data[head] = v
			head = (head % size) + 1
			if count < size then count += 1 end
		end,
		avg = function()
			if count == 0 then return 0 end
			local s = 0
			for i = 1, count do s += data[i] end
			return s / count
		end,
		avgFiltered = function(minVal)
			local s, c = 0, 0
			for i = 1, count do
				if data[i] > minVal then s += data[i]; c += 1 end
			end
			return c > 0 and (s / c) or 0
		end,
		size = function() return count end,
		reset = function()
			data = table.create(size, 0)
			head = 1; count = 0
		end,
	}
end

-- ============================================================
-- STATE
-- ============================================================
local isPlaying       = false
local soundPlaying    = false
local colorChaseStep  = 0
local AM_colorBeatCount = 0
local lastBeatTime    = 0
local lastColorTime   = 0
local lastSampleTime  = 0
local currentStagePhase = 0

local smoothedLoudness = 0
local bassAvgShort, bassAvgLong, bassEnergy, songBassLevel = 0, 0, 0, 0
local loudnessBuf = newRingBuffer(HISTORY_SIZE)
local bassLongBuf = newRingBuffer(BASS_LONG_SIZE)

local function resetState()
	loudnessBuf.reset(); bassLongBuf.reset()
	smoothedLoudness = 0
	bassAvgShort = 0; bassAvgLong = 0; bassEnergy = 0; songBassLevel = 0
	AM_colorBeatCount = 0; lastBeatTime = 0; lastColorTime = 0; lastSampleTime = 0
end

-- ============================================================
-- ADAPTIVE THRESHOLD (sama seperti versi lama)
-- ============================================================
local function getAdaptiveThreshold()
	if loudnessBuf.size() < 5 then return BEAT_THRESHOLD end
	local avg = loudnessBuf.avg()
	return math.clamp(avg + ADAPTIVE_MULT * avg, ADAPTIVE_MIN, ADAPTIVE_MAX)
end

-- ============================================================
-- BASS DETECTION (sama seperti versi lama)
-- ============================================================
local function updateBass(raw)
	bassAvgShort = bassAvgShort + (raw - bassAvgShort) * BASS_SMOOTHING
	bassAvgLong  = bassAvgLong  + (raw - bassAvgLong)  * 0.03
	local surge  = math.max(0, bassAvgShort - bassAvgLong)
	local normalized = math.clamp(surge / 0.20, 0, 1)

	bassEnergy = bassEnergy * BASS_ENERGY_DECAY
	if normalized > bassEnergy then bassEnergy = normalized end

	local isBassHit = (surge > bassAvgLong * BASS_PEAK_MULT) and (raw > 0.25)

	bassLongBuf.push(normalized)
	if bassLongBuf.size() >= 20 then
		songBassLevel = math.clamp(bassLongBuf.avgFiltered(0.08) * 2.2, 0, 1)
	end

	return bassEnergy, isBassHit, songBassLevel
end

-- ============================================================
-- MOTOR & PHASE
-- ============================================================
local function setStagePhase(phase)
	if currentStagePhase == phase then return end
	currentStagePhase = phase
	local cfg = PHASE_CONFIGS[phase]
	if not cfg then return end
	safeRun("Heads", "Gobo", 0, "All")
	safeRun("Heads", "MotorSpeed", cfg.odd,  "Odd")
	safeRun("Heads", "MotorSpeed", cfg.even, "Even")
end

-- ============================================================
-- APPLY WARNA
-- ============================================================
local function applyColor(color)
	safeRun("Heads", "Color", color, "All")
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
	safeRun("Heads", "FadeOn", "All")
	safeRun("Heads", "Color", CHASE_RAINBOW[1], "All")
	safeRun("Heads", "Cue", "Position.Circle", true, "Odd")
	safeRun("Heads", "Cue", "Position.Circle", true, "Even")
	currentStagePhase = 0
	setStagePhase(1)
end

local function stopAutoMove()
	safeRun("Heads", "Cue", "Position.Circle", false, "Odd")
	safeRun("Heads", "Cue", "Position.Circle", false, "Even")
	safeRun("Heads", "Pan", 0, "All")
	safeRun("Heads", "Tilt", 0, "All")
	safeRun("Heads", "FadeOff", "All")
	-- colorSyncRE:FireAllClients(nil, false) -- Dihapus karena tidak ada listener di client
end

-- ============================================================
-- STATIC COLOR LOOP — PENGGANTI BEAT LOOP (Sangat Ringan)
-- ============================================================
local function simpleColorLoop()
	while isPlaying do
		task.wait(0.5) -- Ganti warna setiap setengah detik secara konstan
		if sound.IsPlaying then
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
	resetState()
	task.delay(0.3, function()
		if isPlaying then
			startAutoMove()
			-- 🔥 ARCHITECT FIX: Gunakan loop statis ringan tanpa mendeteksi Audio Loudness (yang nilainya 0 di Server)
			task.spawn(simpleColorLoop) 
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
