local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local GROUP_ID = 192828493 

task.delay(60, function() 
	
	if player:IsInGroup(GROUP_ID) then return end

	task.delay(3, function()
		local AvatarEditorService = game:GetService("AvatarEditorService")
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)

	local success, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)

	if success then
		if result == Enum.GroupMembershipStatus.Joined then
			print("Player joined the group!")
		elseif result == Enum.GroupMembershipStatus.AlreadyMember then
			print("Already a member")
		else
			print("Join request pending or declined")
		end
	else
		warn("Prompt failed:", result)
	end
end)