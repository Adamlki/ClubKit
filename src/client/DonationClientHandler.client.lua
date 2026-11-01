--!optimize 2
--!native

if _G.__DonationClientHandlerLoaded then return end
_G.__DonationClientHandlerLoaded = true

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientConfig = require(script:FindFirstChild("ClientConfig") or script.Parent:WaitForChild("ClientConfig"))
local ClientUI = require(script:FindFirstChild("ClientUI") or script.Parent:WaitForChild("ClientUI"))
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("DonationBoard", 30)
if not gui then
	warn("[DonationClientHandler] DonationBoard tidak ditemukan di PlayerGui dalam 30 detik!")
	return
end

local mainFrame = gui:WaitForChild("MainFrame")
local leftPanel = mainFrame:WaitForChild("LeftPanel")
local rightPanel = mainFrame:WaitForChild("RightPanel")
local container = rightPanel:WaitForChild("Container")

local UI = {
	mainFrame = mainFrame,
	leftPanel = leftPanel,
	rightPanel = rightPanel,
	messageFrame = gui:WaitForChild("MessageFrame"),
	notificationFrame = gui:WaitForChild("NotificationFrame"),
	container = container,
	templateBtn = container:WaitForChild("RobuxBtn"),
	statsFrame = leftPanel:WaitForChild("StatsFrame"),
	closeBtn = mainFrame:WaitForChild("CloseBtn"),
}

local State = {
	productsLoaded = false,
	isLoading = false,
	isSending = false,
	currentButtons = {},
	productPrices = {},
	lastPurchasedAmount = 0,
	canSendMessage = false,
	lastMessageTime = 0,
}

local donationIcon

local function debugLog(...)
	if ClientConfig.DEBUG.ENABLED and ClientConfig.DEBUG.SHOW_EVENTS then
		print("[CLIENT]", ...)
	end
end

local function deselectDonationIcon()
	if donationIcon and donationIcon.isSelected then
		pcall(donationIcon.deselect, donationIcon)
	end
end

local function updatePlayerProfile()
	local avatarImg = UI.leftPanel:FindFirstChild("Avatar")
	if avatarImg then
		avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	end
	local nameLabel = UI.leftPanel:FindFirstChild("NameLabel")
	if nameLabel then nameLabel.Text = player.DisplayName end
	local userLabel = UI.leftPanel:FindFirstChild("UserLabel")
	if userLabel then userLabel.Text = "@" .. player.Name end
end

local function updatePlayerStats()
	local getStatsRemote = ReplicatedStorage:FindFirstChild("GetPlayerDonationStats")
	if getStatsRemote and getStatsRemote:IsA("RemoteFunction") then
		task.spawn(function()
			local ok, stats = pcall(getStatsRemote.InvokeServer, getStatsRemote)
			if ok and type(stats) == "table" then
				local robuxLbl = UI.statsFrame:FindFirstChild("TotalRobuxLabel")
				if robuxLbl then
					robuxLbl.Text = ClientUI.formatNumber(stats.robux or 0)
				end
			end
		end)
	end
end

local function openFrame(frame)
	frame.Visible = true
	if frame == UI.mainFrame then
		if _G.CloseSaweria then pcall(_G.CloseSaweria) end
		UI.container.CanvasPosition = Vector2.zero
		updatePlayerProfile()
		updatePlayerStats()
	elseif frame == UI.messageFrame then
		UI.mainFrame.Visible = false
		deselectDonationIcon()
	end
end

_G.CloseRobuxDonation = function()
	UI.mainFrame.Visible = false
	deselectDonationIcon()
end

local loadProducts

local function createProductButton(productData, index)
	State.productPrices[productData.Id] = productData.Price
	local card = UI.templateBtn:Clone()
	card.Name = string.format("Product_%02d_%d", index or 0, productData.Id)
	card.LayoutOrder = index or 0
	card.Visible = true
	card.Parent = UI.container

	local title = card:FindFirstChild("CardTitle")
	if title then
		title.Text = string.format("%s ROBUX", ClientUI.formatNumber(productData.Price))
	end

	local priceLabel = card:FindFirstChild("PriceLabel")
	if priceLabel then
		priceLabel.Text = tostring(productData.Price)
	end

	local buyBtn = card:FindFirstChild("BuyButton") or card:FindFirstChildWhichIsA("TextButton")
	if buyBtn then
		local isProcessing = false
		buyBtn.MouseButton1Click:Connect(function()
			if isProcessing then return end
			isProcessing = true

			local originalText = buyBtn.Text
			buyBtn.Text = "..."
			State.lastPurchasedAmount = productData.Price

			local ok, err = pcall(function()
				MarketplaceService:PromptProductPurchase(player, productData.Id)
			end)

			task.wait(0.5)
			buyBtn.Text = originalText
			isProcessing = false

			if not ok then
				debugLog("Purchase error:", err)
				ClientUI.notify("Error", ClientConfig.MESSAGES.PURCHASE_FAILED, 3)
			end
		end)
	end

	table.insert(State.currentButtons, card)
	return card
end

local function clearProducts()
	for _, btn in ipairs(State.currentButtons) do
		if btn and btn.Parent then btn:Destroy() end
	end
	table.clear(State.currentButtons)

	for _, child in ipairs(UI.container:GetChildren()) do
		if child:IsA("GuiObject") and child ~= UI.templateBtn and child.Name:match("^Product_") then
			child:Destroy()
		end
	end

	ClientUI.hideError(UI.container)
end

loadProducts = function()
	if State.isLoading then return end
	State.isLoading = true
	ClientUI.setLoading(UI.container, true)

	task.spawn(function()
		local getProducts = ReplicatedStorage:WaitForChild("GetDeveloperProducts", 10)
		if not getProducts then
			State.isLoading = false
			ClientUI.showError(UI.container, ClientConfig.MESSAGES.SERVER_UNAVAILABLE, loadProducts)
			return
		end

		local ok, products = pcall(getProducts.InvokeServer, getProducts)
		ClientUI.setLoading(UI.container, false)
		State.isLoading = false

		if not ok or not products then
			ClientUI.showError(UI.container, ClientConfig.MESSAGES.LOAD_FAILED, loadProducts)
			return
		end

		if #products == 0 then
			ClientUI.showError(UI.container, ClientConfig.MESSAGES.NO_PRODUCTS)
			return
		end

		clearProducts()
		for i, p in ipairs(products) do
			createProductButton(p, i)
		end
		State.productsLoaded = true
	end)
end

local function showMessageFrame(purchasedAmount)
	UI.mainFrame.Visible = false
	deselectDonationIcon()

	local amountLabel = UI.messageFrame:FindFirstChild("AmountLabel")
	if amountLabel then
		amountLabel.Text = string.format("Kamu baru saja mendonasikan %s Robux!", ClientUI.formatNumber(purchasedAmount))
	end

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	textbox.Text = ""

	State.canSendMessage = true
	State.isSending = false
	local sendBtn = UI.messageFrame:FindFirstChild("SendBtn")
	if sendBtn then sendBtn.Text = "KIRIM" end

	openFrame(UI.messageFrame)

	task.defer(function()
		if textbox and textbox:IsDescendantOf(game) then
			pcall(textbox.CaptureFocus, textbox)
		end
	end)
end

local function hideMessageFrame(cancelled)
	State.canSendMessage = false
	UI.messageFrame.Visible = false

	local textbox = UI.messageFrame:FindFirstChild("TextBox")
	if textbox then textbox.Text = "" end

	local sendBtn = UI.messageFrame:FindFirstChild("SendBtn")
	if sendBtn then sendBtn.Text = "KIRIM" end

	if cancelled and State.lastPurchasedAmount > 0 and not State.isSending then
		debugLog("Pesan broadcast dibatalkan oleh player, mengirim pesan default...")
		State.lastPurchasedAmount = 0
		task.spawn(function()
			local broadcastRemote = ReplicatedStorage:WaitForChild("BroadcastDonationMessage", 5)
			if broadcastRemote then
				local defaultMsg = ClientConfig.MESSAGE.DEFAULT_MESSAGE or "Welcome to RASA NADA"
				pcall(broadcastRemote.InvokeServer, broadcastRemote, defaultMsg)
			end
		end)
	end
end

local function sendMessage()
	if not State.canSendMessage or State.isSending then return end

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	local message = textbox.Text

	if #message < 1 then
		ClientUI.notify("Info", ClientConfig.MESSAGES.MESSAGE_TOO_SHORT, 3)
		return
	end

	if #message > ClientConfig.MESSAGE.MAX_LENGTH then
		ClientUI.notify("Info", ClientConfig.MESSAGES.MESSAGE_TOO_LONG, 3)
		return
	end

	State.canSendMessage = false
	State.isSending = true
	local sendBtn = UI.messageFrame:WaitForChild("SendBtn")
	sendBtn.Text = "MENGIRIM..."

	task.spawn(function()
		local broadcastRemote = ReplicatedStorage:WaitForChild("BroadcastDonationMessage", 5)
		if not broadcastRemote then
			State.isSending = false
			State.canSendMessage = true
			sendBtn.Text = "KIRIM"
			ClientUI.notify("Error", ClientConfig.MESSAGES.SERVER_UNAVAILABLE, 3)
			return
		end

		local ok, success, err = pcall(broadcastRemote.InvokeServer, broadcastRemote, message)
		State.isSending = false
		sendBtn.Text = "KIRIM"

		if ok and success then
			State.lastPurchasedAmount = 0
			ClientUI.notify("Sukses", ClientConfig.MESSAGES.MESSAGE_SENT, 3)
			hideMessageFrame(false)
		else
			State.canSendMessage = true
			ClientUI.notify("Info", err or "Gagal mengirim pesan.", 3)
		end
	end)
end

pcall(function()
	if Icon.getIcon and Icon.getIcon("DonationBoardIcon") then return end

	donationIcon = Icon.new()
		:setName("DonationBoardIcon")
		:setImage("rbxassetid://11560341824")
		:setLabel("")
		:setOrder(2)

	donationIcon.selected:Connect(function()
		openFrame(UI.mainFrame)
		if not State.productsLoaded then loadProducts() end
	end)

	donationIcon.deselected:Connect(function()
		UI.mainFrame.Visible = false
	end)
end)

local donationQueue = {}
local isDisplayingNotif = false

local function processDonationQueue()
	if _G.HideDonationNotif then
		table.clear(donationQueue)
		isDisplayingNotif = false
		if UI.notificationFrame then UI.notificationFrame.Visible = false end
		return
	end
	if isDisplayingNotif or #donationQueue == 0 then return end
	isDisplayingNotif = true

	local current = table.remove(donationQueue, 1)
	ClientUI.showNotification(
		UI.notificationFrame,
		current.displayName,
		current.amount,
		current.message,
		function()
			isDisplayingNotif = false
			processDonationQueue()
		end,
		current.userId,
		current.total
	)
end

local function setupBroadcastListener()
	local receiveRemote = ReplicatedStorage:WaitForChild("ReceiveDonationBroadcast", 10)
	if not receiveRemote then
		warn("[CLIENT] ReceiveDonationBroadcast RemoteEvent tidak ditemukan!")
		return
	end

	receiveRemote.OnClientEvent:Connect(function(displayName, amount, message, userId, totalAmount)
		debugLog("Broadcast diterima:", displayName, amount)
		if _G.HideDonationNotif then return end
		ClientUI.sendDonationChatMessage(displayName, amount)

		if amount >= ClientConfig.NOTIFICATION.MIN_DONATION then
			table.insert(donationQueue, {
				displayName = displayName,
				amount = amount,
				message = message,
				userId = userId,
				total = totalAmount or amount,
			})
			processDonationQueue()
		end
	end)
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if userId ~= player.UserId or not isPurchased then return end
	debugLog("Purchase selesai:", productId)
	updatePlayerStats()

	local purchasedAmount = (State.productPrices and State.productPrices[productId]) or State.lastPurchasedAmount
	State.lastPurchasedAmount = purchasedAmount

	UI.mainFrame.Visible = false
	deselectDonationIcon()

	if purchasedAmount >= ClientConfig.MESSAGE.MIN_DONATION then
		task.wait(0.3)
		showMessageFrame(purchasedAmount)
	end
end)

UI.mainFrame.Visible = false
UI.templateBtn.Visible = false
UI.messageFrame.Visible = false
UI.notificationFrame.Visible = false

local function bindDebouncedClick(btn, delay, callback)
	if not btn then return end
	local lastClick = 0
	btn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastClick < delay then return end
		lastClick = now
		callback()
	end)
end

bindDebouncedClick(UI.closeBtn, 0.3, function()
	deselectDonationIcon()
	UI.mainFrame.Visible = false
end)

local messageHeader = UI.messageFrame:FindFirstChild("Header")
if messageHeader and messageHeader:FindFirstChild("CloseBtn") then
	bindDebouncedClick(messageHeader.CloseBtn, 0.3, function() hideMessageFrame(true) end)
end

local cancelBtn = UI.messageFrame:FindFirstChild("CancelBtn")
bindDebouncedClick(cancelBtn, 0.3, function() hideMessageFrame(true) end)

local sendBtn = UI.messageFrame:FindFirstChild("SendBtn")
if sendBtn then
	sendBtn.MouseButton1Click:Connect(sendMessage)
end

local textbox = UI.messageFrame:FindFirstChild("TextBox")
if textbox then
	textbox.FocusLost:Connect(function(enterPressed)
		if enterPressed and State.canSendMessage then sendMessage() end
	end)
end

UI.container.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.container.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.container.CanvasPosition = Vector2.zero

local pad = UI.container:FindFirstChildOfClass("UIPadding")
if pad then
	pad.PaddingBottom = UDim.new(0, 15)
	pad.PaddingTop = UDim.new(0, 6)
end

ClientUI.initNotification(UI.notificationFrame)
setupBroadcastListener()
updatePlayerProfile()
updatePlayerStats()
task.spawn(loadProducts)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player and donationIcon then
		donationIcon:Destroy()
	end
end)

debugLog("DonationClientHandler (Photo 4 Match) Initialized successfully")
