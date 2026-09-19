local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local AvatarEditorService = game:GetService("AvatarEditorService")

local player = Players.LocalPlayer
local GROUP_ID = 192828493 

-- ====================================
-- NOTIFICATION HELPER
-- ====================================
local function showNotify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
end

-- ====================================
-- REMOTE CHECK GROUP VIP
-- ====================================
local function requestVIPRole()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		local checkRemote = remotes:WaitForChild("CheckGroupVIP", 5)
		if checkRemote and checkRemote:IsA("RemoteFunction") then
			local ok, success, msg = pcall(function()
				return checkRemote:InvokeServer()
			end)
			if ok and success then
				return true, msg
			end
		end
	end
	return false, nil
end

-- ====================================
-- PROMPT HANDLER FUNCTION
-- ====================================
local promptDebounce = false
local function handleJoinCommunityInteraction()
	if promptDebounce then return end
	promptDebounce = true

	local isInGroup = false
	pcall(function()
		isInGroup = player:IsInGroup(GROUP_ID)
	end)

	if isInGroup then
		requestVIPRole()
		showNotify("Komunitas VIP", "✨ Kamu sudah bergabung di komunitas! Status VIP kamu aktif.", 5)
		task.delay(2, function() promptDebounce = false end)
		return
	end

	-- Prompt Favorite
	task.spawn(function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)

	-- Prompt Join Group
	local success, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)

	if success then
		if result == Enum.GroupMembershipStatus.Joined then
			print("[JoinGroup] Player joined the group!")
			requestVIPRole()
			showNotify("🎉 VIP Gratis Aktif!", "Selamat! Kamu berhasil bergabung di komunitas dan mendapatkan VIP Gratis!", 7)
		elseif result == Enum.GroupMembershipStatus.AlreadyMember then
			print("[JoinGroup] Already a member")
			requestVIPRole()
			showNotify("Komunitas VIP", "Kamu sudah menjadi anggota komunitas! Status VIP kamu aktif.", 5)
		else
			print("[JoinGroup] Join request pending or declined")
			showNotify("Komunitas", "Permintaan bergabung ke grup dikirim / pending persetujuan.", 5)
		end
	else
		warn("[JoinGroup] Prompt failed:", result)
	end

	task.delay(2, function()
		promptDebounce = false
	end)
end

-- ====================================
-- HOOK IN-WORLD OBJECT (JOINKOMUN.joingrup)
-- ====================================
task.spawn(function()
	local joinkomun = workspace:WaitForChild("JOINKOMUN", 20)
	if joinkomun then
		local joingrup = joinkomun:WaitForChild("joingrup", 10)
		if joingrup then
			local prompt = joingrup:WaitForChild("Join Group", 10)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function(triggerPlayer)
					if triggerPlayer == player then
						handleJoinCommunityInteraction()
					end
				end)
				print("[JoinGroup] ✅ ProximityPrompt 'Join Group' connected successfully!")
			end

			local clickDetector = joingrup:FindFirstChildOfClass("ClickDetector")
			if clickDetector then
				clickDetector.MouseClick:Connect(function(clickPlayer)
					if clickPlayer == player then
						handleJoinCommunityInteraction()
					end
				end)
			end
		end
	end
end)

-- ====================================
-- AUTO-PROMPT AFTER 60 SECONDS (IF NOT IN GROUP)
-- ====================================
task.delay(60, function() 
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)
	if success and isInGroup then
		requestVIPRole()
		return 
	end

	task.delay(3, function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)

	local promptSuccess, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)

	if promptSuccess then
		if result == Enum.GroupMembershipStatus.Joined or result == Enum.GroupMembershipStatus.AlreadyMember then
			requestVIPRole()
			showNotify("🎉 VIP Gratis Aktif!", "Selamat! Kamu berhasil bergabung di komunitas dan mendapatkan VIP Gratis!", 7)
		end
	end
end)

-- ====================================
-- DUMMY LISTENER FOR UPDATELEADERSTATUS
-- ====================================
-- Dummy listener for UpdateLeaderStatus to prevent Remote Event Queue Exhausted error
local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
if remotes then
	local updateLeaderStatus = remotes:WaitForChild("UpdateLeaderStatus", 5)
	if updateLeaderStatus and updateLeaderStatus:IsA("RemoteEvent") then
		updateLeaderStatus.OnClientEvent:Connect(function()
			-- do nothing (dummy listener)
		end)
	end
end