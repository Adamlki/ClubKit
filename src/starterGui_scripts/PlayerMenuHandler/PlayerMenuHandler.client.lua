-- ============================================
-- PlayerMenuHandler (Client) - SCROLLABLE CARD VERSION
-- ============================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local StarterGui        = game:GetService("StarterGui")

local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

-- ============================================
-- CONSTANTS
-- ============================================
local RAYCAST_DISTANCE         = 500
local MAX_INTERACTION_DISTANCE = 500
local CLICK_COOLDOWN           = 0.2
local DEFAULT_BIO              = "This user has no bio."
local DEFAULT_COMMUNITY_IMAGE  = "http://www.roblox.com/asset/?id=100615948228188" -- DMS STUDIO default

local ICON_EYE_OPEN   = "rbxassetid://6031075931"
local ICON_EYE_CLOSED = "rbxassetid://6031075929"

-- ============================================
-- REMOTES & MODULES
-- ============================================
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local startSyncRE = remotes:WaitForChild("startSync")
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

-- Remotes untuk Like & Info
local LikePlayerRemote        = remotes:WaitForChild("LikePlayer", 5)
local CheckLikeCooldownRemote = remotes:WaitForChild("CheckLikeCooldown", 5)
local getPlayerInfoRF         = remotes:WaitForChild("GetPlayerInfo", 5)

-- ============================================
-- GUI ELEMENTS (Safe Resolution)
-- ============================================
local gui       = script.Parent
local mainframe = gui:WaitForChild("MainFrame")

local commBg   = mainframe:WaitForChild("CommunityBackground")
local darkTint = mainframe:WaitForChild("DarkTint")
local plastic  = mainframe:FindFirstChild("PlasticOverlay") or mainframe:WaitForChild("PlasticOverlay", 2)

local topBar   = mainframe:WaitForChild("TopBar")
local eyeBtn   = topBar:WaitForChild("EyeBtn")
local closeBtn = topBar:WaitForChild("CloseBtn")

local scroll = mainframe:WaitForChild("ScrollContainer")

-- Section 1: Profile (Top)
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

-- Section 2: Actions & Bio (Scrolled Down)
local actionsSection = scroll:WaitForChild("ActionsSection")
local bioRow         = actionsSection:WaitForChild("BioRow")
local bioLabel       = bioRow:WaitForChild("BioLabel")
local buttonsFrame   = actionsSection:WaitForChild("ButtonsFrame")
local carryBtn       = buttonsFrame:WaitForChild("CarryBtn")
local syncBtn        = buttonsFrame:WaitForChild("SyncBtn")
local friendBtn      = buttonsFrame:WaitForChild("FriendBtn")
local whisperBtn     = buttonsFrame:WaitForChild("WhisperBtn")
local hideBtn        = buttonsFrame:WaitForChild("HideBtn")

-- ============================================
-- STATE
-- ============================================
local currentTargetPlayer = nil
local lastClickTime       = 0
local isLiking            = false
local currentCooldownEnd  = 0
local hiddenPlayers       = {}
local isSyncing           = false

-- Local Session Cache agar request ke server cuma 1x (Anti-429 & Anti-Lag)
local ClientProfileCache = {}

-- ============================================
-- SOUND HELPER
-- ============================================
local function playClickSound()
	local sounds = ReplicatedStorage:FindFirstChild("Sounds")
	if not sounds then return end
	local s = sounds:FindFirstChild("minimal-pop-click-ui")
	if s then s:Play() end
end

-- ============================================
-- NUMBER & TIME FORMATTERS
-- ============================================
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
	local hours = math.floor(seconds / 3600)
	local mins  = math.floor((seconds % 3600) / 60)
	local secs  = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- ============================================
-- MENU OPEN / CLOSE
-- ============================================
local function closeMenu()
	currentTargetPlayer = nil
	mainframe.Visible   = false
	playClickSound()
end

closeBtn.MouseButton1Click:Connect(closeMenu)

-- ============================================
-- TOMBOL MATA: HANYA UNTUK HIDE/SHOW GUI DEPAN
-- Biar bisa lihat frame belakangnya (Community Background Photo)
-- ============================================
eyeBtn.MouseButton1Click:Connect(function()
	playClickSound()
	if scroll.Visible then
		scroll.Visible = false
		eyeBtn.Image   = ICON_EYE_CLOSED
	else
		scroll.Visible = true
		eyeBtn.Image   = ICON_EYE_OPEN
	end
end)

-- ============================================
-- HIDE PLAYER AVATAR UTILS
-- ============================================
local function toggleHidePlayer(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return false end
	local shouldHide = not hiddenPlayers[targetPlayer]
	hiddenPlayers[targetPlayer] = shouldHide

	for _, desc in ipairs(targetPlayer.Character:GetDescendants()) do
		if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("Decal") then
			desc.LocalTransparencyModifier = shouldHide and 1 or 0
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") or desc:IsA("Trail") then
			desc.Enabled = not shouldHide
		elseif desc:IsA("BillboardGui") then
			desc.Enabled = not shouldHide
		end
	end

	hideBtn.Text = shouldHide and "Show Avatar" or "Hide Avatar"
	return shouldHide
end

-- ============================================
-- ACTION BUTTON BINDINGS
-- ============================================

-- 1. Carry Button -> Buka Carry UI (Screenshot 4)
carryBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	local myHRP = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local targetHRP = currentTargetPlayer.Character and currentTargetPlayer.Character:FindFirstChild("HumanoidRootPart")

	if not myHRP or not targetHRP then closeMenu() return end
	if (myHRP.Position - targetHRP.Position).Magnitude > CarryConfig.MAX_DISTANCE then
		closeMenu()
		return
	end

	local carryEvents = ReplicatedStorage:FindFirstChild("CarryEvents")
		or (function()
			local f = Instance.new("Folder")
			f.Name = "CarryEvents"
			f.Parent = ReplicatedStorage
			return f
		end)()

	local showStyleUI = carryEvents:FindFirstChild("ShowStyleUI")
		or (function()
			local e = Instance.new("BindableEvent")
			e.Name = "ShowStyleUI"
			e.Parent = carryEvents
			return e
		end)()

	pcall(function() showStyleUI:Fire(currentTargetPlayer) end)
	closeMenu()
end)

-- 2. Sync Dance
syncBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	local syncTarget = localPlayer.Character and localPlayer.Character:GetAttribute("Syncing")
	local targetName = currentTargetPlayer.Name

	if isSyncing and syncTarget == targetName then
		startSyncRE:FireServer(currentTargetPlayer, false)
	else
		startSyncRE:FireServer(currentTargetPlayer, true)
	end

	playClickSound()
	closeMenu()
end)

-- 3. Friend
friendBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	pcall(function() localPlayer:RequestFriendship(currentTargetPlayer) end)
	playClickSound()
	closeMenu()
end)

-- 4. Private Chat
whisperBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	local textChannels = TextChatService:FindFirstChild("TextChannels")
	local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
	if generalChannel then
		pcall(function()
			generalChannel:SendAsync("/w " .. currentTargetPlayer.DisplayName .. " ")
		end)
	end
	playClickSound()
	closeMenu()
end)

-- 5. Hide Avatar
hideBtn.MouseButton1Click:Connect(function()
	if not currentTargetPlayer then return end
	toggleHidePlayer(currentTargetPlayer)
	playClickSound()
end)

-- ============================================
-- LIKE SYSTEM
-- ============================================
likeBtn.MouseButton1Click:Connect(function()
	if isLiking or not currentTargetPlayer then return end
	if currentCooldownEnd > os.time() then return end

	isLiking = true
	heartIcon.ImageColor3 = Color3.fromRGB(255, 60, 80)
	playClickSound()

	-- Bounce animation pada HeartIcon
	local origSize = heartIcon.Size
	local shrink = TweenService:Create(heartIcon, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {
		Size = UDim2.new(origSize.X.Scale * 0.8, origSize.X.Offset, origSize.Y.Scale * 0.8, origSize.Y.Offset)
	})
	shrink:Play()
	shrink.Completed:Once(function()
		TweenService:Create(heartIcon, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), { Size = origSize }):Play()
	end)

	if LikePlayerRemote then
		local success, result = pcall(function()
			return LikePlayerRemote:InvokeServer(currentTargetPlayer.UserId)
		end)
		if success and result and currentTargetPlayer then
			currentCooldownEnd = result
			cooldownLabel.Visible = true
		end
	end
	isLiking = false
end)

RunService.Heartbeat:Connect(function()
	if currentTargetPlayer and cooldownLabel.Visible then
		local remaining = currentCooldownEnd - os.time()
		if remaining > 0 then
			cooldownLabel.Text = formatTime(remaining)
		else
			cooldownLabel.Visible = false
			heartIcon.ImageColor3 = Color3.fromRGB(255, 55, 75)
		end
	end
end)

-- ============================================
-- LOAD & DISPLAY PLAYER DATA (CUMA 1X REQUEST PER SESSION)
-- ============================================
local function updateTargetData(targetPlayer)
	displayNameLabel.Text = targetPlayer.DisplayName
	usernameLabel.Text    = "@" .. targetPlayer.Name

	-- Full avatar render
	avatarDisplay.Image = "rbxthumb://type=Avatar&id=" .. targetPlayer.UserId .. "&w=720&h=720"

	-- Likes
	local currentLikes = targetPlayer:GetAttribute("TotalLikes") or 0
	likeCountLabel.Text = formatNumber(currentLikes) .. " Likes"

	-- Status hide button
	local isHidden = hiddenPlayers[targetPlayer] == true
	hideBtn.Text = isHidden and "Show Avatar" or "Hide Avatar"

	-- Status sync dance button
	local syncTarget = localPlayer.Character and localPlayer.Character:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		isSyncing = true
		syncBtn.Text = (syncTarget == targetPlayer.Name) and "Unsync Dance" or "Switch Dance"
	else
		isSyncing = false
		syncBtn.Text = "Sync Dance"
	end

	-- Cek apakah data profil sudah pernah di-fetch di session ini
	local cached = ClientProfileCache[targetPlayer.UserId]
	if cached then
		-- Langsung pakai cache dari memori (0 request ke server)
		bioLabel.Text = (cached.description ~= "" and cached.description) or DEFAULT_BIO
		socialStatsLabel.Text = string.format("%s Connections • %s Followers • %s Following",
			formatNumber(cached.friendsCount or 0),
			formatNumber(cached.followersCount or 0),
			formatNumber(cached.followingCount or 0)
		)
		if cached.primaryGroup and cached.primaryGroup.emblem then
			commBg.Image = cached.primaryGroup.emblem
		end
		return
	end

	-- Jika belum ada di cache, beri nilai default & fetch HANYA SEKALI di background
	bioLabel.Text         = DEFAULT_BIO
	socialStatsLabel.Text = "0 Connections • 0 Followers • 0 Following"
	commBg.Image          = DEFAULT_COMMUNITY_IMAGE

	task.spawn(function()
		if not getPlayerInfoRF then return end

		local ok, data = pcall(function()
			return getPlayerInfoRF:InvokeServer(targetPlayer.UserId)
		end)

		if ok and data then
			ClientProfileCache[targetPlayer.UserId] = data

			if currentTargetPlayer == targetPlayer then
				bioLabel.Text = (data.description ~= "" and data.description) or DEFAULT_BIO
				socialStatsLabel.Text = string.format("%s Connections • %s Followers • %s Following",
					formatNumber(data.friendsCount or 0),
					formatNumber(data.followersCount or 0),
					formatNumber(data.followingCount or 0)
				)
				if data.primaryGroup and data.primaryGroup.emblem then
					commBg.Image = data.primaryGroup.emblem
				end
			end
		else
			-- Jika gagal / roproxy timeout, simpan fallback agar tidak mengulang request
			local fallback = {
				description = DEFAULT_BIO,
				friendsCount = 0,
				followersCount = 0,
				followingCount = 0,
				primaryGroup = { emblem = DEFAULT_COMMUNITY_IMAGE }
			}
			ClientProfileCache[targetPlayer.UserId] = fallback
		end
	end)

	-- Check like cooldown
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

-- ============================================
-- RAYCAST FROM SCREEN (KLIK PEMAIN DI DUNIA 3D)
-- ============================================
-- ============================================
-- SMART TARGET DETECTION (OPTIMAL UNTUK HP / MOBILE & PC)
-- ============================================
local function getPlayerFromHit(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			local p = Players:GetPlayerFromCharacter(current)
			if p and p ~= localPlayer then
				return p
			end
		end
		current = current.Parent
	end
	return nil
end

-- 1. Direct Include-Only Raycast: Hanya mendeteksi karakter pemain lain
-- Mengabaikan 100% part transparan, zona VIP, stage FX, dan part tak terlihat!
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
	if result and result.Instance then
		return getPlayerFromHit(result.Instance)
	end
	return nil
end

-- 2. Screen Proximity Search: Toleransi sentuhan jari di layar HP
-- Jika tap meleset sedikit dari badan (radius 60 pixel di sekitar pemain), tetap terdeteksi!
local function findNearbyPlayerOnScreen(screenPosition, maxScreenRadius)
	local radius = maxScreenRadius or 48 -- Toleransi 60 pixel di layar HP
	local tapPos = Vector2.new(screenPosition.X, screenPosition.Y)
	local bestPlayer = nil
	local closestDist = radius

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p.Character then
			local root = p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart
			if root then
				local points = {
					root.Position,
					root.Position + Vector3.new(0, 1.6, 0), -- Kepala / bahu
					root.Position - Vector3.new(0, 1.4, 0), -- Kaki
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

-- Gabungan: Cek raycast presisi dulu, jika meleset (khas jari HP), gunakan toleransi layar!
local function getTargetPlayerAtScreen(screenPosition)
	local target = raycastToPlayers(screenPosition)
	if target then
		return target
	end
	return findNearbyPlayerOnScreen(screenPosition, 48)
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
	
	-- Reset scroll position selalu ke paling atas (Screenshot 1)
	scroll.CanvasPosition = Vector2.new(0, 0)
	scroll.Visible        = true
	eyeBtn.Image          = ICON_EYE_OPEN
	
	updateTargetData(targetPlayer)
	mainframe.Visible = true
	playClickSound()
end

local function isPointInsideFrame(frame, point)
	local pos  = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

-- ============================================
-- TAP VS SWIPE / DRAG DISCRIMINATOR (ANTI KESENTUH SAAT GESER KAMERA)
-- ============================================
-- Membedakan antara sentuhan klik (TAP) dengan usapan memutar kamera (DRAG/SWIPE).
-- Jika jari bergeser > 14 pixel atau ditahan > 0.35 detik, sistem menganggapnya
-- sebagai memutar kamera atau balik badan, sehingga menu TIDAK AKAN terbuka!
local activeTouches = {}
local MAX_TAP_MOVEMENT = 14   -- pixel maksimal jari boleh bergeser agar dianggap tap
local MAX_TAP_DURATION = 0.35 -- detik maksimal sentuhan dianggap tap cepat

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

	if not touchData then return end
	if gameProcessedEvent then return end

	local currentPos = Vector2.new(inputObject.Position.X, inputObject.Position.Y)
	local moveDistance = (currentPos - touchData.startPos).Magnitude
	local touchDuration = os.clock() - touchData.startTime

	-- 🛡️ Jari bergeser memutar kamera atau ditahan -> ABAIKAN TOTAL (Bukan Tap)
	if moveDistance > MAX_TAP_MOVEMENT or touchDuration > MAX_TAP_DURATION then
		return
	end

	local now = os.clock()
	if now - lastClickTime < CLICK_COOLDOWN then return end

	local pos = inputObject.Position
	if mainframe.Visible and isPointInsideFrame(mainframe, pos) then
		return
	end

	if mainframe.Visible then
		closeMenu()
		return
	end

	-- Cek target player hanya jika sentuhan adalah TAP MURNI
	local target = getTargetPlayerAtScreen(pos)
	if target then
		local inRange, dist = isPlayerInRange(target, MAX_INTERACTION_DISTANCE)
		if inRange then
			lastClickTime = now
			openForPlayer(target)
		end
	end
end)

Players.PlayerAdded:Connect(function(p)
	p:GetAttributeChangedSignal("TotalLikes"):Connect(function()
		if currentTargetPlayer == p then
			likeCountLabel.Text = formatNumber(p:GetAttribute("TotalLikes") or 0) .. " Likes"
		end
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p:GetAttributeChangedSignal("TotalLikes"):Connect(function()
		if currentTargetPlayer == p then
			likeCountLabel.Text = formatNumber(p:GetAttribute("TotalLikes") or 0) .. " Likes"
		end
	end)
end

Players.PlayerRemoving:Connect(function(p)
	hiddenPlayers[p] = nil
	ClientProfileCache[p.UserId] = nil
	if currentTargetPlayer == p then
		closeMenu()
	end
end)

-- Initialize
mainframe.Visible = false
scroll.CanvasPosition = Vector2.new(0, 0)
