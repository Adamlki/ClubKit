--!native
--!optimize 2
local Players = game:GetService("Players")

local module = {}

-- Cache dengan weak keys agar otomatis dibersihkan GC
local trackCache = setmetatable({}, { __mode = "k" })

-- Reference ke AnimationPreloader (di-set oleh EmoteHandler di client)
module.AnimationPreloader = nil

local function getLocalAnimator()
	local localPlayer = Players.LocalPlayer
	local character = localPlayer and localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function isLocalAnimator(animator)
	return animator ~= nil and animator == getLocalAnimator()
end

-- Animation Set untuk O(1) lookup isDanceTrack
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

-- Check apakah track adalah dance track
local function isDanceTrack(track, loadedAnimations)
	if not track or not loadedAnimations then return false end
	if not track.Animation then return false end

	local asSet = animationSetFrom(loadedAnimations)
	if asSet and asSet[track.Animation] then return true end
	if track.Name and loadedAnimations[track.Name] then return true end

	return false
end

-- Character Readiness Check
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

-- Get or Create Animation Track
function module.getOrCreateTrack(animator, animation)
	if not animator or not animation then return nil end
	if not animator.Parent or not animator.Parent.Parent then return nil end

	-- Preloader hanya aman untuk animator LocalPlayer. Untuk karakter remote,
	-- LoadAnimation harus dibuat pada animator karakter itu sendiri.
	if module.AnimationPreloader and isLocalAnimator(animator) then
		local preloadedTrack = module.AnimationPreloader.getPreloadedTrack(animation, animator)
		if preloadedTrack then
			local trackValid = false
			pcall(function()
				trackValid = preloadedTrack.Animation ~= nil and typeof(preloadedTrack.Length) == "number"
			end)

			if trackValid then
				return preloadedTrack
			else
				module.AnimationPreloader.invalidateTrack(animation, animator)
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
			isValid = track.Animation ~= nil
				and typeof(track.Length) == "number" -- Pastikan track belum ter-destroy secara instance!
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

-- Get Currently Playing Dance Track
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

-- Stop All Dance Tracks
function module.stopAllDances(animator, loadedAnimations, fadeOut)
	if not animator or not animator.Parent then return end
	fadeOut = (fadeOut ~= nil) and fadeOut or 0.5

	local tracks
	local success = pcall(function()
		tracks = animator:GetPlayingAnimationTracks()
	end)

	if not success or not tracks then return end

	for _, t in ipairs(tracks) do
		if isDanceTrack(t, loadedAnimations) or t.Priority == Enum.AnimationPriority.Action4 then
			pcall(function()
				t:Stop(fadeOut)
			end)
		end
	end
end

-- Stop all dances EXCEPT specified track
function module.stopOtherDances(animator, excludeTrack, loadedAnimations, fadeOut)
	if not animator or not animator.Parent then return end
	fadeOut = (fadeOut ~= nil) and fadeOut or 0.06

	local tracks
	local success = pcall(function()
		tracks = animator:GetPlayingAnimationTracks()
	end)

	if not success or not tracks then return end

	for _, t in ipairs(tracks) do
		if t ~= excludeTrack and (isDanceTrack(t, loadedAnimations) or t.Priority == Enum.AnimationPriority.Action4) then
			pcall(function() t:Stop(fadeOut) end)
		end
	end
end

-- Sisakan hanya track remote yang masih dipakai. Track local tidak disentuh
-- karena dipegang AnimationPreloader untuk seluruh katalog.
function module.pruneTracks(animator, keep)
	if not animator or not keep then return end
	if isLocalAnimator(animator) then return end

	local perAnimator = trackCache[animator]
	if not perAnimator then return end

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

-- Hapus satu track remote dengan aman.
function module.evictTrack(animator, animation, track)
	if not animator or not animation or isLocalAnimator(animator) then return end
	local perAnimator = trackCache[animator]
	if not perAnimator then return end

	local cached = perAnimator[animation]
	if track and cached and cached ~= track then return end
	perAnimator[animation] = nil
	if cached then
		pcall(function()
			cached:Stop(0)
			cached:Destroy()
		end)
	end
end

-- Clear Cache (panggil saat karakter mati)
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

-- Strip AnimationId ke angka saja
function module.stripAnimationId(id)
	if not id then return "" end
	return string.match(id, "%d+") or ""
end

-- Auto-Cleanup Event (Mencegah Memory Leak)
local function setupAutoCleanup(player)
	player.CharacterRemoving:Connect(function(character)
		-- Menggunakan referensi 'character' yang sedang dihapus
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator and trackCache[animator] then
				for _, track in pairs(trackCache[animator]) do
					pcall(function() track:Destroy() end)
				end
				trackCache[animator] = nil
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupAutoCleanup)
for _, p in ipairs(Players:GetPlayers()) do
	setupAutoCleanup(p)
end

return module
