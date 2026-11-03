--!optimize 2

local ScriptOnce = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("ScriptOnce"))
if not ScriptOnce.Claim("SettingClient") then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientSettingsState = require(script.Parent:WaitForChild("Modules"):WaitForChild("ClientSettingsState"))
local ClientState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClientState"))

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

local player = game:GetService("Players")
local tweenservice = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local textChatService = game:GetService("TextChatService")
local collectionService = game:GetService("CollectionService")

local localPlayer = player.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local gui = script.Parent:IsA("ScreenGui") and script.Parent or playerGui:WaitForChild("SettingGui", 30)
if not gui then
	warn("[SettingClient] SettingGui tidak ditemukan di PlayerGui dalam 30 detik!")
	return
end
local mainframe = gui:WaitForChild("Mainframe", 15)
local settingBtn = gui:FindFirstChild("SettingBtn")
local headerframe = mainframe:WaitForChild("HeaderFrame")
local closeBtn = headerframe:WaitForChild("CloseBtn")

local unhideBtn = gui:WaitForChild("Unhide")
unhideBtn.Visible = false 

local containerframe = mainframe:WaitForChild("ContainerFrame")
local templateframe = containerframe:WaitForChild("TemplateFrame")
templateframe.Visible = false

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
	local stroke = bg:FindFirstChildOfClass("UIStroke")
	if stroke then
		tweenservice:Create(stroke, tweenInfo, { Color = isActive and Color3.fromRGB(46, 210, 115) or Color3.fromRGB(44, 44, 44) }):Play()
	end
	tweenservice:Create(button, tweenInfo, { Position = isActive and CONFIG.BUTTON_POS_ON or CONFIG.BUTTON_POS_OFF }):Play()
	tweenservice:Create(bg, tweenInfo, { BackgroundColor3 = isActive and CONFIG.BG_COLOR_ON or CONFIG.BG_COLOR_OFF }):Play()
end

function Utils:HideBasePart(part, shouldHide)
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = shouldHide and 1 or 0
		return true
	elseif part:IsA("Decal") or part:IsA("Texture") then
		if part:GetAttribute("OriginalTransparency") == nil then
			part:SetAttribute("OriginalTransparency", part.Transparency)
		end
		part.Transparency = shouldHide and 1 or (part:GetAttribute("OriginalTransparency") or 0)
		return true
	end
	return false
end

function Utils:HideEnabled(obj, shouldHide)
	if obj:GetAttribute("OriginalEnabled") == nil then
		obj:SetAttribute("OriginalEnabled", obj.Enabled)
	end
	obj.Enabled = if shouldHide then false else (obj:GetAttribute("OriginalEnabled") == true)
	return true
end

function Utils:HideEffect(effect, shouldHide)
	if effect:IsA("ParticleEmitter") or effect:IsA("Fire") or effect:IsA("Smoke") or effect:IsA("Sparkles") or effect:IsA("Trail") or effect:IsA("Beam") then
		return self:HideEnabled(effect, shouldHide)
	end
	return false
end

function Utils:HideLight(light, shouldHide)
	if light:IsA("Light") then
		return self:HideEnabled(light, shouldHide)
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

local OverheadSystem = {}
local BubbleChatSystem = {}
local ShadowSystem = {}
local PlayerHideSystem = {}
local EffectsSystem = {}
local DonationEffectSystem = {}
local DonationNotifSystem = {}
local AdminNotifSystem = {}
local HideUISystem = { hiddenGuis = {}, childAddedConn = nil }
local CameraFocusSystem = {
	currentMode = "DEFAULT",
	isApplying = false,
	buttons = {},
}

local FeatureManager = {
	features = {},
	featureStates = {}
}

local FEATURES = {
	{
		id = "overhead",
		name = "Hide Player Name",
		defaultState = false,
		onToggle = function(self, isActive) OverheadSystem:SetVisible(not isActive) end,
		onCharacterAdded = function(self, character, p) OverheadSystem:OnCharacterAdded(character, p) end
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
		onCharacterAdded = function(self, character, p) PlayerHideSystem:OnCharacterAdded(character, p) end
	},
	{
		id = "effects",
		name = "Hide Effect Player",
		defaultState = false,
		onToggle = function(self, isActive) EffectsSystem:SetEffectsVisible(not isActive) end,
		onCharacterAdded = function(self, character, p) EffectsSystem:OnCharacterAdded(character, p) end
	},
	{
		id = "donationeffect",
		name = "Hide Effect Donate",
		defaultState = false,
		onToggle = function(self, isActive) DonationEffectSystem:SetVisible(not isActive) end
	},
	{
		id = "donationnotif",
		name = "Hide Notif Pesan Donate",
		defaultState = false,
		onToggle = function(self, isActive) DonationNotifSystem:SetVisible(not isActive) end
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

function FeatureManager:RegisterFeature(featureConfig)
	if not featureConfig.id or not featureConfig.name then return false end

	local featureFrame = templateframe:Clone()
	featureFrame.Name = featureConfig.id .. "Frame"
	featureFrame.LayoutOrder = 1
	featureFrame.Visible = true

	local label = featureFrame:FindFirstChild("TemplateLabel")
	if label then label.Text = featureConfig.name end

	local bg = featureFrame:FindFirstChild("Templatebg")
	local button = bg and (bg:FindFirstChild("OnBtn") or bg:FindFirstChild("TemplateBtn"))
	if not bg or not button then return false end

	local isActive = featureConfig.defaultState or false
	self.featureStates[featureConfig.id] = isActive

	local lastToggleClick = 0
	button.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastToggleClick < 0.3 then return end
		lastToggleClick = now
		self:ToggleFeature(featureConfig.id)
	end)

	self.features[featureConfig.id] = {
		config = featureConfig, frame = featureFrame,
		button = button, bg = bg, label = label
	}

	button.Position = isActive and CONFIG.BUTTON_POS_ON or CONFIG.BUTTON_POS_OFF
	bg.BackgroundColor3 = isActive and CONFIG.BG_COLOR_ON or CONFIG.BG_COLOR_OFF
	local stroke = bg:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = isActive and Color3.fromRGB(46, 210, 115) or Color3.fromRGB(44, 44, 44) end

	if featureConfig.onToggle then
		task.spawn(function() featureConfig.onToggle(featureConfig, isActive) end)
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
	if not feature or not feature.button or self.featureStates[featureId] == targetState then return end

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
	for _, feature in pairs(self.features) do
		if feature.config.onCharacterAdded then
			feature.config.onCharacterAdded(feature.config, character, playerObj)
		end
	end
end

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

		if not self.childAddedConn then
			self.childAddedConn = playerGui.ChildAdded:Connect(function(childGui)
				if childGui:IsA("ScreenGui") and childGui ~= gui and childGui.Enabled then
					self.hiddenGuis[childGui] = true
					childGui.Enabled = false
				end
			end)
		end
	else
		for hiddenGui in pairs(self.hiddenGuis) do
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

if settingBtn then
	local lastSettingClick = 0
	settingBtn.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastSettingClick < 0.3 then return end
		lastSettingClick = now
		mainframe.Visible = not mainframe.Visible
	end)
end

local lastCloseSettingClick = 0
closeBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if now - lastCloseSettingClick < 0.3 then return end
	lastCloseSettingClick = now
	mainframe.Visible = false
end)

local lastUnhideClick = 0
unhideBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if now - lastUnhideClick < 0.3 then return end
	lastUnhideClick = now
	if FeatureManager:GetFeatureState("hideui") then FeatureManager:ToggleFeature("hideui") end
end)

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
			local shouldHide = isHidingNames or (otherPlayer ~= localPlayer and isHidingPlayers)
			self:HideOverheadGui(otherPlayer.Character, shouldHide)
		end
	end
end

function OverheadSystem:OnCharacterAdded(character, otherPlayer)
	character.ChildAdded:Connect(function(child)
		if child.Name == "PlayerOverhead" then
			task.wait(0.1)
			local shouldHide = FeatureManager:GetFeatureState("overhead") or (otherPlayer ~= localPlayer and FeatureManager:GetFeatureState("players"))
			if shouldHide and child:IsA("BillboardGui") then
				child.Enabled = false
			end
		end
	end)

	task.wait(CONFIG.WAIT_FOR_OVERHEAD)
	local shouldHide = FeatureManager:GetFeatureState("overhead") or (otherPlayer ~= localPlayer and FeatureManager:GetFeatureState("players"))
	if shouldHide then
		self:HideOverheadGui(character, true)
	end
end

function ShadowSystem:SetVisible(visible)
	lighting.GlobalShadows = visible
end

function EffectsSystem:HideCharacterEffects(character, shouldHide)
	local processed = 0
	for _, descendant in pairs(character:GetDescendants()) do
		if not descendant:FindFirstAncestorOfClass("Tool") then
			Utils:HideEffect(descendant, shouldHide)
		end
		processed += 1
		if processed % 50 == 0 then task.wait() end
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
	local shouldHide = FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players")
	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			self:HideCharacterEffects(otherPlayer.Character, shouldHide)
			self:HideAuraEffects(otherPlayer.Character, shouldHide)
		end
	end
end

function EffectsSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer == localPlayer then return end
	task.wait(CONFIG.WAIT_FOR_EFFECTS)

	local shouldHide = FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players")
	if shouldHide then
		self:HideCharacterEffects(character, true)
		self:HideAuraEffects(character, true)
	end

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
			if not descendant:FindFirstAncestorOfClass("Tool") and (FeatureManager:GetFeatureState("effects") or FeatureManager:GetFeatureState("players")) then
				Utils:HideEffect(descendant, true)
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

local MEGA_EFFECT_KEYWORDS = { "Smite", "Starfall", "BlackHole", "Nuke" }
local function matchesAny(name, keywords)
	for _, kw in ipairs(keywords) do
		if string.find(name, kw) then return true end
	end
	return false
end

function DonationEffectSystem:SetVisible(visible)
	local shouldHide = not visible
	ClientSettingsState.setDonationEffectsHidden(shouldHide)

	for _, effect in ipairs(collectionService:GetTagged("DonationEffect")) do
		if shouldHide then
			pcall(function() effect:Destroy() end)
		else
			Utils:HideBasePart(effect, false)
			for _, desc in ipairs(effect:GetDescendants()) do
				Utils:HideEffect(desc, false)
				Utils:HideLight(desc, false)
				Utils:HideBasePart(desc, false)
			end
		end
	end

	local stageEffectsFolder = workspace:FindFirstChild("StageEffects")
	if stageEffectsFolder then
		for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
			if stageFX:IsA("BasePart") then
				local sound = stageFX:FindFirstChild("HissSound")
				if sound and shouldHide then pcall(function() sound:Stop() end) end
				for _, fx in ipairs(stageFX:GetChildren()) do
					if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
						Utils:HideEffect(fx, shouldHide)
					end
				end
			end
		end
	end

	if shouldHide then
		local activeEffects = workspace:FindFirstChild("ActiveEffects")
		if activeEffects then
			for _, effect in ipairs(activeEffects:GetChildren()) do
				pcall(function() effect:Destroy() end)
			end
		end

		for _, child in ipairs(workspace:GetChildren()) do
			if (child:IsA("Folder") or child:IsA("Model")) and matchesAny(child.Name, MEGA_EFFECT_KEYWORDS) then
				pcall(function() child:Destroy() end)
			end
		end

		for _, snd in ipairs(workspace:GetChildren()) do
			if snd:IsA("Sound") and matchesAny(snd.Name, { "Smite", "Donation", "Starfall" }) then
				pcall(function() snd:Stop(); snd:Destroy() end)
			end
		end

		for _, lightEffect in ipairs(lighting:GetChildren()) do
			if matchesAny(lightEffect.Name, MEGA_EFFECT_KEYWORDS) then
				pcall(function() lightEffect:Destroy() end)
			end
		end

		pcall(function() game:GetService("RunService"):UnbindFromRenderStep("CameraShaker") end)
	end
end

collectionService:GetInstanceAddedSignal("DonationEffect"):Connect(function(effect)
	task.wait(0.1)
	if FeatureManager:GetFeatureState("donationeffect") or ClientSettingsState.isDonationEffectsHidden() then
		Utils:HideBasePart(effect, true)
		for _, desc in ipairs(effect:GetDescendants()) do
			Utils:HideEffect(desc, true)
			Utils:HideLight(desc, true)
			Utils:HideBasePart(desc, true)
		end
	end
end)

local stageEffectsFolder = workspace:FindFirstChild("StageEffects")
if stageEffectsFolder then
	for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
		if stageFX:IsA("BasePart") then
			local sound = stageFX:FindFirstChild("HissSound")
			if sound then
				sound:GetPropertyChangedSignal("Playing"):Connect(function()
					if ClientSettingsState.isDonationEffectsHidden() and sound.Playing then
						pcall(function() sound:Stop() end)
					end
				end)
			end
			for _, fx in ipairs(stageFX:GetChildren()) do
				if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
					fx:GetPropertyChangedSignal("Enabled"):Connect(function()
						if ClientSettingsState.isDonationEffectsHidden() and fx.Enabled then
							fx.Enabled = false
						end
					end)
				end
			end
		end
	end
end

function AdminNotifSystem:SetVisible(visible)
	local shouldHide = not visible
	ClientSettingsState.setAdminNotifHidden(shouldHide)

	if shouldHide then
		local notifGui = playerGui:FindFirstChild("MessageNotifications")
		local listFrame = notifGui and notifGui:FindFirstChild("NotificationList")
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

function DonationNotifSystem:SetVisible(visible)
	local shouldHide = not visible
	ClientSettingsState.setDonationNotifHidden(shouldHide)

	if shouldHide then
		local notifSaweriaGui = playerGui:FindFirstChild("NotifSaweriaGui")
		local notifFrame = notifSaweriaGui and notifSaweriaGui:FindFirstChild("NotifFrame")
		if notifFrame then
			notifFrame.Visible = false
			notifFrame.Position = UDim2.new(0.5, 0, -0.2, 0)
		end
		ClientState.clearDonationNotificationActive()

		local donationBoardGui = playerGui:FindFirstChild("DonationBoard")
		local dbFrame = donationBoardGui and donationBoardGui:FindFirstChild("NotificationFrame")
		if dbFrame then dbFrame.Visible = false end

		local level4Gui = playerGui:FindFirstChild("Level4Donation")
		if level4Gui then
			local container = level4Gui:FindFirstChild("CinematicContainer")
			if container then container.Visible = false end
			local skipFrame = level4Gui:FindFirstChild("SkipFrame")
			if skipFrame then skipFrame.Visible = false end
		end
	end
end

function PlayerHideSystem:HideObject(object, shouldHide)
	local hideEffect = shouldHide or FeatureManager:GetFeatureState("effects")
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
	local hideOverhead = isHidingPlayers or FeatureManager:GetFeatureState("overhead")

	for _, otherPlayer in pairs(player:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local character = otherPlayer.Character
			self:HideObject(character, isHidingPlayers)
			self:HideTools(otherPlayer, character, isHidingPlayers)
			OverheadSystem:HideOverheadGui(character, hideOverhead) 
		end
	end
end

function PlayerHideSystem:OnCharacterAdded(character, otherPlayer)
	if otherPlayer == localPlayer then return end
	task.wait(CONFIG.WAIT_FOR_ACCESSORIES)

	if FeatureManager:GetFeatureState("players") then
		self:HideObject(character, true)
		self:HideTools(otherPlayer, character, true)
		OverheadSystem:HideOverheadGui(character, true)
	end

	character.ChildAdded:Connect(function(child)
		task.wait(CONFIG.WAIT_FOR_TOOLS)
		if FeatureManager:GetFeatureState("players") and (child:IsA("Tool") or Utils:IsAura(child)) then
			self:HideObject(child, true)
		end
	end)

	self.backpackConns = self.backpackConns or {}
	if self.backpackConns[otherPlayer] then
		self.backpackConns[otherPlayer]:Disconnect()
		self.backpackConns[otherPlayer] = nil
	end
	if otherPlayer.Backpack then
		self.backpackConns[otherPlayer] = otherPlayer.Backpack.ChildAdded:Connect(function(child)
			task.wait(CONFIG.WAIT_FOR_TOOLS)
			if child:IsA("Tool") and FeatureManager:GetFeatureState("players") then
				self:HideObject(child, true)
			end
		end)
	end
end

function CameraFocusSystem:Init()
	local povFrame = containerframe:WaitForChild("POVFocusFrame", 5)
	if not povFrame then return end

	local defaultBtn = povFrame:WaitForChild("DefaultBtn", 5)
	local headBtn    = povFrame:WaitForChild("HeadBtn", 5)
	local bodyBtn    = povFrame:WaitForChild("BodyBtn", 5)

	if not defaultBtn or not headBtn or not bodyBtn then return end

	self.buttons = { DEFAULT = defaultBtn, HEAD = headBtn, BODY = bodyBtn }

	for mode, btn in pairs(self.buttons) do
		btn.MouseButton1Click:Connect(function() self:SetFocus(mode, true) end)
		btn.MouseEnter:Connect(function()
			if self.currentMode ~= mode then
				tweenservice:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(32, 32, 32) }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if self.currentMode ~= mode then
				tweenservice:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = Color3.fromRGB(22, 22, 22) }):Play()
			end
		end)
	end

	local function onChar(char)
		char:WaitForChild("Humanoid", 10)
		task.wait(0.25)
		self:ApplyCurrentFocus()
	end

	if localPlayer.Character then task.spawn(onChar, localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(onChar)

	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("CameraType"):Connect(function()
			if cam.CameraType == Enum.CameraType.Custom and self.currentMode ~= "DEFAULT" then
				task.defer(function() self:ApplyCurrentFocus() end)
			end
		end)

		cam:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			if self.isApplying or cam.CameraType ~= Enum.CameraType.Custom or self.currentMode == "DEFAULT" then return end
			local expected = self:GetTargetPart(self.currentMode, localPlayer.Character)
			if expected and cam.CameraSubject ~= expected then
				task.defer(function() self:ApplyCurrentFocus() end)
			end
		end)
	end

	self:UpdateVisuals()
end

function CameraFocusSystem:GetTargetPart(mode, char)
	if not char then return nil end
	if mode == "HEAD" then
		return char:FindFirstChild("Head")
	elseif mode == "BODY" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	end
	return char:FindFirstChildOfClass("Humanoid")
end

local lastFocusClickTime = 0
function CameraFocusSystem:SetFocus(mode, playSound)
	local now = os.clock()
	if now - lastFocusClickTime < 0.2 then return end
	lastFocusClickTime = now

	self.currentMode = mode
	self:ApplyCurrentFocus()

	if playSound then
		pcall(function()
			local clickSound = game:GetService("SoundService"):FindFirstChild("Sound")
			if clickSound then
				clickSound.TimePosition = 0
				clickSound:Play()
			end
		end)
	end
end

function CameraFocusSystem:ApplyCurrentFocus()
	local char = localPlayer.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return end

	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end

	self.isApplying = true
	local target = self:GetTargetPart(self.currentMode, char)
	cam.CameraSubject = target or hum

	if hum then hum.CameraOffset = Vector3.zero end
	self.isApplying = false
	self:UpdateVisuals()
end

function CameraFocusSystem:UpdateVisuals()
	local tweenInfo = TweenInfo.new(CONFIG.ANIMATION_DURATION, CONFIG.ANIMATION_STYLE, CONFIG.ANIMATION_DIRECTION)

	for mode, btn in pairs(self.buttons) do
		local isActive = (mode == self.currentMode)
		tweenservice:Create(btn, tweenInfo, {
			BackgroundColor3 = isActive and CONFIG.BG_COLOR_ON or Color3.fromRGB(22, 22, 22),
			TextColor3       = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180),
		}):Play()

		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then
			tweenservice:Create(stroke, tweenInfo, {
				Color = isActive and Color3.fromRGB(46, 210, 115) or Color3.fromRGB(44, 44, 44),
			}):Play()
		end
	end
end

CameraFocusSystem:Init()
for _, featureConfig in ipairs(FEATURES) do
	FeatureManager:RegisterFeature(featureConfig)
end

local otherPlayerCharConns = {}

local function monitorOtherPlayer(otherPlayer)
	if otherPlayerCharConns[otherPlayer] then
		otherPlayerCharConns[otherPlayer]:Disconnect()
	end
	otherPlayerCharConns[otherPlayer] = otherPlayer.CharacterAdded:Connect(function(character)
		FeatureManager:OnCharacterAdded(character, otherPlayer)
	end)
	if otherPlayer.Character then
		task.spawn(function()
			FeatureManager:OnCharacterAdded(otherPlayer.Character, otherPlayer)
		end)
	end
end

for _, otherPlayer in ipairs(player:GetPlayers()) do monitorOtherPlayer(otherPlayer) end
player.PlayerAdded:Connect(monitorOtherPlayer)

player.PlayerRemoving:Connect(function(leavingPlayer)
	if otherPlayerCharConns[leavingPlayer] then
		otherPlayerCharConns[leavingPlayer]:Disconnect()
		otherPlayerCharConns[leavingPlayer] = nil
	end
	if PlayerHideSystem.backpackConns and PlayerHideSystem.backpackConns[leavingPlayer] then
		PlayerHideSystem.backpackConns[leavingPlayer]:Disconnect()
		PlayerHideSystem.backpackConns[leavingPlayer] = nil
	end
end)

local userSettings = UserSettings():GetService("UserGameSettings")
local isUpdatingQuality = false
local function onGraphicsQualityChanged()
	if isUpdatingQuality then return end
	isUpdatingQuality = true

	task.defer(function()
		pcall(function()
			local quality = userSettings.SavedQualityLevel
			local qualityValue = quality and quality.Value or 0
			if qualityValue > 0 then
				local isLow = qualityValue <= 4
				FeatureManager:SetFeature("effects", isLow)
				FeatureManager:SetFeature("shadow", isLow)
			end
		end)
		isUpdatingQuality = false
	end)
end

userSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(onGraphicsQualityChanged)
task.defer(onGraphicsQualityChanged)
