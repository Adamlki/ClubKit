-- ============================================
-- SINGLETON PROTECTION & GLOBAL FLAGS
-- ============================================
if _G.__SettingClientLoaded then return end
_G.__SettingClientLoaded = true

_G.HideDonationEffects = false
_G.IsDonationEffectsHidden = function()
	return _G.HideDonationEffects == true
end
_G.HideAdminNotif = false

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	DEBUG_MODE = false, 
	DEBUG_DETAILED = false, 

	ANIMATION_DURATION = 0.3,
	ANIMATION_STYLE = Enum.EasingStyle.Quad,
	ANIMATION_DIRECTION = Enum.EasingDirection.Out,

	WAIT_FOR_ACCESSORIES = 0.5, 
	WAIT_FOR_TOOLS = 0.1, 
	WAIT_FOR_OVERHEAD = 0.3, 
	WAIT_FOR_EFFECTS = 0.2, 

	DETECT_AURA_NAMES = true, 
	AURA_KEYWORDS = {"aura", "effect", "vfx", "particle", "donation"}, 

	BUTTON_POS_ON = UDim2.new(0, 32, 0.5, 0),
	BUTTON_POS_OFF = UDim2.new(0, 12, 0.5, 0),

	BG_COLOR_ON = Color3.fromRGB(27, 67, 46),
	BG_COLOR_OFF = Color3.fromRGB(28, 28, 28),
}

-- ============================================
-- SERVICES
-- ============================================
local player = game:GetService("Players")
local replicatedstorage = game:GetService("ReplicatedStorage")
local tweenservice = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local textChatService = game:GetService("TextChatService")
local collectionService = game:GetService("CollectionService")

local localPlayer = player.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ============================================
-- UI REFERENCES
-- ============================================
local gui = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("SettingGui")
local mainframe = gui:WaitForChild("Mainframe")
local settingBtn = gui:FindFirstChild("SettingBtn")
local headerframe = mainframe:WaitForChild("HeaderFrame")
local closeBtn = headerframe:WaitForChild("CloseBtn")

local unhideBtn = gui:WaitForChild("Unhide")
unhideBtn.Visible = false 

local containerframe = mainframe:WaitForChild("ContainerFrame")
local templateframe = containerframe:WaitForChild("TemplateFrame")
templateframe.Visible = false

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local Utils = {}

function Utils:IsAura(object)
	if not CONFIG.DETECT_AURA_NAMES then return false end
	local name = object.Name:lower()
	for _, keyword in ipairs(CONFIG.AURA_KEYWORDS) do
		if name:find(keyword:lower()) then return true end
	end
	return false
end

function Utils:AnimateButton(button, bg, isActive)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	local tweenInfo = TweenInfo.new(CONFIG.ANIMATION_DURATION, CONFIG.ANIMATION_STYLE, CONFIG.ANIMATION_DIRECTION)
	local newPosition = isActive and CONFIG.BUTTON_POS_ON or CONFIG.BUTTON_POS_OFF
	local newColor = isActive and CONFIG.BG_COLOR_ON or CONFIG.BG_COLOR_OFF
	local stroke = bg:FindFirstChildOfClass("UIStroke")
	if stroke then
		local newStrokeColor = isActive and Color3.fromRGB(46, 210, 115) or Color3.fromRGB(44, 44, 44)
		tweenservice:Create(stroke, tweenInfo, {Color = newStrokeColor}):Play()
	end
	tweenservice:Create(button, tweenInfo, {Position = newPosition}):Play()
	tweenservice:Create(bg, tweenInfo, {BackgroundColor3 = newColor}):Play()
end

function Utils:HideEffect(effect, shouldHide)
	if effect:IsA("ParticleEmitter") or effect:IsA("Fire") or effect:IsA("Smoke") or effect:IsA("Sparkles") or effect:IsA("Trail") or effect:IsA("Beam") then

		-- [TAMBAHKAN INI]: Simpan kondisi asli sebelum dimanipulasi
		if effect:GetAttribute("OriginalEnabled") == nil then
			effect:SetAttribute("OriginalEnabled", effect.Enabled)
		end

		if shouldHide then
			effect.Enabled = false
		else
			-- [UBAH INI]: Kembalikan ke kondisi asli, bukan dipaksa 'true'
			effect.Enabled = effect:GetAttribute("OriginalEnabled")
		end
		return true
	end
	return false
end

function Utils:HideLight(light, shouldHide)
	if light:IsA("Light") or light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then

		if light:GetAttribute("OriginalEnabled") == nil then
			light:SetAttribute("OriginalEnabled", light.Enabled)
		end

		if shouldHide then
			light.Enabled = false
		else
			light.Enabled = light:GetAttribute("OriginalEnabled")
		end
		return true
	end
	return false
end

function Utils:HideGui(guiObj, shouldHide)
	if guiObj:IsA("BillboardGui") or guiObj:IsA("SurfaceGui") then
		guiObj.Enabled = not shouldHide
		return true
	end
	return false
end

-- ============================================
-- SYSTEM DECLARATIONS
-- ============================================
local OverheadSystem = {}
local BubbleChatSystem = {}
local ShadowSystem = {}
local PlayerHideSystem = {}
local EffectsSystem = {}
local DonationEffectSystem = {}
local AdminNotifSystem = {}
local HideUISystem = { hiddenGuis = {}, childAddedConn = nil }

local FeatureManager = {
	features = {},
	featureStates = {}
}

-- ============================================
-- FEATURES CONFIGURATION
-- ============================================
local FEATURES = {
	{
		id = "overhead",
		name = "Hide Player Name",
		defaultState = false,
		onToggle = function(self, isActive) OverheadSystem:SetVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) OverheadSystem:OnCharacterAdded(character, player) end
	},
	{
		id = "bubblechat",
		name = "Hide Bubble Chat",
		defaultState = false,
		onToggle = function(self, isActive) BubbleChatSystem:SetVisible(not isActive) end
	},
	{
		id = "shadow",
		name = "Hide All Shadow",
		defaultState = true,
		onToggle = function(self, isActive) ShadowSystem:SetVisible(not isActive) end
	},
	{
		id = "players",
		name = "Hide All Players",
		defaultState = false,
		onToggle = function(self, isActive) PlayerHideSystem:SetPlayersVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) PlayerHideSystem:OnCharacterAdded(character, player) end
	},
	{
		id = "effects",
		name = "Hide Effect Player",
		defaultState = false,
		onToggle = function(self, isActive) EffectsSystem:SetEffectsVisible(not isActive) end,
		onCharacterAdded = function(self, character, player) EffectsSystem:OnCharacterAdded(character, player) end
	},
	{
		id = "donationeffect",
		name = "Hide Effect Donate",
		defaultState = false,
		onToggle = function(self, isActive) DonationEffectSystem:SetVisible(not isActive) end
	},
	{
		id = "adminnotif",
		name = "Hide Notif Admin",
		defaultState = false,
		onToggle = function(self, isActive) AdminNotifSystem:SetVisible(not isActive) end
	},
	{
		id = "hideui",
		name = "Hide All UI",
		defaultState = false,
		onToggle = function(self, isActive) HideUISystem:SetVisible(isActive) end
	}
}

-- ============================================
-- FEATURE MANAGER
-- ============================================
function FeatureManager:RegisterFeature(featureConfig)
	if not featureConfig.id or not featureConfig.name then return false end

	local featureFrame = templateframe:Clone()
	featureFrame.Name = featureConfig.id .. "Frame"
	featureFrame.Visible = true

	local label = featureFrame:FindFirstChild("TemplateLabel")
	if label then label.Text = featureConfig.name end

	local bg = featureFrame:FindFirstChild("Templatebg")
	if not bg then return false end

	local button = bg:FindFirstChild("OnBtn") or bg:FindFirstChild("TemplateBtn")
	if not button then return false end

	self.featureStates[featureConfig.id] = featureConfig.defaultState or false

	button.MouseButton1Click:Connect(function()
		self:ToggleFeature(featureConfig.id)
	end)

	self.features[featureConfig.id] = {
		config = featureConfig, frame = featureFrame,
		button = button, bg = bg, label = label
	}

	if self.featureStates[featureConfig.id] then
		button.Position = CONFIG.BUTTON_POS_ON
		bg.BackgroundColor3 = CONFIG.BG_COLOR_ON
		local stroke = bg:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(46, 210, 115) end
		if featureConfig.onToggle then
			task.spawn(function() featureConfig.onToggle(featureConfig, true) end)
		end
	else
		button.Position = CONFIG.BUTTON_POS_OFF
		bg.BackgroundColor3 = CONFIG.BG_COLOR_OFF
		local stroke = bg:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(44, 44, 44) end
		if featureConfig.onToggle then
			task.spawn(function() featureConfig.onToggle(featureConfig, false) end)
		end
	end

	featureFrame.Parent = containerframe
	return true
end
function FeatureManager:ToggleFeature(featureId)
	local feature = self.features[featureId]
	if not feature or not feature.button then return end

	local newState = not self.featureStates[featureId]
	self.featureStates[featureId] = newState

	Utils:AnimateButton(feature.button, feature.bg, newState)

	if feature.config.onToggle then
		feature.config.onToggle(feature.config, newState)
	end
end

function FeatureManager:SetFeature(featureId, targetState)
	local feature = self.features[featureId]
	if not feature or not feature.button then return end
	if self.featureStates[featureId] == targetState then return end

	self.featureStates[featureId] = targetState
	Utils:AnimateButton(feature.button, feature.bg, targetState)

	if feature.config.onToggle then
		feature.config.onToggle(feature.config, targetState)
	end
end

function FeatureManager:GetFeatureState(featureId)
	return self.featureStates[featureId] or false
end

function FeatureManager:OnCharacterAdded(character, playerObj)
	for featureId, feature in pairs(self.features) do
		if feature.config.onCharacterAdded then
			feature.config.onCharacterAdded(feature.config, character, playerObj)
		end
	end
end

-- ============================================
-- HIDE ALL UI SYSTEM
-- ============================================
function HideUISystem:SetVisible(isHiding)
	if isHiding then
		self.hiddenGuis = {}
		for _, childGui in ipairs(playerGui:GetChildren()) do
			if childGui:IsA("ScreenGui") and childGui ~= gui and childGui.Enabled then
				self.hiddenGuis[childGui] = true
				childGui.Enabled = false
			end
		end
		mainframe.Visible = false
		unhideBtn.Visible = true

		-- 🔥 FIX 2: Cegah UI baru muncul saat mode Hide UI sedang menyala (Penjaga Pintu)
		if not self.childAddedConn then
			self.childAddedConn = playerGui.ChildAdded:Connect(function(childGui)
				if childGui:IsA("ScreenGui") and childGui ~= gui then
					-- task.wait() TELAH DIHAPUS DI SINI AGAR TIDAK FLICKER
					if childGui.Enabled then
						self.hiddenGuis[childGui] = true
						childGui.Enabled = false
					end
				end
			end)
		end
	else
		for hiddenGui, _ in pairs(self.hiddenGuis) do
			if hiddenGui and hiddenGui.Parent then hiddenGui.Enabled = true end
		end
		self.hiddenGuis = {} 
		unhideBtn.Visible = false

		if self.childAddedConn then
			self.childAddedConn:Disconnect()
			self.childAddedConn = nil
		end
	end
end

-- ============================================
-- MAINFRAME & UNHIDE TOGGLE
-- ============================================
if settingBtn then
	settingBtn.MouseButton1Click:Connect(function()
		mainframe.Visible = not mainframe.Visible
	end)
end

closeBtn.MouseButton1Click:Connect(function() mainframe.Visible = false end)
unhideBtn.MouseButton1Click:Connect(function()
	if FeatureManager:GetFeatureState("hideui") then FeatureManager:ToggleFeature("hideui") end
end)

-- ============================================
-- OTHER SYSTEMS
-- ============================================
function BubbleChatSystem:SetVisible(visible)
	pcall(function()
		local bubbleChatConfig = textChatService:FindFirstChild("BubbleChatConfiguration")
		if bubbleChatConfig then bubbleChatConfig.Enabled = visible end
	end)
end

function OverheadSystem:HideOverheadGui(character, shouldHide)
	local overheadGui = character:FindFirstChild("PlayerOverhead")
	if overheadGui and overheadGui:IsA("BillboardGui") then
		overheadGui.Enabled = not shouldHide
	end
end

function OverheadSystem:SetVisible(visible)
	local isHidingNames = FeatureManager:GetFeatureState("overhead")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")

	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer.Character then
			-- 🔥 FIX 1: Cross-check dengan status Hide Players
			local shouldHide = isHidingNames
			if otherPlayer ~= localPlayer and isHidingPlayers then
				shouldHide = true
			end

			self:HideOverheadGui(otherPlayer.Character, shouldHide)
		end
	end
end

function OverheadSystem:OnCharacterAdded(character, otherPlayer)
	character.ChildAdded:Connect(function(child)
		if child.Name == "PlayerOverhead" then
			task.wait(0.1)

			local isHidingNames = FeatureManager:GetFeatureState("overhead")
			local isHidingPlayers = FeatureManager:GetFeatureState("players")

			local shouldHide = isHidingNames
			if otherPlayer ~= localPlayer and isHidingPlayers then
				shouldHide = true
			end

			if shouldHide and child:IsA("BillboardGui") then
				child.Enabled = false
			end
		end
	end)

	task.wait(CONFIG.WAIT_FOR_OVERHEAD)

	local isHidingNames = FeatureManager:GetFeatureState("overhead")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")

	local shouldHide = isHidingNames
	if otherPlayer ~= localPlayer and isHidingPlayers then
		shouldHide = true
	end

	if shouldHide then
		self:HideOverheadGui(character, true)
	end
end

function ShadowSystem:SetVisible(visible)
	lighting.GlobalShadows = visible
end

-- ============================================
-- EFFECTS HIDE SYSTEM
-- ============================================
function EffectsSystem:HideCharacterEffects(character, shouldHide)
	for _, descendant in pairs(character:GetDescendants()) do
		if not descendant:FindFirstAncestorOfClass("Tool") then
			Utils:HideEffect(descendant, shouldHide)
			
		end
	end
end

function EffectsSystem:HideAuraEffects(character, shouldHide)
	for _, child in pairs(character:GetChildren()) do
		if Utils:IsAura(child) and not child:IsA("Tool") then
			Utils:HideBasePart(child, shouldHide)
			for _, descendant in pairs(child:GetDescendants()) do
				Utils:HideEffect(descendant, shouldHide) 
				 
				Utils:HideBasePart(descendant, shouldHide)
			end
		end
	end
end

function EffectsSystem:SetEffectsVisible(visible)
	local isHidingEffects = FeatureManager:GetFeatureState("effects")
	local isHidingPlayers = FeatureManager:GetFeatureState("players")
	local shouldHide = isHidingEffects or isHidingPlayers

	-- Sembunyikan efek di semua karakter (kecuali Tool)
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character
			self:HideCharacterEffects(character, shouldHide)
			self:HideAuraEffects(character, shouldHide)
		end
	end
end

function EffectsSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer ~= localPlayer then
		task.wait(CONFIG.WAIT_FOR_EFFECTS)

		local isHidingEffects = FeatureManager:GetFeatureState("effects")
		local isHidingPlayers = FeatureManager:GetFeatureState("players")
		local shouldHide = isHidingEffects or isHidingPlayers

		if shouldHide then
			self:HideCharacterEffects(character, true)
			self:HideAuraEffects(character, true)
		end

		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
				if not descendant:FindFirstAncestorOfClass("Tool") then
					if FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players") then
						Utils:HideEffect(descendant, true)
					end
				end
			end
		end)

		character.ChildAdded:Connect(function(child)
			task.wait(CONFIG.WAIT_FOR_EFFECTS)
			if Utils:IsAura(child) and not child:IsA("Tool") and (FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players")) then
				Utils:HideBasePart(child, true)
				for _, descendant in pairs(child:GetDescendants()) do
					Utils:HideEffect(descendant, true)
					Utils:HideBasePart(descendant, true)
				end
			end
		end)
	end
end

-- ============================================
-- DONATION EFFECT SYSTEM (ROBUX & SAWERIA)
-- ============================================
function DonationEffectSystem:SetVisible(visible)
	local shouldHide = not visible
	_G.HideDonationEffects = shouldHide

	-- 1. Sembunyikan objek donasi 3D di Workspace (DonationEffect tag)
	for _, effect in ipairs(collectionService:GetTagged("DonationEffect")) do
		Utils:HideBasePart(effect, shouldHide)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, shouldHide)
			Utils:HideLight(desc, shouldHide)
			Utils:HideBasePart(desc, shouldHide)
		end
	end

	-- 2. Sembunyikan semprotan panggung (StageEffects)
	local stageEffectsFolder = workspace:FindFirstChild("StageEffects")
	if stageEffectsFolder then
		for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
			if stageFX:IsA("BasePart") then
				local sound = stageFX:FindFirstChild("HissSound")
				if sound and shouldHide then
					pcall(function() sound:Stop() end)
				end
				for _, fx in ipairs(stageFX:GetChildren()) do
					if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
						Utils:HideEffect(fx, shouldHide)
					end
				end
			end
		end
	end

	-- 3. Hapus efek animasi 3D yang sedang aktif jika disembunyikan
	if shouldHide then
		local activeEffects = workspace:FindFirstChild("ActiveEffects")
		if activeEffects then
			for _, effect in ipairs(activeEffects:GetChildren()) do
				pcall(function() effect:Destroy() end)
			end
		end
	end
end

-- Event: Deteksi donasi baru di Workspace saat Hide Effect Donate aktif
collectionService:GetInstanceAddedSignal("DonationEffect"):Connect(function(effect)
	task.wait(0.1)
	if FeatureManager:GetFeatureState("donationeffect") or _G.HideDonationEffects then
		Utils:HideBasePart(effect, true)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, true)
			Utils:HideLight(desc, true)
			Utils:HideBasePart(desc, true)
		end
	end
end)

-- Listener pencegah server replication menyalakan StageEffects saat disembunyikan
local stageEffectsFolder = workspace:FindFirstChild("StageEffects")
if stageEffectsFolder then
	for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
		if stageFX:IsA("BasePart") then
			local sound = stageFX:FindFirstChild("HissSound")
			if sound then
				sound:GetPropertyChangedSignal("Playing"):Connect(function()
					if _G.HideDonationEffects and sound.Playing then
						pcall(function() sound:Stop() end)
					end
				end)
			end
			for _, fx in ipairs(stageFX:GetChildren()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx:GetPropertyChangedSignal("Enabled"):Connect(function()
						if _G.HideDonationEffects and fx.Enabled then
							fx.Enabled = false
						end
					end)
				end
			end
		end
	end
end

-- ============================================
-- ADMIN NOTIFICATION SYSTEM
-- ============================================
_G.HideAdminNotif = false

function AdminNotifSystem:SetVisible(visible)
	local shouldHide = not visible
	_G.HideAdminNotif = shouldHide

	if shouldHide then
		local notifGui = playerGui:FindFirstChild("MessageNotifications")
		if notifGui then
			local listFrame = notifGui:FindFirstChild("NotificationList")
			if listFrame then
				for _, child in ipairs(listFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name ~= "TemplateFrame" then
						child.Visible = false
						child:Destroy()
					end
				end
			end
		end
	end
end

-- ============================================
-- PLAYER HIDE SYSTEM
-- ============================================
function PlayerHideSystem:HideObject(object, shouldHide)
	local isHidingEffects = FeatureManager:GetFeatureState("effects")

	-- Efek tidak boleh muncul ulang jika salah satu tombol (Hide Players atau Hide Effects) menyala
	local hideEffect = shouldHide or isHidingEffects

	for _, descendant in pairs(object:GetDescendants()) do
		Utils:HideBasePart(descendant, shouldHide)
		Utils:HideEffect(descendant, hideEffect)
		Utils:HideLight(descendant, hideEffect)
		Utils:HideGui(descendant, shouldHide)
	end
end

function PlayerHideSystem:HideTools(otherPlayer, character, shouldHide)
	if otherPlayer.Backpack then
		for _, tool in pairs(otherPlayer.Backpack:GetChildren()) do
			if tool:IsA("Tool") then self:HideObject(tool, shouldHide) end
		end
	end
	for _, child in pairs(character:GetChildren()) do
		if child:IsA("Tool") then self:HideObject(child, shouldHide) end
	end
end

function PlayerHideSystem:SetPlayersVisible(visible)
	local isHidingPlayers = FeatureManager:GetFeatureState("players")
	local isHidingNames = FeatureManager:GetFeatureState("overhead")

	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character

			self:HideObject(character, isHidingPlayers)
			self:HideTools(otherPlayer, character, isHidingPlayers)

			local hideOverhead = isHidingPlayers or isHidingNames
			OverheadSystem:HideOverheadGui(character, hideOverhead) 
		end
	end
end

function PlayerHideSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer ~= localPlayer then
		task.wait(CONFIG.WAIT_FOR_ACCESSORIES)

		if FeatureManager:GetFeatureState("players") then
			self:HideObject(character, true)
			self:HideTools(otherPlayer, character, true)

			OverheadSystem:HideOverheadGui(character, true)
		end

		character.ChildAdded:Connect(function(child)
			task.wait(CONFIG.WAIT_FOR_TOOLS)
			if FeatureManager:GetFeatureState("players") then
				if child:IsA("Tool") or Utils:IsAura(child) then 
					self:HideObject(child, true) 
				end
			end
		end)

		if otherPlayer.Backpack then
			otherPlayer.Backpack.ChildAdded:Connect(function(child)
				task.wait(CONFIG.WAIT_FOR_TOOLS)
				if child:IsA("Tool") and FeatureManager:GetFeatureState("players") then
					self:HideObject(child, true)
				end
			end)
		end
	end
end

-- ============================================
-- INITIALIZE
-- ============================================
for _, featureConfig in ipairs(FEATURES) do
	FeatureManager:RegisterFeature(featureConfig)
end

for _, otherPlayer in pairs(player:GetPlayers()) do
	if otherPlayer.Character then FeatureManager:OnCharacterAdded(otherPlayer.Character, otherPlayer) end
end

player.PlayerAdded:Connect(function(otherPlayer)
	otherPlayer.CharacterAdded:Connect(function(character)
		FeatureManager:OnCharacterAdded(character, otherPlayer)
	end)
end)


-- ============================================
-- GRAPHICS QUALITY MONITOR
-- ============================================
local userSettings = UserSettings():GetService("UserGameSettings")

local function onGraphicsQualityChanged()
	local quality = userSettings.SavedQualityLevel
	local qualityValue = quality.Value
	
	-- Automatic = 0. Manual levels = QualityLevel1 (1) to QualityLevel10 (10).
	-- Level 1-4 bars are the left (low graphics) side of the graphics slider.
	if qualityValue > 0 then
		if qualityValue <= 4 then
			-- Bar kiri (1-4 bar / Grafik rendah): Aktifkan Hide Effect Player, Hide Effect Donate, & Hide All Shadow
			FeatureManager:SetFeature("effects", true)
			FeatureManager:SetFeature("donationeffect", true)
			FeatureManager:SetFeature("shadow", true)
		else
			-- Bar kanan (5-10 bar / Grafik sedang-tinggi): Matikan fitur sembunyikan otomatis
			FeatureManager:SetFeature("effects", false)
			FeatureManager:SetFeature("donationeffect", false)
			FeatureManager:SetFeature("shadow", false)
		end
	end
end

userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(onGraphicsQualityChanged)
-- Panggil saat inisialisasi awal
onGraphicsQualityChanged()
