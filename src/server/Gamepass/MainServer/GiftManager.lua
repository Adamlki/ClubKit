local Players = game:GetService("Players")
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
		local isGiftProduct = false
		local matchedGiftType = nil
		if RoleSystem.Config.GiftProducts then
			for gType, prodId in pairs(RoleSystem.Config.GiftProducts) do
				if prodId == productId then
					isGiftProduct = true
					matchedGiftType = gType
					break
				end
			end
		end

		-- Jika bukan produk Gift, return nil agar ProcessReceiptHandler tahu ini unknown productId
		if not isGiftProduct then
			return nil
		end

		local giverId = player.UserId
		local giftData = pendingGifts[giverId]

		local targetId = (giftData and giftData.TargetId) or player:GetAttribute("PendingGiftTarget")
		local giftType = (giftData and giftData.GiftType) or player:GetAttribute("PendingGiftType") or matchedGiftType or "VIP"

		if targetId then
			local success = RoleSystem:GivePassToPlayer(targetId, giftType, giverId)
			if success then
				pendingGifts[giverId] = nil
				player:SetAttribute("PendingGiftTarget", nil)
				player:SetAttribute("PendingGiftType", nil)
				return true
			end
			return false
		end

		-- Fallback jika targetId hilang (mis. pembeli disconnect sebelum memilih target): berikan ke pembeli sendiri agar Robux tidak hangus
		local fallbackSuccess = RoleSystem:GivePassToPlayer(giverId, giftType, giverId)
		if fallbackSuccess then
			pendingGifts[giverId] = nil
			return true
		end
		return false
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingGifts[player.UserId] = nil
	end)
end

return GiftManager