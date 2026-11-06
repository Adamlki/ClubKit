local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetConfig       = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))
local TextChatService   = game:GetService("TextChatService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local RAYCAST_DISTANCE         = 500
local MAX_INTERACTION_DISTANCE = 500
local CLICK_COOLDOWN           = 0.2
local DEFAULT_BIO              = "This user has no bio."
local DEFAULT_COMMUNITY_IMAGE  = string.format("http://www.roblox.com/asset/?id=%d", AssetConfig.Images.DefaultCommunityId)

local ICON_EYE_OPEN   = AssetConfig.Images.ProfileEyeOpen
local ICON_EYE_CLOSED = AssetConfig.Images.ProfileEyeClosed

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startSyncRE = remotes:WaitForChild("startSync")
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

local LikePlayerRemote        = remotes:WaitForChild("LikePlayer", 5)
local CheckLikeCooldownRemote = remotes:WaitForChild("CheckLikeCooldown", 5)
local getPlayerInfoRF         = remotes:WaitForChild("GetPlayerInfo", 5)

local carryEvents = ReplicatedStorage:FindFirstChild("CarryEvents")
if not carryEvents then
	carryEvents = Instance.new("Folder")
	carryEvents.Name = "CarryEvents"
	carryEvents.Parent = ReplicatedStorage
end
local showStyleUI = carryEvents:FindFirstChild("ShowStyleUI")
if not showStyleUI then
	showStyleUI = Instance.new("BindableEvent")
	showStyleUI.Name = "ShowStyleUI"
	showStyleUI.Parent = carryEvents
end

local gui       = script.Parent
local mainframe = gui:WaitForChild("MainFrame")

local commBg   = mainframe:WaitForChild("CommunityBackground")
local darkTint = mainframe:WaitForChild("DarkTint")
local plastic  = mainframe:FindFirstChild("PlasticOverlay") or mainframe:WaitForChild("PlasticOverlay", 2)

local topBar   = mainframe:WaitForChild("TopBar")
local eyeBtn   = topBar:WaitForChild("EyeBtn")
local closeBtn = topBar:WaitForChild("CloseBtn")

local scroll = mainframe:WaitForChild("ScrollContainer")

scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local profileSection   = scroll:WaitForChild("ProfileSection")
local avatarDisplay    = profileSection:WaitForChild("AvatarDisplay")
local bottomInfo       = profileSection:WaitForChild("BottomInfoFrame")
local nameRow          = bottomInfo:WaitForChild("NameRow")
local displayNameLabel = nameRow:WaitForChild("DisplayName")
local likeBtn          = nameRow:WaitForChild("LikeBtn")
local heartIcon        = likeBtn:WaitForChild("HeartIcon")
local likeCountLabel   = likeBtn:WaitForChild("LikeCount")
local cooldownLabel    = likeBtn:WaitForChild("CooldownLabel")
local usernameLabel    = bottomInfo:WaitForChild("UsernameLabel")
local socialStatsLabel = bottomInfo:WaitForChild("SocialStatsLabel")

local actionsSection = scroll:WaitForChild("ActionsSection")
local bioRow         = actionsSection:WaitForChild("BioRow")
local bioLabel       = bioRow:WaitForChild("BioLabel")
local buttonsFrame   = actionsSection:WaitForChild("ButtonsFrame")
local carryBtn       = buttonsFrame:WaitForChild("CarryBtn")
local syncBtn        = buttonsFrame:WaitForChild("SyncBtn")
local friendBtn      = buttonsFrame:WaitForChild("FriendBtn")
local whisperBtn     = buttonsFrame:WaitForChild("WhisperBtn")
local hideBtn        = buttonsFrame:WaitForChild("HideBtn")

local currentTargetPlayer = nil
local lastClickTime       = 0
local isLiking            = false
local currentCooldownEnd  = 0
local hiddenPlayers       = {}
local isSyncing           = false

local ClientProfileCache = {}

local function playClickSound()
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	if not sounds then return end
	local s = sounds:FindFirstChild("minimal-pop-click-ui")
	if s then s:Play() end
end

local function formatNumber(n)
	local num = tonumber(n) or 0
	if num < 10000 then
		return tostring(num)
	elseif num < 1000000 then
		local val = math.floor((num / 1000) * 10) / 10
		return (val % 1 == 0) and string.format("%dk", val) or string.format("%.1fk", val)
	else
		local val = math.floor((num / 1000000) * 10) / 10
		return (val % 1 == 0) and string.format("%dM", val) or string.format("%.1fM", val)
	end
end

local function formatTime(seconds)
	if seconds <= 0 then return "00:00:00" end
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), math.floor(seconds % 60))
end

local function closeMenu()
	currentTargetPlayer = nil
	mainframe.Visible   = false
	playClickSound()
end

closeBtn.MouseButton1Click:Connect(closeMenu)

eyeBtn.MouseButton1Click:Connect(function()
	playClickSound()
	local newVisible = not scroll.Visible
	scroll.Visible = newVisible
	eyeBtn.Image = newVisible and ICON_EYE_OPEN or ICON_EYE_CLOSED
end)

local function toggleHidePlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return false end
	local shouldHide = not hiddenPlayers[targetPlayer]
	hiddenPlayers[targetPlayer] = shouldHide

	for _, desc in ipairs(targetPlayer.Character:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("Decal") then
			desc.LocalTransparencyModifier = shouldHide and 1 or 0
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") or desc:IsA("BillboardGui") then
			desc.Enabled = not shouldHide
		end
	end

	hideBtn.Text = shouldHide and "Show Avatar" or "Hide Avatar"
	return shouldHide
end

carryBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	local myHRP = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetHRP = currentTargetPlayer.Character and currentTargetPlayer.Character:FindFirstChild("HumanoidRootPart")

	if not myHRP or not targetHRP or (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		closeMenu()
		return
	end

	pcall(function() showStyleUI:Fire(currentTargetPlayer) end)
	closeMenu()
end)

syncBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	local syncTarget = localPlayer.Character and localPlayer.Character:GetAttribute("Syncing")
	startSyncRE:FireServer(currentTargetPlayer, not (isSyncing and syncTarget == currentTargetPlayer.Name))
	playClickSound()
	closeMenu()
end)

friendBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	pcall(function() localPlayer:RequestFriendship(currentTargetPlayer) end)
	playClickSound()
	closeMenu()
end)

whisperBtn.Visible = true
whisperBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end

	local textChannels = TextChatService:FindFirstChild("TextChannels")
	local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
	if generalChannel then
		pcall(function()
			generalChannel:SendAsync("/w @" .. currentTargetPlayer.Name .. " ")
		end)
	end

	playClickSound()
	closeMenu()
end)

hideBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	toggleHidePlayer(currentTargetPlayer)
	playClickSound()
end)

task.spawn(function()
	local featureFolder = ReplicatedStorage:WaitForChild("FeatureFlags", 10)
	local giftFlag = featureFolder and featureFolder:WaitForChild("VIPGiftEnabled", 5)
	if not (giftFlag and giftFlag.Value) then return end
	if buttonsFrame:FindFirstChild("GiftBtn") then return end

	local promptGift = remotes:WaitForChild("PromptGift", 10)
	if not promptGift then return end

	local giftBtn = friendBtn:Clone()
	giftBtn.Name = "GiftBtn"
	giftBtn.Text = "Gift VIP"
	giftBtn.LayoutOrder = 5
	giftBtn.Visible = true
	giftBtn.Parent = buttonsFrame
	hideBtn.LayoutOrder = 6

	giftBtn.MouseButton1Click:Connect(function()
		if not currentTargetPlayer then return end
		if giftBtn:GetAttribute("Busy") then return end
		giftBtn:SetAttribute("Busy", true)

		pcall(function()
			promptGift:FireServer(currentTargetPlayer, "VIP")
		end)

		playClickSound()
		task.delay(2, function()
			if giftBtn.Parent then
				giftBtn:SetAttribute("Busy", false)
			end
		end)
		closeMenu()
	end)
	promptGift.OnClientEvent:Connect(function(success, message)
		if not success and message then
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "Gift VIP",
					Text = tostring(message),
					Duration = 6,
				})
			end)
		end
	end)
end)

likeBtn.MouseButton1Click:Connect(function()
	if isLiking or not currentTargetPlayer or currentCooldownEnd > os.time() then return end

	isLiking = true
	heartIcon.ImageColor3 = Color3.fromRGB(255, 60, 80)
	playClickSound()

	local origSize = heartIcon.Size
	local shrink = TweenService:Create(heartIcon, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {
		Size = UDim2.new(origSize.X.Scale * 0.8, origSize.X.Offset, origSize.Y.Scale * 0.8, origSize.Y.Offset)
	})
	shrink:Play()
	shrink.Completed:Once(function()
		TweenService:Create(heartIcon, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), { Size = origSize }):Play()
	end)

	if LikePlayerRemote then
		local ok, liked, cooldownEnd = pcall(function()
			return LikePlayerRemote:InvokeServer(currentTargetPlayer.UserId)
		end)
		if ok and liked and currentTargetPlayer then
			currentCooldownEnd = tonumber(cooldownEnd) or 0
			cooldownLabel.Visible = (currentCooldownEnd > os.time())
			likeCountLabel.Text = formatNumber(currentTargetPlayer:GetAttribute("TotalLikes") or 0) .. " Likes"
		end
	end
	isLiking = false
end)

RunService.Heartbeat:Connect(function()
	if currentTargetPlayer and cooldownLabel.Visible then
		local endTime = tonumber(currentCooldownEnd) or 0
		local remaining = endTime - os.time()
		if remaining > 0 then
			cooldownLabel.Text = formatTime(remaining)
		else
			cooldownLabel.Visible = false
			heartIcon.ImageColor3 = Color3.fromRGB(255, 55, 75)
		end
	end
end)

local function applyProfileData(data)
	bioLabel.Text = (data.description and data.description ~= "") and data.description or DEFAULT_BIO
	socialStatsLabel.Text = string.format("%s Connections • %s Followers • %s Following",
		formatNumber(data.friendsCount or 0),
		formatNumber(data.followersCount or 0),
		formatNumber(data.followingCount or 0)
	)
	if data.primaryGroup and data.primaryGroup.emblem then
		commBg.Image = data.primaryGroup.emblem
	end
end

local function updateTargetData(targetPlayer)
	displayNameLabel.Text = targetPlayer.DisplayName
	usernameLabel.Text    = "@" .. targetPlayer.Name
	avatarDisplay.Image   = "rbxthumb://type=Avatar&id=" .. targetPlayer.UserId .. "&w=720&h=720"

	local currentLikes = targetPlayer:GetAttribute("TotalLikes") or 0
	likeCountLabel.Text = formatNumber(currentLikes) .. " Likes"

	hideBtn.Text = (hiddenPlayers[targetPlayer] == true) and "Show Avatar" or "Hide Avatar"

	local syncTarget = localPlayer.Character and localPlayer.Character:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		isSyncing = true
		syncBtn.Text = (syncTarget == targetPlayer.Name) and "Unsync Dance" or "Switch Dance"
	else
		isSyncing = false
		syncBtn.Text = "Sync Dance"
	end

	local cached = ClientProfileCache[targetPlayer.UserId]
	if cached then
		applyProfileData(cached)
		return
	end

	bioLabel.Text         = DEFAULT_BIO
	socialStatsLabel.Text = "0 Connections • 0 Followers • 0 Following"
	commBg.Image          = DEFAULT_COMMUNITY_IMAGE

	task.spawn(function()
		if not getPlayerInfoRF then return end

		local ok, data = pcall(function()
			return getPlayerInfoRF:InvokeServer(targetPlayer.UserId)
		end)

		local profile = (ok and data) or {
			description = DEFAULT_BIO,
			friendsCount = 0,
			followersCount = 0,
			followingCount = 0,
			primaryGroup = { emblem = DEFAULT_COMMUNITY_IMAGE }
		}
		ClientProfileCache[targetPlayer.UserId] = profile

		if currentTargetPlayer == targetPlayer then
			applyProfileData(profile)
		end
	end)

	if CheckLikeCooldownRemote then
		task.spawn(function()
			local ok, cdData = pcall(function()
				return CheckLikeCooldownRemote:InvokeServer(targetPlayer.UserId)
			end)
			if ok and cdData and currentTargetPlayer == targetPlayer then
				currentCooldownEnd = cdData.cooldownTime or 0
				cooldownLabel.Visible = (currentCooldownEnd > os.time())
			end
		end)
	end
end

local function getPlayerFromHit(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(current)
			if p and p ~= localPlayer then return p end
		end
		current = current.Parent
	end
	return nil
end

local function raycastToPlayers(screenPosition)
	local otherCharacters = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p.Character then
			table.insert(otherCharacters, p.Character)
		end
	end
	if #otherCharacters == 0 then return nil end

	local unitRay = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params  = RaycastParams.new()
	params.FilterType                 = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = otherCharacters
	params.IgnoreWater                = true

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * RAYCAST_DISTANCE, params)
	return result and result.Instance and getPlayerFromHit(result.Instance) or nil
end

local function findNearbyPlayerOnScreen(screenPosition, maxScreenRadius)
	local radius = maxScreenRadius or 48
	local tapPos = Vector2.new(screenPosition.X, screenPosition.Y)
	local bestPlayer = nil
	local closestDist = radius

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart
			if root then
				local points = {
					root.Position,
					root.Position + Vector3.new(0, 1.6, 0),
					root.Position - Vector3.new(0, 1.4, 0),
				}
				for _, pt in ipairs(points) do
					local screenPt, onScreen = camera:WorldToViewportPoint(pt)
					if onScreen and screenPt.Z > 0 then
						local dist = (Vector2.new(screenPt.X, screenPt.Y) - tapPos).Magnitude
						if dist < closestDist then
							closestDist = dist
							bestPlayer = p
						end
					end
				end
			end
		end
	end
	return bestPlayer
end

local function getTargetPlayerAtScreen(screenPosition)
	return raycastToPlayers(screenPosition) or findNearbyPlayerOnScreen(screenPosition, 48)
end

local function isPlayerInRange(targetPlayer, maxDistance)
	local myChar     = localPlayer.Character
	local targetChar = targetPlayer.Character
	if not myChar or not targetChar then return true, 0 end

	local myHRP     = myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart or myChar:FindFirstChildWhichIsA("BasePart")
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart") or targetChar.PrimaryPart or targetChar:FindFirstChildWhichIsA("BasePart")
	if not myHRP or not targetHRP then return true, 0 end

	local distance = (myHRP.Position - targetHRP.Position).Magnitude
	return distance <= maxDistance, distance
end

local function openForPlayer(targetPlayer)
	currentTargetPlayer = targetPlayer
	scroll.CanvasPosition = Vector2.new(0, 0)
	scroll.Visible        = true
	eyeBtn.Image          = ICON_EYE_OPEN
	updateTargetData(targetPlayer)
	mainframe.Visible = true
	playClickSound()
end

local function isPointInsideFrame(frame, point)
	local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local activeTouches = {}
local MAX_TAP_MOVEMENT = 14
local MAX_TAP_DURATION = 0.35

UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
	if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if gameProcessedEvent then return end

	activeTouches[inputObject] = {
		startPos  = Vector2.new(inputObject.Position.X, inputObject.Position.Y),
		startTime = os.clock(),
	}
end)

UserInputService.InputEnded:Connect(function(inputObject, gameProcessedEvent)
	local touchData = activeTouches[inputObject]
	activeTouches[inputObject] = nil

	if not touchData or gameProcessedEvent then return end

	local currentPos = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
	local moveDistance = (currentPos - touchData.startPos).Magnitude
	local touchDuration = os.clock() - touchData.startTime

	if moveDistance > MAX_TAP_MOVEMENT or touchDuration > MAX_TAP_DURATION then return end

	local now = os.clock()
	if now - lastClickTime < CLICK_COOLDOWN then return end

	local pos = inputObject.Position
	if mainframe.Visible then
		if not isPointInsideFrame(mainframe, pos) then closeMenu() end
		return
	end

	local target = getTargetPlayerAtScreen(pos)
	if target then
		local inRange = isPlayerInRange(target, MAX_INTERACTION_DISTANCE)
		if inRange then
			lastClickTime = now
			openForPlayer(target)
		end
	end
end)

local function hookPlayerLikes(p)
	p:GetAttributeChangedSignal("TotalLikes"):Connect(function()
		if currentTargetPlayer == p then
			likeCountLabel.Text = formatNumber(p:GetAttribute("TotalLikes") or 0) .. " Likes"
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayerLikes(p) end
Players.PlayerAdded:Connect(hookPlayerLikes)

Players.PlayerRemoving:Connect(function(p)
	hiddenPlayers[p] = nil
	ClientProfileCache[p.UserId] = nil
	if currentTargetPlayer == p then
		closeMenu()
	end
end)

mainframe.Visible = false
scroll.CanvasPosition = Vector2.new(0, 0)
