local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))

local CONFIG = {
	DEBUG_ENABLED = false,

	COLOR_PRESETS = {
		{ name = "White",       color = Color3.fromRGB(255, 255, 255) },
		{ name = "Black",       color = Color3.fromRGB(0, 0, 0) },
		{ name = "Crimson Red", color = Color3.fromRGB(220, 20, 60) },
		{ name = "Ruby",        color = Color3.fromRGB(224, 17, 95) },
		{ name = "Gold",        color = Color3.fromRGB(255, 215, 0) },
		{ name = "Neon Green",  color = Color3.fromRGB(57, 255, 20) },
		{ name = "Emerald",     color = Color3.fromRGB(80, 200, 120) },
		{ name = "Cyan",        color = Color3.fromRGB(0, 255, 255) },
		{ name = "Royal Blue",  color = Color3.fromRGB(65, 105, 225) },
		{ name = "Navy",        color = Color3.fromRGB(0, 0, 128) },
		{ name = "Purple",      color = Color3.fromRGB(128, 0, 128) },
		{ name = "Amethyst",    color = Color3.fromRGB(153, 102, 204) },
		{ name = "Hot Pink",    color = Color3.fromRGB(255, 105, 180) },
		{ name = "Orange",      color = Color3.fromRGB(255, 165, 0) },
		{ name = "Silver",      color = Color3.fromRGB(192, 192, 192) },
	},

	MAX_TITLE_LENGTH = 50,
	REFRESH_INTERVAL = 5,

	BTN_ACTIVE_COLOR   = Color3.fromRGB(46, 210, 115),
	BTN_INACTIVE_COLOR = Color3.fromRGB(24, 24, 24),

	ROLE_BTN_ACTIVE_COLOR   = Color3.fromRGB(27, 67, 46),
	ROLE_BTN_INACTIVE_COLOR = Color3.fromRGB(24, 24, 24),

	ADMIN_ICON_IMAGE     = AssetConfig.Images.AdminPanelIcon,
	ADMIN_ICON_LABEL     = "",
	ADMIN_ICON_ALIGNMENT = "left",
	ADMIN_ICON_SETORDER  = -1,

	UseStroke       = false,
	StrokeThickness = 1,
	StrokeColor     = Color3.fromRGB(255, 255, 255),

	UseGradient    = false,
	GradientSpeed  = 90,
	GradientColor0 = Color3.fromRGB(255, 255, 255),
	GradientColor1 = Color3.fromRGB(0,   0,   0),
	GradientColor2 = Color3.fromRGB(255, 255, 255),
}

local COLOR_FALLBACKS = {
	["Merah"] = "Bright red", ["Oranye"] = "Deep orange", ["Kuning"] = "New Yeller",
	["Hijau"] = "Dark green", ["Hijau Tua"] = "Earth green", ["Cyan"] = "Cyan",
	["Biru"] = "Bright blue", ["Biru Tua"] = "Navy blue", ["Ungu"] = "Royal purple",
	["Pink"] = "Hot pink", ["Putih"] = "White", ["Abu-abu"] = "Medium stone grey",
	["Hitam"] = "Really black", ["Emas"] = "Bright yellow", ["Perak"] = "Silver",
	["Coklat"] = "Brown"
}

local function debug(...) if CONFIG.DEBUG_ENABLED then print("[AdminPanel]", ...) end end
local function debugWarn(...) if CONFIG.DEBUG_ENABLED then warn("[AdminPanel]", ...) end end

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Teams             = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer

local function SafeInvoke(remote, timeout, ...)
	local args = {...}
	local finished = false
	local success = false
	local data = nil

	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(unpack(args))
		end)
		success = ok
		data = result
		finished = true
	end)

	local elapsed = 0
	while not finished and elapsed < timeout do
		elapsed += task.wait()
	end

	return finished and success, data
end

local gui               = script.Parent
local mainframe         = gui:WaitForChild("mainframe")
local notificationframe = gui:WaitForChild("NotificationFrame")
local notificationtext  = notificationframe:WaitForChild("NotificationText")
local headerframe       = mainframe:WaitForChild("HeaderFrame")
local closeBtn          = headerframe:WaitForChild("CloseBtn")

local playerlistframe   = mainframe:WaitForChild("PlayerlistFrame")
local playerimage       = playerlistframe:WaitForChild("playerimage")
local playername        = playerlistframe:WaitForChild("PlayerName")
local rolelabel         = playerlistframe:WaitForChild("Rolelabel")
local teamlabel         = playerlistframe:WaitForChild("Teamlabel")
local titlelabel        = playerlistframe:WaitForChild("Titlelabel")
local searchbox         = playerlistframe:WaitForChild("Searchbox")
local playerlist        = playerlistframe:WaitForChild("playerlist")
local playertemplateBtn = playerlist:WaitForChild("TemplatenameBtn")

local actionframe       = mainframe:WaitForChild("ActionFrame")
local actionheaderframe = actionframe:WaitForChild("ActionHeaderFrame")
local roleBtn           = actionheaderframe:WaitForChild("RoleBtn")
local titleBtn          = actionheaderframe:WaitForChild("TitleBtn")
local teamBtn           = actionheaderframe:WaitForChild("TeamBtn")
local donateBtn         = actionheaderframe:WaitForChild("DonateBtn", 5)

local roleframe          = actionframe:WaitForChild("RoleFrame")
local rolescrollingframe = roleframe:WaitForChild("RoleScrollingFrame")
local roletemplateBtn    = rolescrollingframe:WaitForChild("RoleTemplateBtn")
local roleBtnFrame       = roleframe:WaitForChild("RoleBtnFrame")
local roleconfirmBtn     = roleBtnFrame:WaitForChild("RoleConfirmBtn")
local rolecancelBtn      = roleBtnFrame:WaitForChild("RoleCancelBtn")

local titleframe             = actionframe:WaitForChild("TitleFrame")
-- Instance GUI lama masih bernama EffectFrame; isinya sekarang hanya preset warna.
local colorPresetFrame       = titleframe:WaitForChild("EffectFrame")
local colorPresetTemplateBtn = colorPresetFrame:WaitForChild("TitleEffectTemplate")
local colorpickframe         = titleframe:WaitForChild("ColorPickFrame")
local colorresult            = colorpickframe:WaitForChild("ColorResult")
local bluebox                = colorpickframe:WaitForChild("Blue")
local greenbox               = colorpickframe:WaitForChild("Green")
local redbox                 = colorpickframe:WaitForChild("Red")
local titleBtnFrame          = titleframe:WaitForChild("TitleBtnFrame")
local titlecancelBtn         = titleBtnFrame:WaitForChild("TitleCancelBtn")
local titleconfirmBtn        = titleBtnFrame:WaitForChild("TitleConfirmBtn")
local entrytitlebox          = titleframe:WaitForChild("EntryTitle")

local teamframe          = actionframe:WaitForChild("TeamFrame")
local teamcolorpickframe = teamframe:WaitForChild("ColorPickFrame")
local colortemplateBtn   = teamcolorpickframe:WaitForChild("ColorTemplateBtn")
local teamBtnFrame       = teamframe:WaitForChild("TeamBtnFrame")
local moveplayerBtn      = teamBtnFrame:WaitForChild("MovePlayerBtn")
local deleteteamBtn      = teamBtnFrame:WaitForChild("DeleteTeamBtn")
local teamlistframe      = teamframe:WaitForChild("teamlist")
local teamtemplateBtn    = teamlistframe:WaitForChild("TeamTemplateBtn")
local teamnamebox        = teamframe:WaitForChild("TeamName")
local teamcreateBtn      = teamframe:WaitForChild("TeamCreateBtn")

local donateframe        = actionframe:WaitForChild("DonateFrame", 5)
local donateCard         = donateframe and donateframe:WaitForChild("Card", 5)
local donateToggleBtn    = donateCard and donateCard:WaitForChild("ToggleBtn", 5)
local robuxRow           = donateCard and donateCard:WaitForChild("RobuxRow", 5)
local minRobuxBox        = robuxRow and robuxRow:WaitForChild("MinRobuxBox", 5)
local saweriaRow         = donateCard and donateCard:WaitForChild("SaweriaRow", 5)
local minSaweriaBox      = saweriaRow and saweriaRow:WaitForChild("MinSaweriaBox", 5)
local donateSaveBtn      = donateCard and donateCard:WaitForChild("SaveBtn", 5)

local titleRemotes        = ReplicatedStorage:WaitForChild("TitleRemotes")
local UpdateTitleRemote   = titleRemotes:WaitForChild("UpdateTitle")
local CheckAccessRemote   = titleRemotes:WaitForChild("CheckAccess")
local GetPlayerDataRemote = titleRemotes:WaitForChild("GetPlayerData")

local giveRoleRemote = ReplicatedStorage:WaitForChild("GiveRoleRemote", 30)

local adminPanelRemotes       = ReplicatedStorage:WaitForChild("AdminPanelRemotes")
local GetTeamListRemote       = adminPanelRemotes:WaitForChild("GetTeamList")
local GetColorTemplatesRemote = adminPanelRemotes:WaitForChild("GetColorTemplates")
local TeamActionRemote        = adminPanelRemotes:WaitForChild("TeamAction")
local TeamActionResultRemote  = adminPanelRemotes:WaitForChild("TeamActionResult")

local playerButtons   = {}
local selectedUserId  = nil
local selectedRole = nil
local roleButtonsPool = {}
local colorPresetBtnsPool = {}
local teamBtnsPool       = {}
local selectedTeamName   = nil
local selectedColorName  = nil
local colorBtnsPool      = {}

local hasAccess  = false
local playerRole = "Player"
local isRefreshing = false
local currentTab   = "Role"
local isSpotlightEnabled = false
local loadSpotlightSettings = nil
local loadTitleData

mainframe.Visible             = false
notificationframe.Visible     = false
playertemplateBtn.Visible     = false
roletemplateBtn.Visible       = false
teamtemplateBtn.Visible       = false
colorPresetTemplateBtn.Visible = false
colortemplateBtn.Visible      = false
if donateframe then donateframe.Visible = false end 

local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
local TopbarPanelRegistry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TopbarPanelRegistry"))

local gradientRotation    = 0
local registeredGradients = {}

if CONFIG.UseStroke and CONFIG.UseGradient then
	RunService.Heartbeat:Connect(function(dt)
		gradientRotation = (gradientRotation + CONFIG.GradientSpeed * dt) % 180
		for _, g in pairs(registeredGradients) do g.Rotation = gradientRotation end
	end)
end

local function getIconWidget(icon)
	for _, name in ipairs({"IconFrame","IconContainer","Widget","ClickRegion"}) do
		local inst = icon:getInstance(name)
		if inst then return inst end
	end
	return icon.widget
end

local function applyStroke(icon)
	if not CONFIG.UseStroke then return end
	local widget = getIconWidget(icon)
	if not widget then return end
	local stroke = Instance.new("UIStroke")
	stroke.Name            = "AdminStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness       = CONFIG.StrokeThickness
	stroke.Color           = CONFIG.StrokeColor
	stroke.Parent          = widget
	if CONFIG.UseGradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,   CONFIG.GradientColor0),
			ColorSequenceKeypoint.new(0.5, CONFIG.GradientColor1),
			ColorSequenceKeypoint.new(1,   CONFIG.GradientColor2),
		})
		gradient.Rotation = gradientRotation
		gradient.Parent   = stroke
		local uid = icon.UID
		registeredGradients[uid] = gradient
		icon:addToJanitor(function()
			registeredGradients[uid] = nil
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	else
		icon:addToJanitor(function()
			if stroke and stroke.Parent then stroke:Destroy() end
		end)
	end
end

local adminIcon = Icon.new()
adminIcon:setLabel(CONFIG.ADMIN_ICON_LABEL)
adminIcon:setOrder(CONFIG.ADMIN_ICON_SETORDER)
if CONFIG.ADMIN_ICON_IMAGE then adminIcon:setImage(CONFIG.ADMIN_ICON_IMAGE) end
if CONFIG.ADMIN_ICON_ALIGNMENT == "mid" then
	adminIcon:setMid()
elseif CONFIG.ADMIN_ICON_ALIGNMENT == "right" then
	adminIcon:setRight()
else
	adminIcon:setLeft()
end
applyStroke(adminIcon)
adminIcon:setEnabled(false)

local function showNotification(message, isSuccess)
	if not message or type(message) ~= "string" or message == "" then
		message = isSuccess and "Operasi berhasil" or "Operasi gagal"
	end
	notificationtext.Text       = message
	notificationtext.TextColor3 = isSuccess and Color3.fromRGB(85,255,127) or Color3.fromRGB(255,85,85)
	notificationframe.Visible   = true

	task.delay(3, function()
		if notificationframe.Visible then
			notificationframe.Visible = false
		end
	end)
end

local TAB_FRAMES = {
	Role   = roleframe,
	Title  = titleframe,
	Team   = teamframe,
	Donate = donateframe,
}

local TAB_BUTTONS = {
	Role  = roleBtn,
	Title = titleBtn,
	Team  = teamBtn,
}
if donateBtn then TAB_BUTTONS.Donate = donateBtn end

local function switchTab(tab)
	currentTab = tab

	for name, frame in pairs(TAB_FRAMES) do
		if frame then frame.Visible = (name == tab) end
	end

	if tab == "Donate" and loadSpotlightSettings then
		loadSpotlightSettings()
	end

	for name, btn in pairs(TAB_BUTTONS) do
		local stroke = btn:FindFirstChild("TabStroke") or btn:FindFirstChildOfClass("UIStroke")
		local isActive = (name == tab)
		btn.BackgroundColor3 = isActive and Color3.fromRGB(27, 67, 46) or Color3.fromRGB(16, 16, 16)
		btn.BackgroundTransparency = isActive and 0 or 1
		btn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 160)
		btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
		if stroke then
			stroke.Color = Color3.fromRGB(46, 210, 115)
			stroke.Transparency = isActive and 0 or 1
			stroke.Thickness = 1.2
		end
	end
end

local function updatePlayerInfoDisplay(userId)
	local target = Players:GetPlayerByUserId(userId)
	if not target then return end
	playername.Text = target.DisplayName

	local roleVal = target:FindFirstChild("Role")
	local roleName = roleVal and roleVal.Value or "Player"
	playername.TextColor3 = (roleName ~= "Player" and target.Team) and target.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)

	task.spawn(function()
		local ok, thumbUrl = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if selectedUserId == userId and ok and thumbUrl then 
			playerimage.Image = thumbUrl 
		end
	end)

	rolelabel.Text = "Role: " .. roleName
	teamlabel.Text = "Team: " .. (target.Team and target.Team.Name or "-")
	titlelabel.Text = "Title: Loading..."

	task.spawn(function()
		local ok2, data = SafeInvoke(GetPlayerDataRemote, 3, target)
		if selectedUserId ~= userId then return end
		titlelabel.Text = (ok2 and data) and "Title: " .. (data.Title ~= "" and data.Title or "-") or "Title: -"
	end)
end

local function refreshPlayerList()
	if isRefreshing then return end
	isRefreshing = true

	local filterText = searchbox.Text:lower()
	local yOffset    = 0
	local currentPlayersInServer = {}

	for _, plr in ipairs(Players:GetPlayers()) do
		currentPlayersInServer[plr.UserId] = true

		local existingBtn = playerButtons[plr.UserId]
		local isVisible = (filterText == "" or plr.DisplayName:lower():find(filterText, 1, true))

		local roleVal = plr:FindFirstChild("Role")
		local roleName = roleVal and roleVal.Value or "Player"
		local nameColor = (roleName ~= "Player" and plr.Team) and plr.Team.TeamColor.Color or Color3.fromRGB(255, 255, 255)
		local displayText = (plr == LocalPlayer) and (plr.DisplayName .. " (Saya)") or plr.DisplayName

		if existingBtn then
			if isVisible then
				existingBtn.Position = UDim2.new(0, 0, 0, yOffset)
				existingBtn.Visible  = true
				existingBtn.Text     = displayText
				existingBtn.TextColor3 = nameColor 
				yOffset += existingBtn.Size.Y.Offset + 5
			else
				existingBtn.Visible = false
			end
		elseif isVisible then
			local newBtn    = playertemplateBtn:Clone()
			newBtn.Name     = "Player_" .. plr.UserId
			newBtn.Text     = displayText
			newBtn.Position = UDim2.new(0, 0, 0, yOffset)
			newBtn.Visible  = true
			newBtn.TextColor3 = nameColor 
			newBtn.Parent   = playerlist

			newBtn.MouseButton1Click:Connect(function()
				selectedUserId = plr.UserId
				updatePlayerInfoDisplay(plr.UserId)
				loadTitleData(plr.UserId)
			end)

			playerButtons[plr.UserId] = newBtn
			yOffset += newBtn.Size.Y.Offset + 5
		end
	end

	for userId, btn in pairs(playerButtons) do
		if not currentPlayersInServer[userId] then
			if btn and btn.Parent then btn:Destroy() end
			playerButtons[userId] = nil
		end
	end

	playerlist.CanvasSize = UDim2.new(0, 0, 0, yOffset)
	isRefreshing = false
end

local ROLE_TYPES = { "VIP", "Moderator", "Admin", "Player" }
local ROLE_PERMS = {
	Owner     = { VIP = true, Moderator = true, Admin = true, Player = true },
	Admin     = { VIP = true, Moderator = true, Player = true },
	Moderator = { VIP = true, Player = true },
}

local function getOrCreateRoleButton(roleName)
	if not roleButtonsPool[roleName] then
		local newBtn = roletemplateBtn:Clone()
		newBtn.Name = "RoleBtn_" .. roleName
		newBtn.Parent = rolescrollingframe

		newBtn.MouseButton1Click:Connect(function()
			selectedRole = roleName
			for _, rb in pairs(roleButtonsPool) do rb.BackgroundColor3 = CONFIG.ROLE_BTN_INACTIVE_COLOR end
			newBtn.BackgroundColor3 = CONFIG.ROLE_BTN_ACTIVE_COLOR
		end)

		roleButtonsPool[roleName] = newBtn
	end
	return roleButtonsPool[roleName]
end

local function buildRoleButtons()
	for _, btn in pairs(roleButtonsPool) do btn.Visible = false end

	local myRole = (LocalPlayer:FindFirstChild("Role") and LocalPlayer.Role.Value) or "Player"
	local perms = ROLE_PERMS[myRole]
	local yOffset = 0

	for _, roleName in ipairs(ROLE_TYPES) do
		if perms and perms[roleName] then
			local btn = getOrCreateRoleButton(roleName)
			btn.Text = roleName
			btn.Position = UDim2.new(0, 0, 0, yOffset)
			btn.Visible = true
			btn.BackgroundColor3 = (selectedRole == roleName) and CONFIG.ROLE_BTN_ACTIVE_COLOR or CONFIG.ROLE_BTN_INACTIVE_COLOR
			yOffset += btn.Size.Y.Offset + 5
		end
	end
	rolescrollingframe.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

local function resetRoleForm()
	selectedRole = nil
	for _, btn in pairs(roleButtonsPool) do btn.BackgroundColor3 = CONFIG.ROLE_BTN_INACTIVE_COLOR end
end

roleconfirmBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	if not selectedRole   then showNotification("Pilih role terlebih dahulu!", false);   return end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end
	showNotification("Memproses...", true)
	giveRoleRemote:FireServer({
		source = "AdminPanel", action = "GiveRole",
		targetUserId = targetPlayer.UserId, roleType = selectedRole,
	})
	resetRoleForm()
end)

rolecancelBtn.MouseButton1Click:Connect(function()
	resetRoleForm()
	showNotification("Dibatalkan", false)
end)

local function validateRGB(value)
	local num = tonumber(value)
	return (num and num >= 0 and num <= 255) and math.floor(num) or 0
end

local function updateColorPreview()
	colorresult.BackgroundColor3 = Color3.fromRGB(
		validateRGB(redbox.Text), validateRGB(greenbox.Text), validateRGB(bluebox.Text))
end

local function buildColorPresetButtons()
	for _, btn in pairs(colorPresetBtnsPool) do btn.Visible = false end

	for i, preset in ipairs(CONFIG.COLOR_PRESETS) do
		local btn = colorPresetBtnsPool[i]
		if not btn then
			btn = colorPresetTemplateBtn:Clone()
			btn.Name = "Preset_" .. i
			btn.Parent = colorPresetFrame

			btn.MouseButton1Click:Connect(function()
				redbox.Text   = tostring(math.floor(preset.color.R * 255))
				greenbox.Text = tostring(math.floor(preset.color.G * 255))
				bluebox.Text  = tostring(math.floor(preset.color.B * 255))
				updateColorPreview()
			end)
			colorPresetBtnsPool[i] = btn
		end

		btn.Text = preset.name
		btn.LayoutOrder = i
		btn.Visible = true
		btn.BackgroundColor3 = preset.color
		local brightness = (preset.color.R + preset.color.G + preset.color.B)
		btn.TextColor3 = brightness < 1.5 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	end
end

loadTitleData = function(userId)
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then return end

	titleconfirmBtn.Text = "Memuat..."
	task.spawn(function()
		local ok, data = SafeInvoke(GetPlayerDataRemote, 3, targetPlayer)
		if selectedUserId ~= userId then return end

		titleconfirmBtn.Text = "✓ Simpan Title"
		if not ok or not data then return end

		entrytitlebox.Text = data.Title or ""
		local color = data.Color or { R=255, G=255, B=255 }
		redbox.Text   = tostring(color.R)
		greenbox.Text = tostring(color.G)
		bluebox.Text  = tostring(color.B)
		updateColorPreview()
	end)
end

local function resetTitleForm()
	entrytitlebox.Text = ""
	redbox.Text        = "255"
	greenbox.Text      = "255"
	bluebox.Text       = "255"
	updateColorPreview()
end

redbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
greenbox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)
bluebox:GetPropertyChangedSignal("Text"):Connect(updateColorPreview)

local isProcessingTitle = false

titleconfirmBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then showNotification("Pilih player terlebih dahulu!", false); return end
	if isProcessingTitle then return end 

	local titleText = entrytitlebox.Text:match("^%s*(.-)%s*$")
	if titleText ~= "" then
		local len = utf8.len(titleText)
		if len and len > CONFIG.MAX_TITLE_LENGTH then
			showNotification("Title terlalu panjang! Maksimal "..CONFIG.MAX_TITLE_LENGTH.." karakter", false)
			return
		end
	end

	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end

	isProcessingTitle = true
	local previousRevision = targetPlayer:GetAttribute("TitleRevision") or 0
	UpdateTitleRemote:FireServer(targetPlayer, {
		Title = titleText,
		Color = Color3.fromRGB(validateRGB(redbox.Text), validateRGB(greenbox.Text), validateRGB(bluebox.Text)),
	})

	titleconfirmBtn.Text = "Menyimpan..."
	task.spawn(function()
		local deadline = os.clock() + 2
		local updated = false
		while os.clock() < deadline do
			if (targetPlayer:GetAttribute("TitleRevision") or 0) ~= previousRevision then
				updated = true
				break
			end
			task.wait(0.1)
		end

		titleconfirmBtn.Text = "✓ Simpan Title"
		isProcessingTitle = false

		if updated then
			-- Tampilkan judul yang benar-benar lolos filter server, bukan teks mentah client.
			local appliedTitle = targetPlayer:GetAttribute("Overhead_TitleText") or titleText
			showNotification("Title berhasil diupdate!", true)
			titlelabel.Text = "Title: " .. ((appliedTitle ~= "" and appliedTitle) or "-")
		else
			showNotification("Gagal menyimpan title. Cek akses/filter lalu coba lagi.", false)
		end
	end)
end)

titlecancelBtn.MouseButton1Click:Connect(resetTitleForm)

local function updateColorTemplateBtnStates()
	for _, btn in pairs(colorBtnsPool) do
		if btn.Visible and btn:GetAttribute("ColorName") == selectedColorName then
			btn.BorderSizePixel  = 3
			btn.BorderColor3     = Color3.fromRGB(255, 255, 255)
		else
			btn.BorderSizePixel  = 0
		end
	end
end

local function buildColorTemplates(templates)
	for _, btn in pairs(colorBtnsPool) do btn.Visible = false end
	selectedColorName = nil

	for i, tmpl in ipairs(templates) do
		local newBtn = colorBtnsPool[i]
		if not newBtn then
			newBtn = colortemplateBtn:Clone()
			newBtn.Parent = teamcolorpickframe
			newBtn.MouseButton1Click:Connect(function()
				selectedColorName = newBtn:GetAttribute("ColorName")
				updateColorTemplateBtnStates()
			end)
			colorBtnsPool[i] = newBtn
		end

		newBtn.Name = "ColorBtn_" .. tmpl.name
		newBtn:SetAttribute("ColorName", tmpl.name)

		local finalColorName = tmpl.brickColorName or COLOR_FALLBACKS[tmpl.name]
		if finalColorName then
			newBtn.BackgroundColor3 = BrickColor.new(finalColorName).Color
		elseif tmpl.r then
			newBtn.BackgroundColor3 = Color3.fromRGB(tmpl.r, tmpl.g, tmpl.b)
		else
			newBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end
		newBtn.Visible = true
	end

	if #templates > 0 then
		selectedColorName = templates[1].name
		updateColorTemplateBtnStates()
	end
end

local colorTemplatesLoaded = false
local function loadColorTemplates()
	if colorTemplatesLoaded then return end
	colorTemplatesLoaded = true
	task.spawn(function()
		local ok, templates = SafeInvoke(GetColorTemplatesRemote, 3)
		if ok and type(templates) == "table" and #templates > 0 then
			buildColorTemplates(templates)
		else
			colorTemplatesLoaded = false 
			debugWarn("Failed to load color templates")
		end
	end)
end

local function buildTeamList()
	task.spawn(function()
		local ok, teamList = SafeInvoke(GetTeamListRemote, 3)
		if not ok or type(teamList) ~= "table" then return end

		for _, btn in pairs(teamBtnsPool) do btn.Visible = false end
		selectedTeamName = nil

		local yOffset = 0
		for i, teamData in ipairs(teamList) do
			local newBtn = teamBtnsPool[i]
			if not newBtn then
				newBtn = teamtemplateBtn:Clone()
				newBtn.Parent = teamlistframe
				newBtn.MouseButton1Click:Connect(function()
					selectedTeamName = newBtn:GetAttribute("TeamName")
					for _, tb in pairs(teamBtnsPool) do tb.BorderSizePixel = 0 end
					newBtn.BorderSizePixel = 2
				end)
				teamBtnsPool[i] = newBtn
			end

			newBtn.Name = "TeamBtn_" .. teamData.name
			newBtn:SetAttribute("TeamName", teamData.name)
			newBtn.Text = teamData.isCustom and ("[Custom] " .. teamData.name) or teamData.name
			newBtn.Position = UDim2.new(0, 0, 0, yOffset)
			newBtn.BorderSizePixel = 0

			local realTeamObj = Teams:FindFirstChild(teamData.name)
			if realTeamObj then
				newBtn.BackgroundColor3 = realTeamObj.TeamColor.Color
			else
				local fallbackStr = teamData.brickColorName or COLOR_FALLBACKS[teamData.name]
				newBtn.BackgroundColor3 = fallbackStr and BrickColor.new(fallbackStr).Color or Color3.fromRGB(teamData.r or 200, teamData.g or 200, teamData.b or 200)
			end

			newBtn.Visible = true
			yOffset += newBtn.Size.Y.Offset + 5
		end
		teamlistframe.CanvasSize = UDim2.new(0, 0, 0, yOffset)
	end)
end

moveplayerBtn.MouseButton1Click:Connect(function()
	if not selectedUserId   then showNotification("Pilih player terlebih dahulu!", false); return end
	if not selectedTeamName then showNotification("Pilih team terlebih dahulu!", false);   return end
	local targetPlayer = Players:GetPlayerByUserId(selectedUserId)
	if not targetPlayer then showNotification("Player tidak ditemukan!", false); return end
	TeamActionRemote:FireServer({ action="MovePlayer", targetUserId=selectedUserId, teamName=selectedTeamName })
	showNotification("Memindahkan "..targetPlayer.DisplayName.." ke "..selectedTeamName.."...", true)
end)

deleteteamBtn.MouseButton1Click:Connect(function()
	if not selectedTeamName then showNotification("Pilih team yang akan dihapus!", false); return end
	TeamActionRemote:FireServer({ action="DeleteTeam", teamName=selectedTeamName })
	showNotification("Menghapus team "..selectedTeamName.."...", true)
end)

teamcreateBtn.MouseButton1Click:Connect(function()
	local newTeamName = teamnamebox.Text:match("^%s*(.-)%s*$")
	if newTeamName == "" then showNotification("Masukkan nama team!", false); return end
	if not selectedColorName then showNotification("Pilih warna team terlebih dahulu!", false); return end

	TeamActionRemote:FireServer({
		action    = "CreateTeam",
		teamName  = newTeamName,
		colorName = selectedColorName, 
	})

	showNotification("Membuat team "..newTeamName.." ("..selectedColorName..")...", true)
	teamnamebox.Text = ""
	debug("CreateTeam:", newTeamName, "warna:", selectedColorName)
end)

TeamActionResultRemote.OnClientEvent:Connect(function(data)
	if not data then return end
	showNotification(data.message or "Operasi selesai", data.success or false)
	if data.success then
		task.delay(0.3, buildTeamList)
		if selectedUserId then
			local tp = Players:GetPlayerByUserId(selectedUserId)
			if tp then
				task.delay(0.5, function()
					teamlabel.Text = "Team: " .. (tp.Team and tp.Team.Name or "-")
				end)
			end
		end
	end
end)

local function checkAccess()
	local roleVal = LocalPlayer:FindFirstChild("Role")
	playerRole = roleVal and roleVal.Value or "Player"
	local adminRoles = { Owner=true, Admin=true, Moderator=true }
	if adminRoles[playerRole] then
		hasAccess = true
		adminIcon:setEnabled(true)
		buildRoleButtons()
		buildColorPresetButtons()
	else
		hasAccess = false
		adminIcon:setEnabled(false)
		if mainframe.Visible then
			adminIcon:deselect()
		end
	end
end

local function openPanel()
	if not hasAccess then return end
	mainframe.Visible = true
	refreshPlayerList()
	buildTeamList()
	loadColorTemplates() 
	switchTab("Role")
	playerimage.Image = ""
	playername.Text   = "Pilih Player"
	rolelabel.Text    = "Role: -"
	teamlabel.Text    = "Team: -"
	titlelabel.Text   = "Title: -"
	selectedUserId    = nil
end

TopbarPanelRegistry:Register("Admin", function()
	if adminIcon then adminIcon:deselect() end
end)

adminIcon:bindEvent("selected", function()
	if not hasAccess then adminIcon:deselect(); return end
	TopbarPanelRegistry:CloseOthers("Admin")
	openPanel()
end)

adminIcon:bindEvent("deselected", function()
	mainframe.Visible = false
	selectedUserId    = nil
	resetTitleForm()
	resetRoleForm()
end)

closeBtn.MouseButton1Click:Connect(function() 
	adminIcon:deselect() 
end)

roleBtn.MouseButton1Click:Connect(function()  switchTab("Role")  end)
titleBtn.MouseButton1Click:Connect(function() switchTab("Title") end)
teamBtn.MouseButton1Click:Connect(function()
	switchTab("Team")
	buildTeamList()
	loadColorTemplates()
end)
if donateBtn then
	donateBtn.MouseButton1Click:Connect(function() switchTab("Donate") end)
end

local function updateSpotlightToggleUI(enabled)
	isSpotlightEnabled = (enabled == true)
	if donateToggleBtn then
		donateToggleBtn.Text = isSpotlightEnabled and "STATUS: AKTIF" or "STATUS: NONAKTIF"
		donateToggleBtn.BackgroundColor3 = isSpotlightEnabled and Color3.fromRGB(30, 130, 60) or Color3.fromRGB(130, 30, 30)
	end
end

loadSpotlightSettings = function()
	local spotFolder = ReplicatedStorage:FindFirstChild("DonationSpotlightSettings")
	if spotFolder then
		updateSpotlightToggleUI(spotFolder:GetAttribute("Enabled") == true)
		if minRobuxBox then minRobuxBox.Text = tostring(spotFolder:GetAttribute("MinRobux") or 500) end
		if minSaweriaBox then minSaweriaBox.Text = tostring(spotFolder:GetAttribute("MinSaweria") or 50000) end
	else
		updateSpotlightToggleUI(false)
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("AdminPanelRemotes")
		local getRemote = remotes and remotes:FindFirstChild("GetSpotlightSettings")
		if getRemote then
			local ok, res = pcall(function() return getRemote:InvokeServer() end)
			if ok and res and type(res) == "table" then
				updateSpotlightToggleUI(res.Enabled == true)
				if minRobuxBox then minRobuxBox.Text = tostring(res.MinRobux or 500) end
				if minSaweriaBox then minSaweriaBox.Text = tostring(res.MinSaweria or 50000) end
			end
		end
	end)
end

if donateToggleBtn then
	donateToggleBtn.MouseButton1Click:Connect(function()
		updateSpotlightToggleUI(not isSpotlightEnabled)
	end)
end

if donateSaveBtn then
	donateSaveBtn.MouseButton1Click:Connect(function()
		local remotes = ReplicatedStorage:FindFirstChild("AdminPanelRemotes")
		local updateRemote = remotes and remotes:FindFirstChild("UpdateSpotlightSettings")
		if not updateRemote then
			showNotification("Remote UpdateSpotlightSettings tidak ditemukan!", false)
			return
		end

		local rVal = tonumber(minRobuxBox and minRobuxBox.Text) or 500
		local sVal = tonumber(minSaweriaBox and minSaweriaBox.Text) or 50000

		local ok, res = pcall(function()
			return updateRemote:InvokeServer({
				Enabled = isSpotlightEnabled,
				MinRobux = rVal,
				MinSaweria = sVal,
			})
		end)

		if ok and res and res.success then
			showNotification(res.message or "Pengaturan tersimpan!", true)
		else
			showNotification((res and res.message) or "Gagal menyimpan pengaturan!", false)
		end
	end)
end

local searchDebounce = nil
searchbox:GetPropertyChangedSignal("Text"):Connect(function()
	if searchDebounce then task.cancel(searchDebounce) end
	searchDebounce = task.delay(0.3, function()
		if not isRefreshing then refreshPlayerList() end
	end)
end)

if giveRoleRemote then
	giveRoleRemote.OnClientEvent:Connect(function(responseData)
		if not responseData or responseData.source ~= "AdminPanel" then return end
		if responseData.success then
			showNotification(responseData.message or "Role berhasil diberikan", true)
			if selectedUserId then
				local tp = Players:GetPlayerByUserId(selectedUserId)
				if tp then
					local rv = tp:FindFirstChild("Role")
					rolelabel.Text = rv and ("Role: " .. rv.Value) or "Role: -"
				end
			end
			task.wait(1.5)
			adminIcon:deselect()
		else
			showNotification(responseData.message or "Operasi gagal", false)
		end
	end)
else
	debugWarn("GiveRoleRemote not found!")
end

Players.PlayerAdded:Connect(function()
	if mainframe.Visible then 
		task.wait(0.5) 
		refreshPlayerList() 
	end
end)

Players.PlayerRemoving:Connect(function(removingPlayer)
	if mainframe.Visible then refreshPlayerList() end
	if selectedUserId == removingPlayer.UserId then
		selectedUserId    = nil
		playerimage.Image = ""
		playername.Text   = "Pilih Player"
		rolelabel.Text    = "Role: -"
		teamlabel.Text    = "Team: -"
		titlelabel.Text   = "Title: -"
	end
end)

local function watchRoleValue()
	local roleVal = LocalPlayer:WaitForChild("Role", 10)
	if roleVal then
		checkAccess()
		roleVal:GetPropertyChangedSignal("Value"):Connect(checkAccess)
	end
end

updateColorPreview()
switchTab("Role")
task.wait(2)
task.spawn(watchRoleValue)

debug("Admin Panel Client initialized")
