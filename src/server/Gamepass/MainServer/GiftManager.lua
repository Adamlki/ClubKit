local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem = require(ServerStorage.Modules.RoleSystem)

local GiftManager = {}
local pendingGifts = {} -- Memori sementara: [GiverUserId] = {TargetId, GiftType}

function GiftManager:Init(ProcessReceiptHandler)
	-- 1. Buat RemoteEvent jika belum ada
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	local promptGiftEvent = remotesFolder:FindFirstChild("PromptGift") or Instance.new("RemoteEvent")
	promptGiftEvent.Name = "PromptGift"
	promptGiftEvent.Parent = remotesFolder

	-- 2. Dengar sinyal dari Menu Klik Player
	promptGiftEvent.OnServerEvent:Connect(function(giver, targetPlayer, giftType)
		if not targetPlayer or not RoleSystem.Config.GiftProducts[giftType] then return end

		pendingGifts[giver.UserId] = {
			TargetId = targetPlayer.UserId,
			GiftType = giftType
		}

		MarketplaceService:PromptProductPurchase(giver, RoleSystem.Config.GiftProducts[giftType])
	end)

	-- 3. DAFTARKAN CALLBACK KE SISTEM PEMBAYARAN
	ProcessReceiptHandler:RegisterCallback("GiftSystem", function(player, productId, amount, receiptInfo)
		local giverId = player.UserId
		local giftData = pendingGifts[giverId]

		if giftData then
			local isVIP = (productId == RoleSystem.Config.GiftProducts.VIP)
			local isVVIP = (productId == RoleSystem.Config.GiftProducts.VVIP)

			if isVIP or isVVIP then
				local targetId = giftData.TargetId
				local giftType = giftData.GiftType

				-- Berikan hadiah ke target via RoleSystem
				local success = RoleSystem:GivePassToPlayer(targetId, giftType, giverId)

				if success then
					pendingGifts[giverId] = nil -- Bersihkan catatan
					print("Gift Berhasil: " .. player.Name .. " membelikan " .. giftType)
					return true
				end
			end
		end
		return false
	end)
end

return GiftManager