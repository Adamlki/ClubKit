local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ContentProvider = game:GetService("ContentProvider")

-- Get the registry from correct path
local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local ServerModules = SyncServer:WaitForChild("Modules")
local AnimationRegistry = require(ServerModules:WaitForChild("AnimationRegistry"))

local module = {}

-- CACHE (prevents recreation on subsequent calls)
local animationCache = {}
local emotesFolder = nil

-- CREATE ANIMATION INSTANCE FROM ID
local function createAnimationInstance(name, animationId)
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = animationId
	return anim
end

-- MAIN: Initialize Emotes Folder
function module.initializeEmotesFolder()
	if emotesFolder then
		return emotesFolder
	end

	-- Create or get Emotes folder in ReplicatedStorage
	emotesFolder = ReplicatedStorage:FindFirstChild("Emotes")
	if not emotesFolder then
		emotesFolder = Instance.new("Folder")
		emotesFolder.Name = "Emotes"
		emotesFolder.Parent = ReplicatedStorage
	end

	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if not poseFolder then
		poseFolder = Instance.new("Folder")
		poseFolder.Name = "Pose"
		poseFolder.Parent = emotesFolder
	end

	-- Clear existing animations (in case of reload)
	for _, child in ipairs(emotesFolder:GetChildren()) do
		if child:IsA("Animation") then
			child:Destroy()
		end
	end

	for _, child in ipairs(poseFolder:GetChildren()) do
		if child:IsA("Animation") then
			child:Destroy()
		end
	end

	local animCount = 0

	for name, id in pairs(AnimationRegistry.Dances) do
		local anim = createAnimationInstance(name, id)
		anim.Parent = emotesFolder
		animationCache[name] = anim
		animCount = animCount + 1
	end

	for name, id in pairs(AnimationRegistry.Poses) do
		local anim = createAnimationInstance(name, id)
		anim.Parent = poseFolder
		animationCache[name] = anim
		animCount = animCount + 1
	end

	-- Preload hanya di client; server tidak merender animasi.

	return emotesFolder
end

-- BUILD ANIMATION TABLE (For AnimationController)
function module.loadAnimations()
	if not emotesFolder then
		module.initializeEmotesFolder()
	end

	local animations = {}

	for name, anim in pairs(animationCache) do
		animations[name] = anim
	end

	return animations
end

-- HELPER: Get animation by name
function module.getAnimation(animName)
	if animationCache[animName] then
		return animationCache[animName]
	end

	-- Fallback to folder lookup
	if not emotesFolder then
		warn("[AnimLoader] Emotes folder not initialized!")
		return nil
	end

	local anim = emotesFolder:FindFirstChild(animName)
	if anim and anim:IsA("Animation") then
		return anim
	end

	local poseFolder = emotesFolder:FindFirstChild("Pose")
	if poseFolder then
		anim = poseFolder:FindFirstChild(animName)
		if anim and anim:IsA("Animation") then
			return anim
		end
	end

	return nil
end

-- HELPER: Get category
function module.getAnimationCategory(animName)
	return AnimationRegistry.getCategory(animName) or "Dance"
end

-- HELPER: Get all by category
function module.getAnimationsByCategory(category)
	local results = {}

	if category == "Dance" then
		for _, anim in ipairs(emotesFolder:GetChildren()) do
			if anim:IsA("Animation") then
				table.insert(results, anim)
			end
		end
	elseif category == "Pose" then
		local poseFolder = emotesFolder:FindFirstChild("Pose")
		if poseFolder then
			for _, anim in ipairs(poseFolder:GetChildren()) do
				if anim:IsA("Animation") then
					table.insert(results, anim)
				end
			end
		end
	end

	return results
end

-- VALIDATE
function module.validateAnimation(animName)
	return AnimationRegistry.exists(animName)
end

function module.getValidatedAnimation(animName)
	if not module.validateAnimation(animName) then
		warn("[AnimLoader] Security: Attempted to load invalid animation:", animName)
		return nil
	end

	return module.getAnimation(animName)
end

-- GET TOTAL COUNT
function module.getCount()
	return AnimationRegistry.getCount()
end

return module
