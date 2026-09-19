--!strict
-- ============================================================
-- CUSTOM TITLE CLIENT (DRIVES MANUAL STARTERGUI INSTANCE)
-- ============================================================
-- Operates StarterGui.CustomTitleGui (Manual Studio GUI):
--   - No procedural/hardcoded Instance.new UI generation
--   - Text color ALWAYS pure white (Color3.fromRGB(255, 255, 255))
--   - 15 Color Presets in 3-column Grid (White, Black, Crimson Red, ...)
--   - 3x Chances quota saved in DataStore CustomTitleChances_V1
--   - "Cek Dulu (5s)": 5-second overhead preview, hides GUI, then reopens
--   - "Simpan Title": Deducts 1 chance and permanently saves to PlayerTitles_V4
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- References to Manual Studio GUI in PlayerGui
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

local effectFrame    = mainFrame:WaitForChild("EffectFrame")

local liveBanner     = mainFrame:WaitForChild("LiveBanner")
local livePreviewPill = liveBanner:WaitForChild("PreviewPill")
local livePreviewText = livePreviewPill:WaitForChild("PreviewText")

local actionRow      = mainFrame:WaitForChild("ActionRow")
local previewBtn     = actionRow:WaitForChild("PreviewBtn")
local applyBtn       = actionRow:WaitForChild("ApplyBtn")

local floatingToast  = screenGui:WaitForChild("FloatingToast")
local toastText      = floatingToast:WaitForChild("ToastText")

-- State
local state = {
	title = "",
	color = Color3.fromRGB(255, 255, 255),
	chances = 3,
	maxChances = 3,
	isPreviewing = false,
}

-- Remotes
local titleRemotes             = ReplicatedStorage:WaitForChild("TitleRemotes", 15)
local getCustomTitleDataRemote = titleRemotes and titleRemotes:WaitForChild("GetCustomTitleData", 10)
local previewCustomTitleRemote = titleRemotes and titleRemotes:WaitForChild("PreviewCustomTitle", 10)
local previewEndedRemote       = titleRemotes and titleRemotes:WaitForChild("PreviewEnded", 10)
local applyCustomTitleRemote   = titleRemotes and titleRemotes:WaitForChild("ApplyCustomTitle", 10)

-- Notification Helper
local function showNotification(titleText, msgText, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = titleText,
			Text = msgText,
			Duration = duration or 3,
		})
	end)
end

-- Update Chances UI
local function updateChancesUI()
	chancesText.Text = string.format("Sisa Kesempatan: %d / %d", state.chances, state.maxChances)
	if state.chances > 1 then
		chancesText.TextColor3 = Color3.fromRGB(70, 230, 140)
	elseif state.chances == 1 then
		chancesText.TextColor3 = Color3.fromRGB(255, 180, 50)
	else
		chancesText.TextColor3 = Color3.fromRGB(255, 80, 80)
	end
end

-- Update In-GUI Preview Banner (TEXT SELALU PUTIH BERSIH)
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

-- Connect 15 Preset Buttons in EffectFrame Grid
for _, child in ipairs(effectFrame:GetChildren()) do
	if child:IsA("TextButton") then
		child.MouseButton1Click:Connect(function()
			setColor(child.BackgroundColor3)
		end)
	end
end

-- Manual RGB Inputs Handler
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

-- Title Input Text Change
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

-- Close Button Click
closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- ====================================
-- "CEK DULU" (5-SECOND PREVIEW) LOGIC
-- ====================================
local previewDebounce = false
previewBtn.MouseButton1Click:Connect(function()
	if previewDebounce then return end
	if state.isPreviewing then return end

	local trimmed = state.title:match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		showNotification("Peringatan", "Ketik nama title terlebih dahulu!", 3)
		return
	end

	previewDebounce = true
	state.isPreviewing = true

	-- 1. Otomatis sembunyikan GUI
	mainFrame.Visible = false

	-- 2. Tampilkan toast preview 5 detik
	floatingToast.Visible = true
	toastText.Text = "👁️ Title terpasang di kepalamu (5 detik)..."

	-- 3. Kirim data preview ke server (Solid background, text selalu putih)
	if previewCustomTitleRemote then
		previewCustomTitleRemote:FireServer({
			Title = state.title,
			Color = state.color,
			GradientEnabled = false,
			GradientEffect = "none",
		})
	end

	-- 4. Countdown 5 detik
	task.spawn(function()
		for sec = 5, 1, -1 do
			toastText.Text = string.format("👁️ Title terpasang di kepalamu (%d detik)...", sec)
			task.wait(1)
		end

		floatingToast.Visible = false
		state.isPreviewing = false
		previewDebounce = false

		-- 5. Munculkan kembali GUI
		mainFrame.Visible = true
		showNotification("Preview Selesai", "Klik 'Simpan Title' jika kamu sudah cocok!", 4)
	end)
end)

-- Remote fallback when preview ends on server
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

-- ====================================
-- "SIMPAN TITLE" (APPLY) LOGIC
-- ====================================
local applyDebounce = false
applyBtn.MouseButton1Click:Connect(function()
	if applyDebounce then return end
	if state.chances <= 0 then
		showNotification("Kesempatan Habis", "Kesempatan custom title kamu sudah habis (0/3)!", 4)
		return
	end

	local trimmed = state.title:match("^%s*(.-)%s*$") or ""
	if trimmed == "" then
		showNotification("Info", "Title tidak boleh kosong!", 3)
		return
	end

	applyDebounce = true
	applyBtn.Text = "Menyimpan..."

	local ok, success, msg, remaining = pcall(function()
		return applyCustomTitleRemote:InvokeServer({
			Title = trimmed,
			Color = state.color,
			GradientEnabled = false,
			GradientEffect = "none",
		})
	end)

	applyDebounce = false
	applyBtn.Text = "Simpan Title"

	if ok and success then
		state.chances = remaining or math.max(0, state.chances - 1)
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

task.spawn(loadInitialData)
setColor(Color3.fromRGB(255, 255, 255))
updateChancesUI()

-- Expose open/close for TopbarPlus
_G.ToggleCustomTitleGui = function()
	mainFrame.Visible = not mainFrame.Visible
end

mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainFrame.Visible then
		loadInitialData()
	end
end)

print("[CustomTitle] ✅ CustomTitleClient connected to manual StarterGui.CustomTitleGui successfully.")
