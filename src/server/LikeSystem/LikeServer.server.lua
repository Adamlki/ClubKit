local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local LikeManager = require(ServerStorage:WaitForChild("Modules"):WaitForChild("LikeManager"))

-- Create RemoteEvents if they don't exist
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

local LikePlayerRemote = RemotesFolder:FindFirstChild("LikePlayer")
if not LikePlayerRemote then
	LikePlayerRemote = Instance.new("RemoteFunction")
	LikePlayerRemote.Name = "LikePlayer"
	LikePlayerRemote.Parent = RemotesFolder
end

local LikeVisualEffectRemote = RemotesFolder:FindFirstChild("LikeVisualEffect")
if not LikeVisualEffectRemote then
	LikeVisualEffectRemote = Instance.new("RemoteEvent")
	LikeVisualEffectRemote.Name = "LikeVisualEffect"
	LikeVisualEffectRemote.Parent = RemotesFolder
end

local CheckLikeCooldownRemote = RemotesFolder:FindFirstChild("CheckLikeCooldown")
if not CheckLikeCooldownRemote then
	CheckLikeCooldownRemote = Instance.new("RemoteFunction")
	CheckLikeCooldownRemote.Name = "CheckLikeCooldown"
	CheckLikeCooldownRemote.Parent = RemotesFolder
end

-- Wait for UI to load if needed, but we use RemoteFunction for checking cooldown
CheckLikeCooldownRemote.OnServerInvoke = function(player, targetUserId)
	if type(targetUserId) ~= "number" then return {cooldownTime = 0, targetLikes = 0} end
	
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then return {cooldownTime = 0, targetLikes = 0} end
	
	local endTime = LikeManager.GetCooldownEndTime(player, targetPlayer)
	local totalLikes = targetPlayer:GetAttribute("TotalLikes") or 0
	
	return {
		cooldownTime = endTime,
		targetLikes = totalLikes
	}
end

LikePlayerRemote.OnServerInvoke = function(player, targetUserId)
	if type(targetUserId) ~= "number" then
		return false, "Invalid target."
	end
	
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	
	if not targetPlayer then
		return false, "Player not found or has left the game."
	end
	
	-- Process the like
	local success, messageOrTime = LikeManager.ProcessLike(player, targetPlayer)
	
	if success then
		-- Fire visual effect to all clients
		LikeVisualEffectRemote:FireAllClients(player, targetPlayer)
		
		-- Return success and the new cooldown end time
		return true, LikeManager.GetCooldownEndTime(player, targetPlayer)
	else
		-- Return false and error message / remaining time
		return false, messageOrTime
	end
end

-- ============================================
-- LEADERSTATS (TOTAL LIKES)
-- ============================================
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		-- Tunggu folder leaderstats yang dibuat oleh sistem lain
		local leaderstats = player:WaitForChild("leaderstats", 15)
		if not leaderstats then return end
		
		-- Buat stat Likes
		local likeStat = leaderstats:FindFirstChild("Likes")
		if not likeStat then
			likeStat = Instance.new("IntValue")
			likeStat.Name = "Likes"
			likeStat.Value = player:GetAttribute("TotalLikes") or 0
			likeStat.Parent = leaderstats
		end
		
		-- Terus perbarui jika attribute TotalLikes berubah
		player:GetAttributeChangedSignal("TotalLikes"):Connect(function()
			if likeStat then
				likeStat.Value = player:GetAttribute("TotalLikes") or 0
			end
		end)
	end)
end)
