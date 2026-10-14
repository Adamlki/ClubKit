local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local module = {}

-- ============================================
-- CONFIG
-- ============================================
local CONFIG = {
	DEBUG_ENABLED = false,
	PRELOAD_ON_SPAWN = false,
	PRELOAD_DELAY = 2, -- Delay before starting preload (let character fully load)
}

-- ============================================
-- CACHE
-- ============================================
local isPreloaded = false

-- ============================================
-- DEBUG
-- ============================================
local function debug(...)
	if CONFIG.DEBUG_ENABLED then
		print("[AnimPreloader]", ...)
	end
end

-- ============================================
-- GET ANIMATOR
-- ============================================
local function getAnimator()
	if not player.Character then return nil end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[AnimPreloader] No Animator found!")
		return nil
	end

	return animator
end

-- ============================================
-- 🚀 HIGH-PERFORMANCE PRELOADER (0ms INSTANT PLAYBACK)
-- ============================================
-- Melakukan background streaming aset secara bertahap (batching)
-- agar saat pemain mengklik dance atau sync ke leader,
-- animasinya LANGSUNG berputar 0ms tanpa freeze "diem dulu"!
function module.preloadAnimations(animationFolder)
	if isPreloaded then
		return true
	end

	isPreloaded = true

	task.spawn(function()
		local animationsToPreload = {}
		for _, anim in ipairs(animationFolder:GetDescendants()) do
			if anim:IsA("Animation") then
				table.insert(animationsToPreload, anim)
			end
		end

		debug("Starting background preload for", #animationsToPreload, "animations...")

		-- Download aset dalam batch 25 item dengan jeda non-blocking
		-- agar tidak membebani network / CPU thread saat baru join
		local BATCH_SIZE = 25
		for i = 1, #animationsToPreload, BATCH_SIZE do
			local batch = {}
			for j = i, math.min(i + BATCH_SIZE - 1, #animationsToPreload) do
				table.insert(batch, animationsToPreload[j])
			end
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			task.wait(0.04)
		end

		debug("✅ All animations successfully cached locally!")
	end)

	return true
end

-- ============================================
-- 🔄 GET PRELOADED TRACK (Persistent Fast Cache)
-- ============================================
local loadedTrackCache = setmetatable({}, { __mode = "k" })

function module.getPreloadedTrack(animation)
	local animator = getAnimator()
	if not animator then return nil end

	local perAnimator = loadedTrackCache[animator]
	if not perAnimator then
		perAnimator = {}
		loadedTrackCache[animator] = perAnimator
	end

	local cachedTrack = perAnimator[animation]
	if cachedTrack then
		local isValid = false
		pcall(function()
			isValid = cachedTrack.Parent == animator and cachedTrack.Animation ~= nil and typeof(cachedTrack.Length) == "number"
		end)
		if isValid then
			return cachedTrack
		else
			pcall(function() cachedTrack:Destroy() end)
			perAnimator[animation] = nil
		end
	end

	-- Buat AnimationTrack dan simpan di cache agar pemanggilan berikutnya 0ms
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	
	if success and track then
		perAnimator[animation] = track
		return track
	else
		warn("[AnimPreloader] Failed to load animation:", animation.Name)
		return nil
	end
end

-- ============================================
-- 🗑️ INVALIDATE TRACK (CLEANUP)
-- ============================================
function module.invalidateTrack(animation)
	local animator = getAnimator()
	if animator and loadedTrackCache[animator] then
		local t = loadedTrackCache[animator][animation]
		if t then
			pcall(function()
				t:Stop(0)
				t:Destroy()
			end)
			loadedTrackCache[animator][animation] = nil
		end
	end
end

-- ============================================
-- CHECK IF PRELOADED
-- ============================================
function module.isPreloaded()
	return isPreloaded
end

-- ============================================
-- CLEAR CACHE (Call on character death/respawn)
-- ============================================
function module.clearCache()
	debug("🗑️ Clearing preload state...")
	for animator, perAnimator in pairs(loadedTrackCache) do
		if perAnimator then
			for _, track in pairs(perAnimator) do
				if typeof(track) == "Instance" and track:IsA("AnimationTrack") then
					pcall(function()
						track:Stop(0)
						track:Destroy()
					end)
				end
			end
		end
	end
	table.clear(loadedTrackCache)
	debug("✅ State cleared & tracks destroyed")
end

-- ============================================
-- AUTO PRELOAD ON CHARACTER SPAWN
-- ============================================
if CONFIG.PRELOAD_ON_SPAWN then
	local function setupPreload()
		if not player.Character then
			player.CharacterAdded:Wait()
		end

		-- Wait for character to fully load
		local humanoid = player.Character:WaitForChild("Humanoid")
		player.Character:WaitForChild("HumanoidRootPart")

		-- Wait for Animator
		task.wait(0.5)

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			warn("[AnimPreloader] No Animator found!")
			return
		end

		-- Additional delay for stability
		task.wait(CONFIG.PRELOAD_DELAY)

		-- Wait for animations to be loaded
		local emotesFolder = ReplicatedStorage:WaitForChild("Emotes")

		-- Preload from Emotes folder (includes Pose subfolder)
		module.preloadAnimations(emotesFolder)
	end

	-- Initial setup
	task.spawn(setupPreload)

	-- Setup on respawn
	player.CharacterAdded:Connect(function()
		module.clearCache()
		task.wait(1)
		setupPreload()
	end)
end

return module