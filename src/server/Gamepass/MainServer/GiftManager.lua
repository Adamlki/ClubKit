local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

local GiftManager = {}
local pendingGifts = {} -- Memori sementara: [GiverUserId] = {TargetId, GiftType}

function GiftManager:Init(ProcessReceiptHandler)
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local promptGiftEvent = remotesFolder:FindFirstChild("PromptGift") or Instance.new("RemoteEvent")
	promptGiftEvent.Name = "PromptGift"
	promptGiftEvent.Parent = remotesFolder

	promptGiftEvent.OnServerEvent:Connect(function(giver, targetPlayer, giftType)
		if not giver or not targetPlayer or not targetPlayer.Parent then return end
		if giver == targetPlayer then return end
		if not RoleSystem.Config.GiftProducts or not RoleSystem.Config.GiftProducts[giftType] then return end

		pendingGifts[giver.UserId] = {
			TargetId = targetPlayer.UserId,
			GiftType = giftType,
			Timestamp = os.time()
		}

		giver:SetAttribute("PendingGiftTarget", targetPlayer.UserId)
		giver:SetAttribute("PendingGiftType", giftType)

		MarketplaceService:PromptProductPurchase(giver, RoleSystem.Config.GiftProducts[giftType])
	end)

	ProcessReceiptHandler:RegisterCallback("GiftSystem", function(player, productId, amount, receiptInfo)
		local giverId = player.UserId
		local giftData = pendingGifts[giverId]

		local targetId = giftData and giftData.TargetId or player:GetAttribute("PendingGiftTarget")
		local giftType = giftData and giftData.GiftType or player:GetAttribute("PendingGiftType") or "VIP"

		if targetId and RoleSystem.Config.GiftProducts[giftType] == productId then
			local success = RoleSystem:GivePassToPlayer(targetId, giftType, giverId)
			if success then
				pendingGifts[giverId] = nil
				player:SetAttribute("PendingGiftTarget", nil)
				player:SetAttribute("PendingGiftType", nil)
				return true
			end
		end
		return false
	end)
end

return GiftManager