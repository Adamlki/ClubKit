--!native
--!optimize 2
local module = {}

-- Cache dengan weak keys agar otomatis dibersihkan GC
local trackCache = setmetatable({}, { __mode = "k" })

-- Reference ke AnimationPreloader (di-set oleh EmoteHandler di client)
module.AnimationPreloader = nil

-- ============================================
-- Animation Set untuk O(1) lookup isDanceTrack
-- ============================================
local function animationSetFrom(loadedAnimations)
	if not loadedAnimations then return nil end
	if loadedAnimations.__asSet then return loadedAnimations.__asSet end

	local set = setmetatable({}, { __mode = "k" })
	for _, animObj in pairs(loadedAnimations) do
		if typeof(animObj) == "Instance" and animObj:IsA("Animation") then
			set[animObj] = true
		end
	end

	loadedAnimations.__asSet = set
	return set
end

-- ============================================
-- Check apakah track adalah dance track
-- ============================================
local function isDanceTrack(track, loadedAnimations)
	if not track or not loadedAnimations then return false end
	if not track.Animation then return false end

	local asSet = animationSetFrom(loadedAnimations)
	if asSet and asSet[track.Animation] then return true end
	if track.Name and loadedAnimations[track.Name] then return true end

	return false
end

-- ============================================
-- Character Readiness Check
-- ============================================
function module.isCharacterReady(player)
	if not player or not player.Parent then return false end
	if not player.Character or not player.Character.Parent then return false end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.Parent then return false end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator or not animator.Parent then return false end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp.Parent then return false end

	return true
end

function module.getAnimator(player)
	if not module.isCharacterReady(player) then return nil end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid:FindFirstChildOfClass("Animator")
end

-- ============================================
-- Get or Create Animation Track
-- ============================================
function module.getOrCreateTrack(animator, animation)
	if not animator or not animation then return nil end
	if not animator.Parent or not animator.Parent.Parent then return nil end

	-- Coba preloaded track dulu (client side)
	if module.AnimationPreloader then
		local preloadedTrack = module.AnimationPreloader.getPreloadedTrack(animation)
		if preloadedTrack then
			local trackValid = false
			pcall(function()
				trackValid = preloadedTrack.Parent == animator and preloadedTrack.Animation ~= nil
			end)

			if trackValid then
				return preloadedTrack
			else
				module.AnimationPreloader.invalidateTrack(animation)
			end
		end
	end

	-- Fallback ke cache system
	local perAnimator = trackCache[animator]
	if not perAnimator then
		perAnimator = setmetatable({}, { __mode = "k" })
		trackCache[animator] = perAnimator
	end

	local track = perAnimator[animation]

	-- Validasi cached track — tambahkan cek IsPlaying
	if track then
		local isValid = false
		pcall(function()
			isValid = track.Parent == animator 
				and track.Animation ~= nil
				and typeof(track.Length) == "number" -- ✅ Pastikan track belum ter-destroy secara instance!
		end)

		if not isValid then
			pcall(function() track:Destroy() end)  -- ← tambah ini
			perAnimator[animation] = nil
			track = nil
		end
	end

	-- Buat track baru jika perlu
	if not track then
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if not ok or not loaded then return nil end

		perAnimator[animation] = loaded
		track = loaded
	end

	return track
end

-- ============================================
-- Get Currently Playing Dance Track
-- ============================================
function module.getPlayingDanceTrack(animator, loadedAnimations)
	if not animator or not animator.Parent then return nil end

	local tracks
	local success = pcall(function()
		tracks = animator:GetPlayingAnimationTracks()
	end)

	if not success or not tracks then return nil end

	for _, t in ipairs(tracks) do
		if isDanceTrack(t, loadedAnimations) then
			local hitName = nil
			for name, animObj in pairs(loadedAnimations or {}) do
				if typeof(animObj) == "Instance" and t.Animation == animObj then
					hitName = name
					break
				end
			end
			return t, (hitName or t.Name)
		end
	end

	return nil
end

-- ============================================
-- Stop All Dance Tracks
-- ============================================
function module.stopAllDances(animator, loadedAnimations, fadeOut)
	if not animator or not animator.Parent then return end
	fadeOut = (fadeOut ~= nil) and fadeOut or 0.06

	local tracks
	local success = pcall(function()
		tracks = animator:GetPlayingAnimationTracks()
	end)

	if not success or not tracks then return end

	for _, t in ipairs(tracks) do
		if isDanceTrack(t, loadedAnimations) then
			pcall(function() 
				t:AdjustSpeed(1) -- ✅ UNFREEZE SEBELUM STOP (Mencegah Zombie)
				t:Stop(fadeOut) 
			end)
		end
	end
end

-- ============================================
-- Stop all dances EXCEPT specified track
-- ============================================
function module.stopOtherDances(animator, excludeTrack, loadedAnimations, fadeOut)
	if not animator or not animator.Parent then return end
	fadeOut = (fadeOut ~= nil) and fadeOut or 0.06

	local tracks
	local success = pcall(function()
		tracks = animator:GetPlayingAnimationTracks()
	end)

	if not success or not tracks then return end

	for _, t in ipairs(tracks) do
		if t ~= excludeTrack and isDanceTrack(t, loadedAnimations) then
			pcall(function() t:Stop(fadeOut) end)
		end
	end
end

-- ============================================
-- Clear Cache (panggil saat karakter mati)
-- ============================================
function module.clearCacheForPlayer(player)
	if not player or not player.Character then return end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	-- TAMBAHKAN LOOP DESTROY MANUAL INI:
	if trackCache[animator] then
		for _, track in pairs(trackCache[animator]) do
			pcall(function() track:Destroy() end)
		end
	end

	trackCache[animator] = nil
end

-- ============================================
-- Strip AnimationId ke angka saja
-- ============================================
function module.stripAnimationId(id)
	if not id then return "" end
	return string.match(id, "%d+") or ""
end

return module
