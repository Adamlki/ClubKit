local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local module = {}

local CONFIG = {
	DEBUG_ENABLED = false,
	PRELOAD_ON_SPAWN = false,
	PRELOAD_DELAY = 2,
	MAX_PRELOAD = math.huge,
	BATCH_SIZE = 25,
}

local isPreloaded = false
local preloadStarted = false
local preloadFinished = false

local function debug(...)
	if CONFIG.DEBUG_ENABLED then
		print("[AnimPreloader]", ...)
	end
end

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

function module.preloadAnimations(animationFolder)
	if preloadStarted then
		return true
	end
	preloadStarted = true
	isPreloaded = true

	task.spawn(function()
		local animationsToPreload = {}

		for _, child in ipairs(animationFolder:GetChildren()) do
			if child:IsA("Animation") then
				table.insert(animationsToPreload, child)
			end
		end

		local poseFolder = animationFolder:FindFirstChild("Pose")
		if poseFolder then
			for _, child in ipairs(poseFolder:GetChildren()) do
				if child:IsA("Animation") then
					table.insert(animationsToPreload, child)
				end
			end
		end

		debug("Starting background preload for", #animationsToPreload, "animations...")

		local batchSize = math.max(1, CONFIG.BATCH_SIZE)
		for i = 1, #animationsToPreload, batchSize do
			local batch = {}
			for j = i, math.min(i + batchSize - 1, #animationsToPreload) do
				table.insert(batch, animationsToPreload[j])
			end
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			task.wait(0.02)
		end

		preloadFinished = true
		debug("All animations successfully cached locally!")
	end)

	return true
end

local loadedTrackCache = setmetatable({}, { __mode = "k" })

local function cacheFor(animator)
	local perAnimator = loadedTrackCache[animator]
	if not perAnimator then
		perAnimator = setmetatable({}, { __mode = "k" })
		loadedTrackCache[animator] = perAnimator
	end
	return perAnimator
end

function module.getPreloadedTrack(animation, animator)
	if not animation then return nil end
	animator = animator or getAnimator()
	if not animator then return nil end

	local perAnimator = cacheFor(animator)
	local cachedTrack = perAnimator[animation]
	if cachedTrack then
		local isValid = false
		pcall(function()
			isValid = cachedTrack.Animation ~= nil
				and typeof(cachedTrack.Length) == "number"
		end)
		if isValid then
			return cachedTrack
		end

		pcall(function() cachedTrack:Destroy() end)
		perAnimator[animation] = nil
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if success and track then
		perAnimator[animation] = track
		return track
	end

	warn("[AnimPreloader] Failed to load animation:", animation.Name)
	return nil
end

function module.invalidateTrack(animation, animator)
	animator = animator or getAnimator()
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

function module.evictTrack(animator, animation, track)
	if not animator or not animation then return end
	local perAnimator = loadedTrackCache[animator]
	if not perAnimator then return end

	local cached = perAnimator[animation]
	if track and cached and cached ~= track then
		return
	end

	perAnimator[animation] = nil
	if cached then
		pcall(function()
			cached:Stop(0)
			cached:Destroy()
		end)
	end
end

function module.pruneTracks(animator, keep)
	if not animator or not loadedTrackCache[animator] then return end
	if not keep then return end

	local perAnimator = loadedTrackCache[animator]
	for animation, track in pairs(perAnimator) do
		if not keep[track] then
			perAnimator[animation] = nil
			pcall(function()
				track:Stop(0)
				track:Destroy()
			end)
		end
	end
end

function module.isPreloaded()
	return isPreloaded
end

function module.isPreloadFinished()
	return preloadFinished
end

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

if CONFIG.PRELOAD_ON_SPAWN then
	local function setupPreload()
		if not player.Character then
			player.CharacterAdded:Wait()
		end

		local humanoid = player.Character:WaitForChild("Humanoid")
		player.Character:WaitForChild("HumanoidRootPart")

		task.wait(0.5)

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			warn("[AnimPreloader] No Animator found!")
			return
		end

		task.wait(CONFIG.PRELOAD_DELAY)

		local emotesFolder = ReplicatedStorage:WaitForChild("Emotes")

		module.preloadAnimations(emotesFolder)
	end

	task.spawn(setupPreload)

	player.CharacterAdded:Connect(function()
		module.clearCache()
		task.wait(1)
		setupPreload()
	end)
end

return module
