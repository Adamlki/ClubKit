--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- ⚙️ KONFIGURASI KAMERA 360
-- ==========================================
local Config = {
	CameraDistance = 20,   -- Jarak kamera dari kepala
	CameraSpeed = 0.5,     -- Kecepatan putaran
}

local GlobalEffectRemotes = ReplicatedStorage:WaitForChild("GlobalEffectRemotes")
local ToggleEffectEvent = GlobalEffectRemotes:WaitForChild("ToggleEffect")
local CameraEffectEvent = GlobalEffectRemotes:WaitForChild("CameraEffect")
local CheckOwnerFunction = GlobalEffectRemotes:WaitForChild("CheckOwner")
local NotificationEvent = GlobalEffectRemotes:WaitForChild("NotificationEvent")

local StarterGui = game:GetService("StarterGui")

NotificationEvent.OnClientEvent:Connect(function(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title;
		Text = text;
		Duration = duration or 5;
	})
end)

local GlobalEffectGui = PlayerGui:WaitForChild("GlobalEffectGui", 10)

-- Cek Kepemilikan
local isOwner = false
if GlobalEffectGui then
	isOwner = CheckOwnerFunction:InvokeServer()
	
	local MainFrame = GlobalEffectGui:WaitForChild("MainFrame")
	local NotifikasiFrame = GlobalEffectGui:WaitForChild("NotifikasiFrame")
	
	local ToggleNotificationEvent = GlobalEffectRemotes:WaitForChild("ToggleNotification")
	local ToggleFollowEvent = GlobalEffectRemotes:WaitForChild("ToggleFollow")
	
	local isFollowing = true
	local FollowBtn = NotifikasiFrame:WaitForChild("FollowBtn")
	local FollowBtnText = FollowBtn:WaitForChild("TextLabel")
	
	NotifikasiFrame.Visible = false
	
	FollowBtn.MouseButton1Click:Connect(function()
		isFollowing = not isFollowing
		if isFollowing then
			FollowBtnText.Text = "Unfollow"
		else
			FollowBtnText.Text = "Follow"
		end
		ToggleFollowEvent:FireServer(isFollowing)
	end)
	
	ToggleNotificationEvent.OnClientEvent:Connect(function(show)
		if show then
			isFollowing = true
			FollowBtnText.Text = "Unfollow"
			NotifikasiFrame.Visible = true
		else
			NotifikasiFrame.Visible = false
		end
	end)

	if not isOwner then
		MainFrame:Destroy()
	else
		local BtnFrame = MainFrame:WaitForChild("BtnFrame")
		
		local Btn360 = BtnFrame:WaitForChild("360Btn")
		local BtnFloating = BtnFrame:WaitForChild("FloatingBtn")
		local BtnFly = BtnFrame:WaitForChild("FlyBtn")
		local BtnWing = BtnFrame:WaitForChild("WingBtn")
		local BtnClear = MainFrame:WaitForChild("ClearBtn")
		
		local COLOR_ACTIVE = Color3.fromRGB(0, 255, 0)
		local COLOR_DEFAULT = Color3.fromRGB(255, 255, 255)
		
		local ButtonStates = {
			Camera360 = false,
			Floating = false,
			Fly = false,
			Wing = false
		}
		
		MainFrame.Visible = false
		
		local function updateButtonUI(btnName, isActive)
			local btnObj
			if btnName == "Camera360" then btnObj = Btn360
			elseif btnName == "Floating" then btnObj = BtnFloating
			elseif btnName == "Fly" then btnObj = BtnFly
			elseif btnName == "Wing" then btnObj = BtnWing
			end
			
			if btnObj then
				local imageLabel = btnObj:FindFirstChild("ImageLabel")
				if imageLabel then
					imageLabel.ImageColor3 = isActive and COLOR_ACTIVE or COLOR_DEFAULT
				end
			end
		end

		local lastClickTime = 0
		local CLICK_DEBOUNCE = 0.5
		
		local function setupButton(btnObj, stateName)
			btnObj.MouseButton1Click:Connect(function()
				-- 🔥 CLIENT FIX: Cegah UI Desync karena Rate Limiter Server
				if tick() - lastClickTime < CLICK_DEBOUNCE then return end
				lastClickTime = tick()
				
				ButtonStates[stateName] = not ButtonStates[stateName]
				updateButtonUI(stateName, ButtonStates[stateName])
				
				if stateName == "Fly" and ButtonStates["Fly"] then
					if ButtonStates["Floating"] then
						ButtonStates["Floating"] = false
						updateButtonUI("Floating", false)
					end
				elseif stateName == "Floating" and ButtonStates["Floating"] then
					if ButtonStates["Fly"] then
						ButtonStates["Fly"] = false
						updateButtonUI("Fly", false)
					end
				end
				
				ToggleEffectEvent:FireServer(stateName, ButtonStates[stateName])
			end)
		end

		setupButton(Btn360, "Camera360")
		setupButton(BtnFloating, "Floating")
		setupButton(BtnFly, "Fly")
		setupButton(BtnWing, "Wing")

		BtnClear.MouseButton1Click:Connect(function()
			for stateName, _ in pairs(ButtonStates) do
				ButtonStates[stateName] = false
				updateButtonUI(stateName, false)
			end
			ToggleEffectEvent:FireServer("ClearAll", true)
		end)
	end
end

-- ==========================================
-- CINEMATIC TRANSITION
-- ==========================================
local isTransitioning = false

local function playCinematicTransition(callback)
	if isTransitioning then return end
	isTransitioning = true
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CinematicTransitionGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.DisplayOrder = 9999
	screenGui.Parent = PlayerGui
	
	local topFrame = Instance.new("Frame")
	topFrame.Size = UDim2.new(1, 0, 0.5, 0)
	topFrame.Position = UDim2.new(0, 0, -0.5, 0)
	topFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	topFrame.BorderSizePixel = 0
	topFrame.Parent = screenGui
	
	local bottomFrame = Instance.new("Frame")
	bottomFrame.Size = UDim2.new(1, 0, 0.5, 0)
	bottomFrame.Position = UDim2.new(0, 0, 1, 0)
	bottomFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	bottomFrame.BorderSizePixel = 0
	bottomFrame.Parent = screenGui
	
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	
	-- Nutup layar (Menuju tengah)
	local topTweenIn = TweenService:Create(topFrame, tweenInfo, {Position = UDim2.new(0, 0, 0, 0)})
	local bottomTweenIn = TweenService:Create(bottomFrame, tweenInfo, {Position = UDim2.new(0, 0, 0.5, 0)})
	
	topTweenIn:Play()
	bottomTweenIn:Play()
	
	topTweenIn.Completed:Wait()
	
	-- Ganti kamera saat layar tertutup hitam pekat
	if callback then callback() end
	task.wait(0.2) -- Jeda sebentar agar pergantian terasa smooth
	
	-- Buka layar kembali
	local topTweenOut = TweenService:Create(topFrame, tweenInfo, {Position = UDim2.new(0, 0, -0.5, 0)})
	local bottomTweenOut = TweenService:Create(bottomFrame, tweenInfo, {Position = UDim2.new(0, 0, 1, 0)})
	
	topTweenOut:Play()
	bottomTweenOut:Play()
	
	topTweenOut.Completed:Wait()
	screenGui:Destroy()
	
	isTransitioning = false
end

-- ==========================================
-- 360 CAMERA EFFECT
-- ==========================================
local Camera = Workspace.CurrentCamera
local CameraConnection = nil
local CameraAngle = 0

local function start360Camera()
	if CameraConnection then return end
	
	Camera.CameraType = Enum.CameraType.Scriptable
	
	CameraConnection = RunService.RenderStepped:Connect(function(dt)
		local character = LocalPlayer.Character
		if not character then return end
		local head = character:FindFirstChild("Head")
		if not head then return end
		
		CameraAngle = CameraAngle + (Config.CameraSpeed * dt)
		
		local offsetX = math.sin(CameraAngle) * Config.CameraDistance
		local offsetZ = math.cos(CameraAngle) * Config.CameraDistance
		
		local targetPosition = head.Position + Vector3.new(offsetX, 2, offsetZ)
		Camera.CFrame = CFrame.lookAt(targetPosition, head.Position)
	end)
end

local function stop360Camera()
	if CameraConnection then
		CameraConnection:Disconnect()
		CameraConnection = nil
	end
	
	Camera.CameraType = Enum.CameraType.Custom
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	
	-- Memaksa kamera kembali ke karakter agar tidak nyangkut di atas
	if LocalPlayer.Character then
		local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Camera.CameraSubject = humanoid
		end
	end
end

-- Listener dari Server (Bisa didengar oleh semua player termasuk non-owner)
CameraEffectEvent.OnClientEvent:Connect(function(isActive)
	playCinematicTransition(function()
		if isActive then
			start360Camera()
		else
			stop360Camera()
		end
	end)
end)

-- ==========================================
-- CLIENT-SIDE ANIMATION LOCK FOR GLOBAL EFFECT
-- ==========================================
local FLY_ANIM_ID = "81229486815853"
local FLOAT_ANIM_ID = "112082806790047"

local suspendedTimePosition = 0
local suspendedDanceID = nil
local resumedDanceTrack = nil
local EmoteNumericIds = nil

local function getNumericId(id)
	if not id then return "" end
	return string.match(tostring(id), "%d+") or ""
end

-- Membangun cache tarian/pose dari folder Emotes di ReplicatedStorage secara dinamis
local function buildEmoteCache()
	local folder = ReplicatedStorage:FindFirstChild("Emotes")
	if not folder then return end
	
	EmoteNumericIds = {}
	for _, anim in ipairs(folder:GetDescendants()) do
		if anim:IsA("Animation") then
			local numId = getNumericId(anim.AnimationId)
			if numId ~= "" then
				EmoteNumericIds[numId] = true
			end
		end
	end
end

local function isRegisteredDanceOrPose(animationId)
	if not EmoteNumericIds then
		buildEmoteCache()
	end
	if not EmoteNumericIds then return false end
	
	local numericId = getNumericId(animationId)
	return EmoteNumericIds[numericId] == true
end

local function stopAllExceptGlobalEffects()
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation then
			local numId = getNumericId(track.Animation.AnimationId)
			if numId ~= "" and numId ~= FLY_ANIM_ID and numId ~= FLOAT_ANIM_ID then
				-- Hanya hentikan jika ini adalah tarian/pose resmi dari database
				if isRegisteredDanceOrPose(track.Animation.AnimationId) then
					-- Simpan posisi waktu untuk tarian yang aktif
					local currentDanceID = char:GetAttribute("CurrentDanceID")
					
					-- Cek apakah player adalah follower
					local syncTarget = char:GetAttribute("Syncing")
					if syncTarget and syncTarget ~= "" then
						local leaderPlayer = Players:FindFirstChild(syncTarget)
						if leaderPlayer and leaderPlayer.Character then
							currentDanceID = leaderPlayer.Character:GetAttribute("CurrentDanceID")
						end
					end

					if currentDanceID and getNumericId(currentDanceID) == numId then
						suspendedTimePosition = track.TimePosition
						suspendedDanceID = currentDanceID
					end
					
					track:Stop(0.1)
				end
			end
		end
	end
end

local function findEmoteAnimationInstance(currentDanceID)
	local folder = ReplicatedStorage:FindFirstChild("Emotes")
	if not folder then return nil end
	
	local targetNumeric = getNumericId(currentDanceID)
	if targetNumeric == "" then return nil end
	
	for _, anim in ipairs(folder:GetDescendants()) do
		if anim:IsA("Animation") then
			if getNumericId(anim.AnimationId) == targetNumeric then
				return anim
			end
		end
	end
	return nil
end

local function resumeLocalDance()
	local char = LocalPlayer.Character
	if not char then return end
	local currentDanceID = char:GetAttribute("CurrentDanceID")
	local speed = char:GetAttribute("DanceSpeed") or 1
	
	-- Cek apakah player adalah follower
	local syncTarget = char:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		local leaderPlayer = Players:FindFirstChild(syncTarget)
		if leaderPlayer and leaderPlayer.Character then
			currentDanceID = leaderPlayer.Character:GetAttribute("CurrentDanceID")
			speed = leaderPlayer.Character:GetAttribute("DanceSpeed") or speed
		end
	end
	
	if not currentDanceID or currentDanceID == "" then return end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	
	-- Cari objek Animation asli dari ReplicatedStorage agar namanya sesuai (misal "Spongebob")
	-- dan dapat dideteksi serta dihentikan oleh menu tarian client saat "Stop Dance"
	local anim = findEmoteAnimationInstance(currentDanceID)
	local isTempAnim = false
	if not anim then
		-- Fallback jika tidak ditemukan
		anim = Instance.new("Animation")
		anim.AnimationId = currentDanceID
		isTempAnim = true
	end
	
	if resumedDanceTrack then
		resumedDanceTrack:Stop(0.1)
		resumedDanceTrack:Destroy()
		resumedDanceTrack = nil
	end
	
	-- Stop any leftover high-priority tracks
	stopAllExceptGlobalEffects()
	
	local track = animator:LoadAnimation(anim)
	if isTempAnim then anim:Destroy() end -- FIX: Cegah memori HP/PC pemain bocor
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	
	track:Play(0.2, 1, speed)
	resumedDanceTrack = track
	
	if suspendedTimePosition > 0 and suspendedDanceID == currentDanceID then
		pcall(function()
			track.TimePosition = suspendedTimePosition
		end)
	end
	suspendedTimePosition = 0
	suspendedDanceID = nil
end

local function onGlobalEffectActiveChanged()
	local char = LocalPlayer.Character
	if not char then return end
	local isActive = char:GetAttribute("GlobalEffectActive")
	if isActive == true then
		stopAllExceptGlobalEffects()
	else
		-- Resume tarian lokal yang tertunda (jika ada)
		resumeLocalDance()
	end
end

local function onAnimationPlayed(track)
	local char = LocalPlayer.Character
	if not char then return end
	if char:GetAttribute("GlobalEffectActive") == true then
		local numId = getNumericId(track.Animation.AnimationId)
		if numId ~= "" and numId ~= FLY_ANIM_ID and numId ~= FLOAT_ANIM_ID then
			-- Blokir tarian/pose baru jika terdaftar di database
			if isRegisteredDanceOrPose(track.Animation.AnimationId) then
				track:Stop(0)
			end
		end
	end
end

local function setupCharacterListener(char)
	suspendedTimePosition = 0
	suspendedDanceID = nil
	resumedDanceTrack = nil

	local humanoid = char:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if animator then
		animator.AnimationPlayed:Connect(onAnimationPlayed)
	end
	
	char:GetAttributeChangedSignal("GlobalEffectActive"):Connect(onGlobalEffectActiveChanged)
	
	char:GetAttributeChangedSignal("CurrentDanceID"):Connect(function()
		if resumedDanceTrack then
			resumedDanceTrack:Stop(0.1)
			resumedDanceTrack = nil
		end
	end)
	
	onGlobalEffectActiveChanged()
end

if LocalPlayer.Character then
	task.spawn(setupCharacterListener, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(setupCharacterListener, char)
end)
