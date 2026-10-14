-- ====================================
-- CLIENT SHOP HANDLER (SIMPLIFIED)
-- ====================================

local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local ShopHandler = {}
ShopHandler.GamepassData = {}
ShopHandler.shopDataLoaded = false
ShopHandler.isRefreshing = false

function ShopHandler:Init(remotes, uiManager, notificationManager)
	self.remotes = remotes
	self.uiManager = uiManager
	self.notificationManager = notificationManager
	Logger:Debug("ShopHandler initialized (Self-purchase only)")
end

function ShopHandler:SetGamepassData(data)
	self.GamepassData = data
end

function ShopHandler:LoadShopData()
	if self.isRefreshing then return end
	if self.shopDataLoaded then return end

	self.isRefreshing = true

	for _, data in pairs(self.GamepassData) do
		self.uiManager:SetButtonState(data.Button, "Loading")
	end

	local success, shopData = pcall(function()
		return self.remotes.shopRequest:InvokeServer({
			action = "GetShopData"
		})
	end)

	if success and shopData and shopData.success then
		for gamepassType, data in pairs(self.GamepassData) do
			if shopData.gamepasses[gamepassType] then
				local passData = shopData.gamepasses[gamepassType]
				data.IDs = passData.ids
				data.Owned = passData.owned
				data.Name = passData.name

				if passData.owned then
					self.uiManager:SetButtonState(data.Button, "Owned")
				else
					self.uiManager:SetButtonState(data.Button, "Buy")
				end
			else
				self.uiManager:SetButtonState(data.Button, "Error")
			end
		end

		self.shopDataLoaded = true
		Logger:Success("Shop data loaded successfully")
	else
		for _, data in pairs(self.GamepassData) do
			self.uiManager:SetButtonState(data.Button, "Error")
		end

		if shopData and shopData.error == "Too many requests" then
			self.notificationManager:Send(Config.Notifications.TooManyRequests)
		else
			self.notificationManager:Send(Config.Notifications.ErrorServer)
		end

		Logger:Error("Failed to load shop data: " .. tostring(shopData))
	end

	self.isRefreshing = false
end

function ShopHandler:PromptPurchase(gamepassType)
	local data = self.GamepassData[gamepassType]
	if not data then return end

	if data.Owned then
		self.notificationManager:Send(
			Config.Notifications.AlreadyOwned, 
			"Kamu sudah memiliki " .. data.Name .. "!"
		)
		return
	end

	local success, result = pcall(function()
		return self.remotes.shopRequest:InvokeServer({
			action = "PromptPurchase",
			gamepassType = gamepassType
		})
	end)

	if success and result then
		if not result.success then
			if result.error == "Already owned" then
				self.notificationManager:Send(Config.Notifications.AlreadyOwned)
				data.Owned = true
				self.uiManager:SetButtonState(data.Button, "Owned")
			elseif result.error == "Too many requests" then
				self.notificationManager:Send(Config.Notifications.TooManyRequests)
			else
				self.notificationManager:Send(Config.Notifications.ErrorPurchase)
			end
		end
	else
		self.notificationManager:Send(Config.Notifications.ErrorPurchase)
	end
end

function ShopHandler:RefreshPlayerRole()
	task.wait(Config.RoleRefreshDelay)
	pcall(function()
		self.remotes.refreshRole:FireServer()
	end)
end

function ShopHandler:HandleOwnershipUpdate(gamepassType, owned)
	Logger:Info(string.format("Ownership updated: %s = %s", gamepassType, tostring(owned)))

	local data = self.GamepassData[gamepassType]
	if data then
		data.Owned = owned
		if owned then
			self.uiManager:SetButtonState(data.Button, "Owned")

			self.notificationManager:ShowVisual(
				"Kamu telah menerima " .. data.Name .. "!",
				true
			)

			self.notificationManager:Send(
				Config.Notifications.PurchaseSuccess, 
				"Kamu telah menerima " .. data.Name .. "!"
			)

			self:RefreshPlayerRole()
		end
	end
end

return ShopHandler
