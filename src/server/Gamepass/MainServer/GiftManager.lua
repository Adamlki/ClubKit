local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

local GiftManager = {}
local pendingGifts = {} -- Memori sementara: [GiverUserId] = {TargetId, GiftType, Timestamp}
local GIFT_INTENT_TTL = 15 * 60 -- detik; data gift yang lebih tua dari ini dianggap basi

local function findGiftTypeForProduct(productId)
	if not RoleSystem.Config.GiftProducts then return nil end
	for gType, prodId in pairs(RoleSystem.Config.GiftProducts) do
		if prodId == productId then
			return gType
		end
	end
	return nil
end

-- Target hanya valid jika konteksnya cocok dengan produk yang benar-benar dibeli
local function resolveGiftTarget(player, matchedGiftType)
	local giftData = pendingGifts[player.UserId]
	if giftData and giftData.GiftType == matchedGiftType
		and (os.time() - (giftData.Timestamp or 0)) <= GIFT_INTENT_TTL then
		return giftData.TargetId
	end

	local attrTarget = player:GetAttribute("PendingGiftTarget")
	local attrType = player:GetAttribute("PendingGiftType")
	local attrTime = player:GetAttribute("PendingGiftTime") or 0
	if attrTarget and attrType == matchedGiftType
		and (os.time() - attrTime) <= GIFT_INTENT_TTL then
		return attrTarget
	end

	return nil
end

local function clearGiftContext(player)
	pendingGifts[player.UserId] = nil
	player:SetAttribute("PendingGiftTarget", nil)
	player:SetAttribute("PendingGiftType", nil)
	player:SetAttribute("PendingGiftTime", nil)
end

function GiftManager:Init(ProcessReceiptHandler)
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local promptGiftEvent = remotesFolder:FindFirstChild("PromptGift") or Instance.new("RemoteEvent")
	promptGiftEvent.Name = "PromptGift"
	promptGiftEvent.Parent = remotesFolder

	promptGiftEvent.OnServerEvent:Connect(function(giver, targetPlayer, giftType)
		if not giver or not giver.Parent then return end
		if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end
		if not targetPlayer.Parent then return end
		if giver == targetPlayer then return end
		if not RoleSystem.Config.GiftProducts or not RoleSystem.Config.GiftProducts[giftType] then return end

		pendingGifts[giver.UserId] = {
			TargetId = targetPlayer.UserId,
			GiftType = giftType,
			Timestamp = os.time()
		}

		giver:SetAttribute("PendingGiftTarget", targetPlayer.UserId)
		giver:SetAttribute("PendingGiftType", giftType)
		giver:SetAttribute("PendingGiftTime", os.time())

		MarketplaceService:PromptProductPurchase(giver, RoleSystem.Config.GiftProducts[giftType])
	end)

	ProcessReceiptHandler:RegisterCallback("GiftSystem", function(player, productId, amount, receiptInfo)
		local matchedGiftType = findGiftTypeForProduct(productId)
		if not matchedGiftType then
			return nil -- bukan produk gift; biarkan ProcessReceiptHandler memutuskan
		end

		local targetId = resolveGiftTarget(player, matchedGiftType)

		if targetId then
			local success = RoleSystem:GivePassToPlayer(targetId, matchedGiftType, player.UserId)
			if success then
				clearGiftContext(player)
				return true
			end
			return false -- DataStore gagal — biarkan Roblox retry
		end

		-- Tidak ada target valid untuk produk ini: JANGAN berikan ke pembeli sendiri.
		-- Tahan receipt (NotProcessedYet) supaya produk gift tidak bisa dibeli tanpa target.
		warn(string.format(
			"[GiftManager] ⚠️ Gift receipt tanpa target valid | userId: %d | productId: %d | purchaseId: %s — receipt DITAHAN (NotProcessedYet).",
			player.UserId, productId, tostring(receiptInfo and receiptInfo.PurchaseId)))
		return false
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingGifts[player.UserId] = nil
	end)
end

return GiftManager
