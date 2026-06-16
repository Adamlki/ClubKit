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
-- 🚀 PRELOAD ALL ANIMATIONS (ContentProvider Fix)
-- ============================================
function module.preloadAnimations(animationFolder)
	if isPreloaded then
		debug("Already preloaded, skipping...")
		return true
	end

	debug("⏳ Starting preload via ContentProvider...")

	local animationsToPreload = {}

	-- Collect all animations
	for _, anim in ipairs(animationFolder:GetDescendants()) do
		if anim:IsA("Animation") then
			table.insert(animationsToPreload, anim)
		end
	end

	debug("Found", #animationsToPreload, "animations to preload")

	-- Unduh aset ke memori HP/PC secara non-blocking
	task.spawn(function()
		local success, err = pcall(function()
			ContentProvider:PreloadAsync(animationsToPreload)
		end)
			
		if success then
			isPreloaded = true
			debug("✅ Successfully preloaded all animations!")
		else
			warn("[AnimPreloader] Failed to preload:", err)
		end
	end)

	-- Return true agar tidak nge-block script yang memanggilnya
	return true
end

-- ============================================
-- 🔄 GET PRELOADED TRACK (Just-In-Time Loading)
-- ============================================
function module.getPreloadedTrack(animation)
	local animator = getAnimator()
	if not animator then return nil end

	-- Load JIT (Just-In-Time) saat tarian benar-benar akan diputar
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	
	if success then
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
	-- Tidak ada cache manual yang perlu dihapus lagi karena kita JIT loading
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
	isPreloaded = false
	debug("✅ State cleared")
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