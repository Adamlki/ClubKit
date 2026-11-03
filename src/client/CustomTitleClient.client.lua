local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local ClientState       = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClientState"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui     = playerGui:WaitForChild("CustomTitleGui", 30)
if not screenGui then return end
local mainFrame     = screenGui:WaitForChild("MainFrame", 10)
if not mainFrame then return end

local header        = mainFrame:WaitForChild("Header")
local closeBtn      = header:WaitForChild("CloseBtn")

local chancesBadge  = mainFrame:WaitForChild("ChancesBadge")
local chancesText   = chancesBadge:WaitForChild("ChancesText")

local entryTitle    = mainFrame:WaitForChild("EntryTitle")
local inputCharCount = mainFrame:WaitForChild("CharCount")

local colorPickFrame = mainFrame:WaitForChild("ColorPickFrame")
local colorResult    = colorPickFrame:WaitForChild("ColorResult")
local redBox         = colorPickFrame:WaitForChild("Red")
local greenBox       = colorPickFrame:WaitForChild("Green")
local blueBox        = colorPickFrame:WaitForChild("Blue")

-- Instance GUI lama bernama EffectFrame; isinya preset warna, bukan animasi.
local colorPresetFrame = mainFrame:WaitForChild("EffectFrame")

local liveBanner     = mainFrame:WaitForChild("LiveBanner")
local livePreviewPill = liveBanner:WaitForChild("PreviewPill")
local livePreviewText = livePreviewPill:WaitForChild("PreviewText")

local actionRow      = mainFrame:WaitForChild("ActionRow")
local previewBtn     = actionRow:WaitForChild("PreviewBtn")
local applyBtn       = actionRow:WaitForChild("ApplyBtn")

local floatingToast  = screenGui:WaitForChild("FloatingToast")
local toastText      = floatingToast:WaitForChild("ToastText")

local state = {
	title = "",
	color = Color3.fromRGB(255, 255, 255),
	chances = 3,
	maxChances = 3,
	isUnlimited = false,
	level = 1,
	unlimitedThreshold = 50,
	isPreviewing = false,
}

local titleRemotes             = ReplicatedStorage:WaitForChild("TitleRemotes", 15)
local getCustomTitleDataRemote = titleRemotes and titleRemotes:WaitForChild("GetCustomTitleData", 10)
local previewCustomTitleRemote = titleRemotes and titleRemotes:WaitForChild("PreviewCustomTitle", 10)
local previewEndedRemote       = titleRemotes and titleRemotes:WaitForChild("PreviewEnded", 10)
local applyCustomTitleRemote   = titleRemotes and titleRemotes:WaitForChild("ApplyCustomTitle", 10)

local function showNotification(titleText, msgText, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = titleText,
			Text = msgText,
			Duration = duration or 3,
		})
	end)
end

local function updateChancesUI()
	local chanceIcon = chancesBadge:FindFirstChild("ChanceIcon")
	if state.isUnlimited then
		chancesText.Text = string.format("Kesempatan: Unlimited (Level %d+)", state.unlimitedThreshold)
		chancesText.TextColor3 = Color3.fromRGB(255, 215, 0) -- Emas / Gold
		if chanceIcon and chanceIcon:IsA("TextLabel") then
			chanceIcon.Text = "👑"
		end
	else
		if state.chances > 0 then
			chancesText.Text = string.format("Sisa Kesempatan: %d / %d (Level %d+ Unlimited)", state.chances, state.maxChances, state.unlimitedThreshold)
		else
			chancesText.Text = string.format("Kesempatan: 0 / %d (Capai Level %d untuk Unlimited)", state.maxChances, state.unlimitedThreshold)
		end

		if chanceIcon and chanceIcon:IsA("TextLabel") then
			chanceIcon.Text = "✨"
		end
		if state.chances > 1 then
			chancesText.TextColor3 = Color3.fromRGB(70, 230, 140)
		elseif state.chances == 1 then
			chancesText.TextColor3 = Color3.fromRGB(255, 180, 50)
		else
			chancesText.TextColor3 = Color3.fromRGB(255, 80, 80)
		end
	end
end

local function updatePreviewBanner()
	local displayText = state.title ~= "" and state.title or "CONTOH TITLE"
	livePreviewText.Text = displayText
	livePreviewText.TextColor3 = Color3.fromRGB(255, 255, 255) -- Selalu putih!
	livePreviewPill.BackgroundColor3 = state.color
	colorResult.BackgroundColor3 = state.color
end

local function validateRGB(val)
	local num = tonumber(val)
	return (num and num >= 0 and num <= 255) and math.floor(num) or 0
end

local function setColor(c)
	state.color = c
	redBox.Text   = tostring(math.floor(c.R * 255))
	greenBox.Text = tostring(math.floor(c.G * 255))
	blueBox.Text  = tostring(math.floor(c.B * 255))
	updatePreviewBanner()
end

local lastColorClick = 0
for _, child in ipairs(colorPresetFrame:GetChildren()) do
	if child:IsA("TextButton") then
		child.MouseButton1Click:Connect(function()
			local now = os.clock()
			if now - lastColorClick < 0.3 then return end
			lastColorClick = now

			setColor(child.BackgroundColor3)
		end)
	end
end

local function updateFromRGBInputs()
	local r = validateRGB(redBox.Text)
	local g = validateRGB(greenBox.Text)
	local b = validateRGB(blueBox.Text)
	state.color = Color3.fromRGB(r, g, b)
	updatePreviewBanner()
end

redBox:GetPropertyChangedSignal("Text"):Connect(updateFromRGBInputs)
greenBox:GetPropertyChangedSignal("Text"):Connect(updateFromRGBInputs)
blueBox:GetPropertyChangedSignal("Text"):Connect(updateFromRGBInputs)

entryTitle:GetPropertyChangedSignal("Text"):Connect(function()
	local t = entryTitle.Text
	if #t > 50 then
		t = t:sub(1, 50)
		entryTitle.Text = t
	end
	state.title = t
	inputCharCount.Text = string.format("%d/50", #t)
	if #t >= 45 then
		inputCharCount.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		inputCharCount.TextColor3 = Color3.fromRGB(130, 130, 130)
	end
	updatePreviewBanner()
end)

local lastCloseTitleClick = 0
closeBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if now - lastCloseTitleClick < 0.3 then return end
	lastCloseTitleClick = now

	mainFrame.Visible = false
end)


local previewDebounce = false
local lastPreviewClick = 0
previewBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if now - lastPreviewClick < 0.3 then return end
	lastPreviewClick = now

	if previewDebounce then return end
	if state.isPreviewing then return end

	local trimmed = state.title:match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		showNotification("Peringatan", "Ketik nama title terlebih dahulu!", 3)
		return
	end

	previewDebounce = true
	state.isPreviewing = true

	mainFrame.Visible = false

	floatingToast.Visible = true
	toastText.Text = "👁️ Title terpasang di kepalamu (5 detik)..."

	if previewCustomTitleRemote then
		previewCustomTitleRemote:FireServer({
			Title = state.title,
			Color = state.color,
		})
	end

	task.spawn(function()
		for sec = 5, 1, -1 do
			toastText.Text = string.format("👁️ Title terpasang di kepalamu (%d detik)...", sec)
			task.wait(1)
		end

		floatingToast.Visible = false
		state.isPreviewing = false
		previewDebounce = false

		mainFrame.Visible = true
		showNotification("Preview Selesai", "Klik 'Simpan Title' jika kamu sudah cocok!", 4)
	end)
end)

if previewEndedRemote then
	previewEndedRemote.OnClientEvent:Connect(function()
		if state.isPreviewing then
			floatingToast.Visible = false
			state.isPreviewing = false
			previewDebounce = false
			mainFrame.Visible = true
		end
	end)
end


local applyDebounce = false
local lastApplyClick = 0
applyBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if now - lastApplyClick < 0.3 then return end
	lastApplyClick = now

	if applyDebounce then return end
	if not state.isUnlimited and state.chances <= 0 then
		showNotification("Kesempatan Habis", string.format("Kesempatan custom title kamu sudah habis (0/%d)! Capai Level %d untuk Custom Title Unlimited!", state.maxChances, state.unlimitedThreshold), 4)
		return
	end

	local trimmed = state.title:match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		showNotification("Info", "Title tidak boleh kosong!", 3)
		return
	end

	applyDebounce = true
	applyBtn.Text = "Menyimpan..."

	local ok, success, msg, remaining, isUnlimited = pcall(function()
		return applyCustomTitleRemote:InvokeServer({
			Title = trimmed,
			Color = state.color,
		})
	end)

	applyDebounce = false
	applyBtn.Text = "Simpan Title"

	if ok and success then
		if isUnlimited ~= nil then
			state.isUnlimited = isUnlimited
		end
		if not state.isUnlimited then
			state.chances = remaining or math.max(0, state.chances - 1)
		end
		updateChancesUI()
		showNotification("Sukses!", msg or "Title kamu berhasil disimpan!", 5)
		mainFrame.Visible = false
	else
		local errMsg = (not ok and "Gagal menghubungi server") or msg or "Gagal memasang title."
		showNotification("Gagal", errMsg, 4)
	end
end)

-- ====================================
-- LOAD INITIAL DATA
-- ====================================
local function loadInitialData()
	if getCustomTitleDataRemote then
		local ok, data = pcall(function()
			return getCustomTitleDataRemote:InvokeServer()
		end)

		if ok and data then
			state.chances = data.Chances or 3
			state.maxChances = data.MaxChances or 3
			if data.IsUnlimited ~= nil then
				state.isUnlimited = data.IsUnlimited
			end
			if data.Level ~= nil then
				state.level = data.Level
			end
			if data.UnlimitedThreshold ~= nil then
				state.unlimitedThreshold = data.UnlimitedThreshold
			end
			updateChancesUI()

			if data.CurrentTitle and data.CurrentTitle.Title and data.CurrentTitle.Title ~= "" then
				entryTitle.Text = data.CurrentTitle.Title
				state.title = data.CurrentTitle.Title
				if data.CurrentTitle.Color then
					setColor(data.CurrentTitle.Color)
				end
			end
		end
	end
end

local function setupLevelListener()
	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local levelVal = leaderstats:FindFirstChild("Level") or leaderstats:WaitForChild("Level", 5)
		if levelVal and levelVal:IsA("IntValue") then
			local function onLevelChanged(lvl)
				state.level = lvl
				state.isUnlimited = (lvl >= state.unlimitedThreshold)
				updateChancesUI()
			end
			onLevelChanged(levelVal.Value)
			levelVal:GetPropertyChangedSignal("Value"):Connect(function()
				onLevelChanged(levelVal.Value)
			end)
		end
	end
end

task.spawn(setupLevelListener)
task.spawn(loadInitialData)
setColor(Color3.fromRGB(255, 255, 255))
updateChancesUI()

local function toggleCustomTitleGui()
	mainFrame.Visible = not mainFrame.Visible
end

ClientState.registerAction("ToggleCustomTitleGui", toggleCustomTitleGui)

mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainFrame.Visible then
		loadInitialData()
	end
end)

print("[CustomTitle] ✅ CustomTitleClient connected to manual StarterGui.CustomTitleGui successfully.")
