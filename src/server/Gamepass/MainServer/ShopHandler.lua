local Config = require(script.Parent.Config)
local Logger = require(script.Parent.Logger)

local MarketplaceService = game:GetService("MarketplaceService")

local ShopHandler = {}

function ShopHandler:Init(roleSystem, validationManager)
	self.roleSystem = roleSystem
	self.validationManager = validationManager
	Logger:Debug("ShopHandler initialized (Self-purchase only)")
end

function ShopHandler:GetShopData(player)
	if not self.validationManager:ValidatePlayer(player) then
		return {success = false, error = "Invalid player"}
	end

	local ownership = self.roleSystem:GetPlayerOwnership(player)

	local data = {
		success = true,
		gamepasses = {
			VVIP = {
				ids = self.roleSystem.Config.GamePasses.VVIP,
				owned = ownership.VVIP,
				name = "VVIP Pass",
				price = 79
			},
			VIP = {
				ids = self.roleSystem.Config.GamePasses.VIP,
				owned = ownership.VIP,
				name = "VIP Pass",
				price = 5
			}
		},
		debug = {
			givenPass = ownership.GivenPass,
			cachedAt = ownership.CheckedAt
		}
	}

	Logger:Debug(string.format("Shop data retrieved for %s (VVIP: %s, VIP: %s)", 
		player.Name, tostring(ownership.VVIP), tostring(ownership.VIP)))

	return data
end

function ShopHandler:PromptPurchase(player, gamepassType)
	if not self.validationManager:ValidatePlayer(player) then
		return {success = false, error = "Invalid player"}
	end

	if gamepassType ~= "VVIP" and gamepassType ~= "VIP" then
		return {success = false, error = "Invalid gamepass type"}
	end

	local ownership = self.roleSystem:GetPlayerOwnership(player)

	if ownership[gamepassType] then
		Logger:Debug(string.format("%s already owns %s", player.Name, gamepassType))
		return {success = false, error = "Already owned"}
	end

	local gamepassId = self.roleSystem.Config.ActiveGamepasses[gamepassType]

	if not gamepassId or gamepassId == 0 then
		Logger:Error("Invalid gamepass configuration for: " .. gamepassType)
		return {success = false, error = "Invalid gamepass configuration"}
	end

	Logger:Info(string.format("Prompting %s for %s (ID: %d)", 
		player.Name, gamepassType, gamepassId))

	local success, errorMsg = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end)

	if success then
		return {success = true, promptedId = gamepassId}
	else
		Logger:Error("Failed to prompt purchase: " .. tostring(errorMsg))
		return {success = false, error = "Failed to prompt purchase"}
	end
end

function ShopHandler:HandlePurchaseFinished(player, purchasedPassID, purchaseSuccess)
	if not self.validationManager:ValidatePlayer(player) then return end

	Logger:Info(string.format("Gamepass Purchase - Player: %s, ID: %d, Success: %s", 
		player.Name, purchasedPassID, tostring(purchaseSuccess)))

	if not purchaseSuccess then
		Logger:Debug("Purchase was not successful, skipping processing")
		return
	end

	-- Determine gamepass type
	local gamepassType = nil
	local vvipIds = self.roleSystem.Config.GamePasses.VVIP
	local vipIds = self.roleSystem.Config.GamePasses.VIP

	for _, id in ipairs(vvipIds) do
		if id == purchasedPassID then
			gamepassType = "VVIP"
			break
		end
	end

	if not gamepassType then
		for _, id in ipairs(vipIds) do
			if id == purchasedPassID then
				gamepassType = "VIP"
				break
			end
		end
	end

	if not gamepassType then
		Logger:Warn(string.format("Unknown gamepass purchased: %d", purchasedPassID))
		return
	end

	Logger:Success(string.format("%s purchased %s Pass!", player.Name, gamepassType))

	-- Use callback system untuk handle verification
	self.roleSystem:GivePassToPlayer(
		player.UserId,
		gamepassType,
		0, -- 0 = self purchase
		function(success, result)
			if success then
				Logger:Success(string.format("Successfully saved %s purchase for %s", 
					gamepassType, player.Name))

				-- Get role AFTER verification
				local newRole = self.roleSystem:GetPlayerRole(player)

				-- Notify client
				self:NotifyPurchaseComplete(player, gamepassType, newRole)

				-- Additional role update dengan proper delay
				if Config.AutoUpdateRole then
					task.spawn(function()
						task.wait(Config.UpdateDelay)

						local finalRole = self:UpdatePlayerRole(player)

						Logger:Success(string.format("Final role for %s: %s", 
							player.Name, finalRole))
					end)
				end

			else
				Logger:Error(string.format("Failed to save purchase: %s", result))
			end
		end
	)
end

function ShopHandler:UpdatePlayerRole(player)
	if not self.validationManager:ValidatePlayer(player) then 
		return nil
	end

	Logger:Debug(string.format("Updating role for player: %s", player.Name))

	task.wait(Config.UpdateDelay)

	-- Force cache refresh
	self.roleSystem:InvalidateOwnershipCache(player.UserId)

	-- Get updated role
	local newRole = self.roleSystem:UpdatePlayerRole(player)

	Logger:Info(string.format("Role updated for %s: %s", player.Name, newRole))

	-- Broadcast if enabled
	if Config.BroadcastRoleChange then
		self:NotifyRoleUpdate(player, newRole)
	end

	return newRole
end

-- Simple notification functions (no RemoteHandler needed)
function ShopHandler:NotifyPurchaseComplete(player, gamepassType, role)
	local remote = game.ReplicatedStorage.Gamepass:FindFirstChild("PlayerDataUpdated")
	if remote then
		remote:FireClient(player, {
			type = "purchase_complete",
			gamepassType = gamepassType,
			ownership = {
				[gamepassType] = true
			},
			role = role,
			message = string.format("Kamu telah menerima %s!", gamepassType)
		})
	end
end

function ShopHandler:NotifyRoleUpdate(player, newRole)
	local remote = game.ReplicatedStorage.Gamepass:FindFirstChild("PlayerDataUpdated")
	if remote then
		remote:FireClient(player, {
			type = "role_updated",
			role = newRole
		})
	end
end

return ShopHandler