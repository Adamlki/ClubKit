local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local module = {}

-- ============================================
-- CONFIG
-- ============================================
local CONFIG = {
	DEBUG_ENABLED = false,
	PRELOAD_ON_SPAWN = false,
	PRELOAD_DELAY = 2, -- Delay before starting preload (let character fully load)
	BATCH_SIZE = 5, -- Load animations in batches to avoid lag spikes
	BATCH_DELAY = 0.1 -- Delay between batches
}

-- ============================================
-- CACHE
-- ============================================
local preloadedTracks = {} -- [Animation] = AnimationTrack
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
-- ? PRELOAD ALL ANIMATIONS
-- ============================================
function module.preloadAnimations(animationFolder)
	if isPreloaded then
		debug("Already preloaded, skipping...")
		return
	end

	local animator = getAnimator()
	if not animator then
		warn("[AnimPreloader] Cannot preload - no animator")
		return
	end

	debug("?? Starting preload...")

	local animations = {}

	-- Collect all animations
	for _, anim in ipairs(animationFolder:GetDescendants()) do
		if anim:IsA("Animation") then
			table.insert(animations, anim)
		end
	end

	debug("Found", #animations, "animations to preload")

	local startTime = tick()
	local successCount = 0
	local failCount = 0

	-- Preload in batches
	for i = 1, #animations, CONFIG.BATCH_SIZE do
		local batch = {}

		for j = i, math.min(i + CONFIG.BATCH_SIZE - 1, #animations) do
			table.insert(batch, animations[j])
		end

		-- Load batch
		for _, anim in ipairs(batch) do
			local success, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)

			if success and track then
				preloadedTracks[anim] = track
				successCount = successCount + 1
				debug("?", anim.Name)
			else
				failCount = failCount + 1
				warn("[AnimPreloader] Failed to preload:", anim.Name)
			end
		end

		-- Small delay between batches
		if i + CONFIG.BATCH_SIZE <= #animations then
			task.wait(CONFIG.BATCH_DELAY)
		end
	end

	local loadTime = tick() - startTime

	-- FIX Bug 1: Hanya set isPreloaded = true jika minimal ada 1 animasi berhasil.
	-- Animasi yang gagal tidak akan menghalangi animasi lain yang sudah sukses di-cache.
	-- isPreloaded tetap false jika SEMUA animasi gagal, agar bisa di-retry.
	if successCount > 0 then
		isPreloaded = true
	end

	debug("??????????????????????????????")
	debug("? PRELOAD COMPLETE")
	debug(string.format("??  Time: %.2fs", loadTime))
	debug(string.format("? Success: %d", successCount))
	debug(string.format("? Failed: %d", failCount))
	if failCount > 0 then
		warn(string.format("[AnimPreloader] %d animation(s) failed to preload. They will fallback to on-demand loading.", failCount))
	end
	debug("??????????????????????????????")

	return successCount > 0
end

-- ============================================
-- GET PRELOADED TRACK (Use this in your system)
-- ============================================
function module.getPreloadedTrack(animation)
	return preloadedTracks[animation]
end

-- ============================================
-- FIX Bug 2: INVALIDATE TRACK (dipanggil oleh AnimatorUtils tapi fungsi ini tidak ada)
-- Menghapus track tertentu dari cache agar di-load ulang saat dibutuhkan
-- ============================================
function module.invalidateTrack(animation)
	if animation and preloadedTracks[animation] then
		pcall(function()
			preloadedTracks[animation]:Stop(0)
		end)
		preloadedTracks[animation] = nil
		debug("? Invalidated track:", animation.Name or "unknown")
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
	debug("?? Clearing preload cache...")

	-- Stop all tracks
	for _, track in pairs(preloadedTracks) do
		pcall(function()
			track:Stop(0)
		end)
	end

	preloadedTracks = {}
	isPreloaded = false

	debug("? Cache cleared")
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
		local animFolder = ReplicatedStorage:WaitForChild("StoredAnimations")
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