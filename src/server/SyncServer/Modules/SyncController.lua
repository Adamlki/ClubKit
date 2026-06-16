--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimatorUtils = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AnimatorUtils"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local syncNotificationRE = remotes:FindFirstChild("SyncNotification")
if not syncNotificationRE then
	syncNotificationRE = Instance.new("RemoteEvent")
	syncNotificationRE.Name = "SyncNotification"
	syncNotificationRE.Parent = remotes
end

local module = {}

-- ============================================
-- CONFIG
-- ============================================
local FADE_OUT = 0.5
local MAX_SYNC_DEPTH = 10
local DANCE_WALK_SPEED = 16 

-- PURE WALKSPEED MANAGEMENT
local function setDanceWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if not character:GetAttribute("OriginalWalkSpeed") then
			character:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		end
		humanoid.WalkSpeed = DANCE_WALK_SPEED
	end
end

local function restoreOriginalWalkSpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local origSpeed = character and character:GetAttribute("OriginalWalkSpeed")

	if humanoid and origSpeed then
		if humanoid.WalkSpeed == DANCE_WALK_SPEED then
			humanoid.WalkSpeed = origSpeed
		end
		character:SetAttribute("OriginalWalkSpeed", nil)
	end
end

local function waitForCharacterReady(player, timeout)
	if AnimatorUtils.isCharacterReady(player) then return true end

	-- Pengecekan aman tanpa memakan banyak thread CPU server
	local waited = 0
	while waited < (timeout or 5) do
		if AnimatorUtils.isCharacterReady(player) then return true end
		waited += task.wait(0.2) -- ✅ Dilonggarkan jadi 0.2
	end
	return false
end

-- ============================================
-- Core Logic
-- ============================================
function module.getSyncSource(player, depth, visitedPlayers)
	depth = depth or 0
	visitedPlayers = visitedPlayers or {}
	if not player or not player.Parent then return nil end
	if not player.Character or not player.Character.Parent then return nil end
	if depth >= MAX_SYNC_DEPTH then return player end
	if visitedPlayers[player] then
		player.Character:SetAttribute("Syncing", nil)
		return player
	end
	visitedPlayers[player] = true
	local syncTarget = player.Character:GetAttribute("Syncing")
	if not syncTarget or syncTarget == "" then return player end

	local targetPlayer = Players:FindFirstChild(syncTarget)
	if not targetPlayer or not targetPlayer.Parent or not targetPlayer.Character then
		player.Character:SetAttribute("Syncing", nil)
		return player
	end
	return module.getSyncSource(targetPlayer, depth + 1, visitedPlayers)
end

function module.getFollowerCount(player)
	if not player or not player.Parent or not player.Character then return 0 end
	local count = 0
	local playerName = player.Name
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Parent and p.Character then
			if p.Character:GetAttribute("Syncing") == playerName then count += 1 end
		end
	end
	return count
end

function module.isLeader(player)
	if not player or not player.Character then return false end
	local isLeader = player.Character:GetAttribute("IsLeader")
	local followerCount = player.Character:GetAttribute("FollowerCount") or 0
	return isLeader == true and followerCount > 0
end

function module.isFollowingPlayer(follower, leader)
	if not follower or not leader then return false end
	if not follower.Character or not leader.Character then return false end
	local success, ultimateLeader = pcall(module.getSyncSource, follower)
	return success and ultimateLeader == leader
end

function module.updateLeaderStatus(player)
	if not player or not player.Parent or not player.Character then return end
	local followerCount = module.getFollowerCount(player)
	if followerCount > 0 then
		player.Character:SetAttribute("IsLeader", true)
		player.Character:SetAttribute("FollowerCount", followerCount)
	else
		player.Character:SetAttribute("IsLeader", nil)
		player.Character:SetAttribute("FollowerCount", nil)
	end
end

-- ============================================
-- 🔥 ARCHITECT FIX: O(N) SYSTEM (0% LAG CPU)
-- Memangkas 10.000 perhitungan menjadi cuma 200!
-- ============================================
function module.updateAllLeaderStatus()
	-- 1. Buat memori sementara (Dictionary Cache)
	local followerCounts = {}

	-- 2. Baca seluruh data server HANYA 1 KALI 
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local target = p.Character:GetAttribute("Syncing")
			if target and target ~= "" then
				-- Tambahkan hitungan untuk leader tersebut
				followerCounts[target] = (followerCounts[target] or 0) + 1
			end
		end
	end

	-- 3. Terapkan hasilnya ke semua player HANYA 1 KALI
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local count = followerCounts[player.Name] or 0
			if count > 0 then
				player.Character:SetAttribute("IsLeader", true)
				player.Character:SetAttribute("FollowerCount", count)
			else
				player.Character:SetAttribute("IsLeader", nil)
				player.Character:SetAttribute("FollowerCount", nil)
			end
		end
	end
end

function module.stopAllFollowers(leaderPlayer, loadedAnimations)
	if not leaderPlayer then return 0 end
	local stoppedCount = 0
	local leaderName = leaderPlayer.Name
	for _, follower in ipairs(Players:GetPlayers()) do
		if follower ~= leaderPlayer and follower.Character then
			if follower.Character:GetAttribute("Syncing") == leaderName then
				local animator = AnimatorUtils.getAnimator(follower)
				--if animator then pcall(AnimatorUtils.stopAllDances, animator, loadedAnimations, FADE_OUT) end
				restoreOriginalWalkSpeed(follower)
				stoppedCount += 1
			end
		end
	end
	return stoppedCount
end

function module.forceUnsyncAllFollowers(leaderPlayer, loadedAnimations)
	if not leaderPlayer then return end
	local leaderName = leaderPlayer.Name

	task.spawn(function() -- ✅ BUNGKUS DI LUAR LOOP
		for _, follower in ipairs(Players:GetPlayers()) do
			if follower ~= leaderPlayer and follower.Character then
				if follower.Character:GetAttribute("Syncing") == leaderName then
					syncNotificationRE:FireClient(follower, "leader_left", leaderName)
					restoreOriginalWalkSpeed(follower)
					follower.Character:SetAttribute("Syncing", nil)
					follower.Character:SetAttribute("IsLeader", nil)
					follower.Character:SetAttribute("FollowerCount", nil)
				end
			end
		end
	end)
end

function module.unsyncPlayer(player, loadedAnimations)
	local animator = AnimatorUtils.getAnimator(player)
	if animator then
		--pcall(AnimatorUtils.stopAllDances, animator, loadedAnimations, FADE_OUT)
		-- HAPUS: task.wait(FADE_OUT)
	end
	restoreOriginalWalkSpeed(player)
	if player.Character then
		player.Character:SetAttribute("Syncing", nil)
		player.Character:SetAttribute("CurrentDanceID", nil)
	end

	local playerName = player.Name
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			if otherPlayer.Character:GetAttribute("Syncing") == playerName then
				local oa = AnimatorUtils.getAnimator(otherPlayer)
				if oa then --pcall(AnimatorUtils.stopAllDances, oa, loadedAnimations, FADE_OUT)
				end
				restoreOriginalWalkSpeed(otherPlayer)
				otherPlayer.Character:SetAttribute("Syncing", nil)
			end
		end
	end
end

function module.wouldCreateCircular(player, targetPlayer)
	if not player or not targetPlayer then return false end
	if player == targetPlayer then return true end
	if targetPlayer.Character and targetPlayer.Character:GetAttribute("Syncing") == player.Name then return true end
	local success, ultimateLeader = pcall(module.getSyncSource, targetPlayer)
	if success and ultimateLeader == player then return true end
	if player.Character then
		local playerSync = player.Character:GetAttribute("Syncing")
		if playerSync and playerSync ~= "" then
			local playerLeader = module.getSyncSource(player)
			if playerLeader == targetPlayer then return true end
		end
	end
	return false
end

-- ============================================
-- Handle Sync Request
-- ============================================
function module.handleSyncRequest(player, targetPlayer, condition, loadedAnimations)
	if not targetPlayer or typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end
	if not waitForCharacterReady(player, 3) then return end
	if condition and not waitForCharacterReady(targetPlayer, 3) then return end

	-- 🔥 VALIDASI ASINKRON: Pastikan kedua player belum keluar server saat Yielding 3 detik
	if not player or not player.Parent or not targetPlayer or not targetPlayer.Parent then return end

	if condition and module.isLeader(player) and module.isFollowingPlayer(targetPlayer, player) then
		syncNotificationRE:FireClient(player, "leader_blocked", targetPlayer.Name)
		return
	end

	if condition and module.wouldCreateCircular(player, targetPlayer) then
		syncNotificationRE:FireClient(player, "circular_blocked", targetPlayer.Name)
		return
	end

	local animator = AnimatorUtils.getAnimator(player)
	if not animator then return end

	local currentSyncTarget = player.Character and player.Character:GetAttribute("Syncing")

	if condition then
		local success, trueLeaderOfTarget = pcall(module.getSyncSource, targetPlayer)
		if not success or not trueLeaderOfTarget then return end

		if currentSyncTarget == trueLeaderOfTarget.Name then
			module.unsyncPlayer(player, loadedAnimations)
			syncNotificationRE:FireClient(player, "unsync_success")
			module.updateLeaderStatus(trueLeaderOfTarget)
		else
			if player.Character then
				--pcall(AnimatorUtils.stopAllDances, animator, loadedAnimations, 0.5)
				player.Character:SetAttribute("CurrentDanceID", nil)
				player.Character:SetAttribute("DanceStartTime", nil)
				player.Character:SetAttribute("Syncing", trueLeaderOfTarget.Name)

				-- FIX: Perlambat follower jika Leadernya saat ini sedang menari
				local leaderChar = trueLeaderOfTarget.Character
				if leaderChar and leaderChar:GetAttribute("CurrentDanceID") then
					setDanceWalkSpeed(player)
				else
					restoreOriginalWalkSpeed(player)
				end
			end

			syncNotificationRE:FireClient(player, "sync_success", trueLeaderOfTarget.Name)
			module.updateLeaderStatus(trueLeaderOfTarget)

			local playerName = player.Name
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:GetAttribute("Syncing") == playerName then
					otherPlayer.Character:SetAttribute("Syncing", trueLeaderOfTarget.Name)
				end
			end
		end
	else
		local trueLeader = currentSyncTarget and Players:FindFirstChild(currentSyncTarget)
		module.unsyncPlayer(player, loadedAnimations)
		syncNotificationRE:FireClient(player, "unsync_success")
		if trueLeader then module.updateLeaderStatus(trueLeader) end
	end
end

return module