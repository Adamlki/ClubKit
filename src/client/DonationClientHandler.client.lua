-- ============================================
-- SINGLETON PROTECTION (Mencegah script & icon berjalan ganda)
-- ============================================
if _G.__DonationClientHandlerLoaded then
	return
end
_G.__DonationClientHandlerLoaded = true

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")

local ClientConfig = require(script:FindFirstChild("ClientConfig") or script.Parent:WaitForChild("ClientConfig"))
local ClientUI     = require(script:FindFirstChild("ClientUI") or script.Parent:WaitForChild("ClientUI"))

-- TopbarPlus (pastikan tersedia di ReplicatedStorage)
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

-- ============================================
-- REFERENCES
-- ============================================
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui       = playerGui:WaitForChild("DonationBoard")

local UI = {
	mainFrame         = gui:WaitForChild("MainFrame"),
	leftPanel         = gui:WaitForChild("MainFrame"):WaitForChild("LeftPanel"),
	rightPanel        = gui:WaitForChild("MainFrame"):WaitForChild("RightPanel"),
	messageFrame      = gui:WaitForChild("MessageFrame"),
	notificationFrame = gui:WaitForChild("NotificationFrame"),
	container         = gui:WaitForChild("MainFrame"):WaitForChild("RightPanel"):WaitForChild("Container"),
	templateBtn       = gui:WaitForChild("MainFrame"):WaitForChild("RightPanel"):WaitForChild("Container"):WaitForChild("RobuxBtn"),
	saweriaFrame      = gui:WaitForChild("MainFrame"):WaitForChild("LeftPanel"):WaitForChild("SawriaFrame"),
	statsFrame        = gui:WaitForChild("MainFrame"):WaitForChild("LeftPanel"):WaitForChild("StatsFrame"),
	closeBtn          = gui:WaitForChild("MainFrame"):WaitForChild("CloseBtn"),
}

local saweriaTextBox = UI.saweriaFrame:WaitForChild("SaweriaTextBox")
local copyBtn        = UI.saweriaFrame:WaitForChild("CopyBtn")

-- ============================================
-- STATE
-- ============================================
local State = {
	productsLoaded       = false,
	isLoading            = false,
	isSending            = false,  
	currentButtons       = {},
	lastPurchasedAmount  = 0,
	canSendMessage       = false,
	lastMessageTime      = 0,
}

local function debugLog(...)
	if ClientConfig.DEBUG.ENABLED and ClientConfig.DEBUG.SHOW_EVENTS then
		print("[CLIENT]", ...)
	end
end

-- ============================================
-- PROFILE & STATS UPDATER
-- ============================================
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
			local ok, stats = pcall(function() return getStatsRemote:InvokeServer() end)
			if ok and type(stats) == "table" then
				local robuxLbl = UI.statsFrame:FindFirstChild("TotalRobuxLabel")
				if robuxLbl then
					robuxLbl.Text = ClientUI.formatNumber(stats.robux or 0)
				end
				local rupiahLbl = UI.statsFrame:FindFirstChild("TotalRupiahLabel")
				if rupiahLbl then
					local r = tostring(math.floor(tonumber(stats.rupiah) or 0))
					local k
					while true do  
						r, k = string.gsub(r, "^(-?%d+)(%d%d%d)", '%1.%2')
						if k == 0 then break end
					end
					rupiahLbl.Text = "Rp " .. r
				end
			end
		end)
	end
end

-- ============================================
-- POP-UP CONTROLLER
-- ============================================
local function openFrame(frame)
	frame.Visible = true
	if frame == UI.mainFrame then
		UI.container.CanvasPosition = Vector2.new(0, 0)
		updatePlayerProfile()
		updatePlayerStats()
	end
end

local function closeFrame(frame)
	frame.Visible = false
end

-- ============================================
-- PRODUCT UI
-- ============================================
local loadProducts
local createProductButton
local clearProducts

createProductButton = function(productData, index)
	local card = UI.templateBtn:Clone()
	card.Name        = string.format("Product_%02d_%d", index or 0, productData.Id)
	card.LayoutOrder = index or 0
	card.Visible     = true
	card.Parent      = UI.container

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

clearProducts = function()
	for _, btn in ipairs(State.currentButtons) do
		if btn and btn.Parent then btn:Destroy() end
	end
	State.currentButtons = {}

	-- Destroy any stray or duplicate product cards in container (except templateBtn)
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

		local ok, products = pcall(function()
			return getProducts:InvokeServer()
		end)

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

-- ============================================
-- MESSAGE FRAME LOGIC
-- ============================================
local function showMessageFrame(purchasedAmount)
	local amountLabel = UI.messageFrame:FindFirstChild("AmountLabel")
	if amountLabel then
		amountLabel.Text = string.format("Kamu baru saja mendonasikan %s Robux!", ClientUI.formatNumber(purchasedAmount))
	end

	local textbox = UI.messageFrame:WaitForChild("TextBox")
	textbox.Text = ""

	State.canSendMessage = true
	openFrame(UI.messageFrame)
end

local function hideMessageFrame(cancelled)
	State.canSendMessage = false
	closeFrame(UI.messageFrame)

	if cancelled then
		debugLog("Pesan broadcast dibatalkan oleh player")
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

	State.isSending = true
	local sendBtn = UI.messageFrame:WaitForChild("SendBtn")
	sendBtn.Text = "MENGIRIM..."

	task.spawn(function()
		local broadcastRemote = ReplicatedStorage:WaitForChild("BroadcastDonationMessage", 5)
		if not broadcastRemote then
			State.isSending = false
			sendBtn.Text = "KIRIM"
			ClientUI.notify("Error", ClientConfig.MESSAGES.SERVER_UNAVAILABLE, 3)
			return
		end

		local ok, success, err = pcall(function()
			return broadcastRemote:InvokeServer(message, State.lastPurchasedAmount)
		end)

		State.isSending = false
		sendBtn.Text = "KIRIM"

		if ok and success then
			ClientUI.notify("Sukses", ClientConfig.MESSAGES.MESSAGE_SENT, 3)
			hideMessageFrame(false)
		else
			local errMsg = err or "Gagal mengirim pesan."
			ClientUI.notify("Info", errMsg, 3)
		end
	end)
end

-- ============================================
-- TOPBAR PLUS ICON SETUP
-- ============================================
local donationIcon = nil

pcall(function()
	if Icon.getIcon and Icon.getIcon("DonationBoardIcon") then
		return
	end

	donationIcon = Icon.new()
		:setName("DonationBoardIcon")
		:setLabel("Donate")
		:setOrder(2)

	donationIcon.selected:Connect(function()
		openFrame(UI.mainFrame)
		if not State.productsLoaded then
			loadProducts()
		end
	end)

	donationIcon.deselected:Connect(function()
		closeFrame(UI.mainFrame)
	end)
end)

-- ============================================
-- NOTIFICATION QUEUE SYSTEM
-- ============================================
local donationQueue    = {}
local isDisplayingNotif = false

local function processDonationQueue()
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
		end
	)
end

local function setupBroadcastListener()
	local receiveRemote = ReplicatedStorage:WaitForChild("ReceiveDonationBroadcast", 10)
	if not receiveRemote then
		warn("[CLIENT] ReceiveDonationBroadcast RemoteEvent tidak ditemukan!")
		return
	end

	receiveRemote.OnClientEvent:Connect(function(displayName, amount, message)
		debugLog("Broadcast diterima:", displayName, amount)
		ClientUI.sendDonationChatMessage(displayName, amount)

		if amount >= ClientConfig.NOTIFICATION.MIN_DONATION then
			table.insert(donationQueue, {
				displayName = displayName,
				amount = amount,
				message = message
			})
			processDonationQueue()
		end
	end)
end

-- ============================================
-- PURCHASE HANDLER
-- ============================================
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if userId ~= player.UserId or not isPurchased then return end
	debugLog("Purchase selesai:", productId)
	updatePlayerStats()

	if State.lastPurchasedAmount >= ClientConfig.MESSAGE.MIN_DONATION then
		task.wait(0.5)
		showMessageFrame(State.lastPurchasedAmount)
	else
		if donationIcon then donationIcon:deselect() end
	end
end)

-- ============================================
-- UI SETUP & EVENT BINDINGS
-- ============================================
UI.mainFrame.Visible         = false
UI.templateBtn.Visible       = false
UI.messageFrame.Visible      = false
UI.notificationFrame.Visible = false

-- Saweria Setup
saweriaTextBox.Text             = "https://saweria.co/JeksAl"
saweriaTextBox.TextEditable     = false
saweriaTextBox.ClearTextOnFocus = false

copyBtn.MouseButton1Click:Connect(function()
	saweriaTextBox:CaptureFocus()
	saweriaTextBox.SelectionStart = 1
	saweriaTextBox.CursorPosition = #saweriaTextBox.Text + 1
	ClientUI.notify("Link Siap Disalin!", "Teks dipilih, tekan Ctrl+C untuk menyalin.", 3)
end)

-- Close Button MainFrame
UI.closeBtn.MouseButton1Click:Connect(function()
	if donationIcon then donationIcon:deselect() end
	UI.mainFrame.Visible = false
end)

-- Message Frame bindings
local messageHeader = UI.messageFrame:FindFirstChild("Header")
local sendBtn       = UI.messageFrame:FindFirstChild("SendBtn")
local cancelBtn     = UI.messageFrame:FindFirstChild("CancelBtn")
local textbox       = UI.messageFrame:FindFirstChild("TextBox")

if messageHeader and messageHeader:FindFirstChild("CloseBtn") then
	messageHeader.CloseBtn.MouseButton1Click:Connect(function()
		hideMessageFrame(true)
	end)
end
if cancelBtn then
	cancelBtn.MouseButton1Click:Connect(function()
		hideMessageFrame(true)
	end)
end
if sendBtn then
	sendBtn.MouseButton1Click:Connect(sendMessage)
end
if textbox then
	textbox.FocusLost:Connect(function(enterPressed)
		if enterPressed and State.canSendMessage then
			sendMessage()
		end
	end)
end

-- Auto-sync canvas size on container
UI.container.AutomaticCanvasSize = Enum.AutomaticSize.Y
UI.container.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.container.CanvasPosition = Vector2.new(0, 0)

local pad = UI.container:FindFirstChildOfClass("UIPadding")
if pad then
	pad.PaddingBottom = UDim.new(0, 15)
	pad.PaddingTop = UDim.new(0, 6)
end

-- Initialization
ClientUI.initNotification(UI.notificationFrame)
setupBroadcastListener()
updatePlayerProfile()
updatePlayerStats()
task.spawn(loadProducts)

Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if donationIcon then donationIcon:Destroy() end
	end
end)

debugLog("DonationClientHandler (Photo 4 Match) Initialized successfully")
