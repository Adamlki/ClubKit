-- LocalScript: CinematicHandler
-- Lokasi: Di dalam ScreenGui (StarterGui)

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local CinematicRemote      = RS:WaitForChild("CinematicRemote")
local RequestDonationState = RS:WaitForChild("RequestDonationState")
local FormatUtils          = require(RS:WaitForChild("Utils"):WaitForChild("FormatUtils"))

-- ============================================================
-- REFERENSI GUI (Pastikan script ini ada di dalam ScreenGui-nya)
-- ============================================================
local donationGUI = script.Parent

-- Cinematic
local cinematicContainer = donationGUI:WaitForChild("CinematicContainer")
local topBar             = cinematicContainer:WaitForChild("TopBar")
local bottomBar          = cinematicContainer:WaitForChild("BottomBar")
local vignette           = cinematicContainer:WaitForChild("Vignette")
local impactFlash        = cinematicContainer:WaitForChild("ImpactFlash")
local mainFrame          = cinematicContainer:WaitForChild("MainFrame")
local glowCircle         = mainFrame:WaitForChild("GlowCircle")
local titleLabel         = mainFrame:WaitForChild("Title")
local titleStroke        = titleLabel:WaitForChild("TitleStroke")
local shadow1            = mainFrame:WaitForChild("Shadow1")
local shadow2            = mainFrame:WaitForChild("Shadow2")
local subtitleLabel      = mainFrame:WaitForChild("Subtitle")
local leftLine           = mainFrame:WaitForChild("LeftLine")
local rightLine          = mainFrame:WaitForChild("RightLine")

-- Skip
local skipFrame   = donationGUI:WaitForChild("SkipFrame")
local progressBar = skipFrame:WaitForChild("ProgressBg"):WaitForChild("ProgressBar")
local skipButton  = skipFrame:WaitForChild("SkipButton")

-- ============================================================
-- STATE
-- ============================================================
local isOrbiting      = false
local orbitConnection = nil
local skipRequested   = false
local originalCamType = nil

-- ============================================================
-- SOUND
-- ============================================================
local SOUND_ID = "rbxassetid://122331425639589"

local function playSound()
	local sound   = Instance.new("Sound")
	sound.SoundId = SOUND_ID
	sound.Volume  = 1
	sound.RollOffMaxDistance = 0
	sound.Parent  = workspace
	sound:Play()
	sound.Ended:Connect(function()
		if sound and sound.Parent then sound:Destroy() end
	end)
	task.delay(30, function()
		if sound and sound.Parent then sound:Destroy() end
	end)
end

-- ============================================================
-- UTILITY
-- ============================================================
local function toColor3(ct)
	if not ct then return Color3.fromRGB(255, 215, 0) end
	return Color3.fromRGB(ct.r or 255, ct.g or 215, ct.b or 0)
end

local function formatRupiah(amount)
	return FormatUtils.formatRupiah(amount)
end

local function resetCinematic()
	cinematicContainer.Visible         = false
	topBar.Size                        = UDim2.new(1, 0, 0, 0)
	topBar.Position                    = UDim2.new(0, 0, 0, 0)
	bottomBar.Size                     = UDim2.new(1, 0, 0, 0)
	bottomBar.Position                 = UDim2.new(0, 0, 1, 0)
	vignette.ImageTransparency         = 1
	impactFlash.Visible                = false
	impactFlash.BackgroundTransparency = 1
	mainFrame.Position                 = UDim2.new(0.5, 0, 1, -85)
	glowCircle.Size                    = UDim2.new(0, 0, 0, 0)
	glowCircle.BackgroundTransparency  = 0.5
	titleLabel.Size                    = UDim2.new(1, 0, 0, 60)
	titleLabel.TextSize                = 36
	titleLabel.TextTransparency        = 1
	titleLabel.Rotation                = 0
	titleStroke.Transparency           = 1
	shadow1.Size                       = UDim2.new(1, 0, 0, 60)
	shadow1.TextSize                   = 36
	shadow1.TextTransparency           = 1
	shadow1.Rotation                   = 0
	shadow2.Size                       = UDim2.new(1, 0, 0, 60)
	shadow2.TextSize                   = 36
	shadow2.TextTransparency           = 1
	shadow2.Rotation                   = 0
	subtitleLabel.TextTransparency     = 1
	leftLine.Size                      = UDim2.new(0, 0, 0, 2)
	leftLine.BackgroundTransparency    = 0
	rightLine.Size                     = UDim2.new(0, 0, 0, 2)
	rightLine.BackgroundTransparency   = 0
end

-- ============================================================
-- SKIP BUTTON LOGIC
-- ============================================================
local isHolding      = false
local isHidingSkip   = false -- 🔥 FIX 3: Pelindung Animasi Hiding
local holdElapsed    = 0
local holdRequired   = 1.2
local holdConn       = nil
local onSkipCallback = nil

local function resetSkip()
	skipFrame.Visible    = false
	skipFrame.Position   = UDim2.new(1, 20, 0.5, 0)
	progressBar.Size     = UDim2.new(0, 0, 1, 0)
	progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
end

local function showSkip(onSkip)
	onSkipCallback = onSkip
	isHidingSkip = false
	resetSkip()
	skipFrame.Visible = true
	TweenService:Create(skipFrame,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -175, 0.5, 0) }
	):Play()
end

local function hideSkip()
	if isHidingSkip then return end
	isHidingSkip = true

	if holdConn then holdConn:Disconnect() holdConn = nil end
	isHolding = false

	local t = TweenService:Create(skipFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(1, 20, 0.5, 0) }
	)
	t:Play()
	t.Completed:Wait()
	resetSkip()

	isHidingSkip = false
end

skipButton.MouseButton1Down:Connect(function()
	isHolding   = true
	holdElapsed = 0
	holdConn = RunService.RenderStepped:Connect(function(dt)
		if not isHolding then
			if holdConn then holdConn:Disconnect() holdConn = nil end
			TweenService:Create(progressBar, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0)}):Play()
			progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			return
		end

		holdElapsed += dt
		local progress = math.min(holdElapsed / holdRequired, 1)
		progressBar.Size = UDim2.new(progress, 0, 1, 0)
		progressBar.BackgroundColor3 = progress > 0.7
			and Color3.fromRGB(255, 100, 50)
			or  Color3.fromRGB(255, 215, 0)

		if progress >= 1 then
			holdConn:Disconnect()
			holdConn  = nil
			isHolding = false
			if onSkipCallback then onSkipCallback() end
			task.spawn(hideSkip)
		end
	end)
end)

skipButton.MouseButton1Up:Connect(function() isHolding = false end)
skipButton.MouseEnter:Connect(function()
	TweenService:Create(skipFrame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
end)
skipButton.MouseLeave:Connect(function()
	isHolding = false
	TweenService:Create(skipFrame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 15)}):Play()
end)

-- ============================================================
-- CAMERA ORBIT
-- ============================================================
local function stopOrbit()
	if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
	if originalCamType then camera.CameraType = originalCamType originalCamType = nil end
	isOrbiting = false
	-- Perhatian: skipRequested tidak di-reset di sini agar showCinematic mendeteksinya.
end

local function startOrbitCamera(targetCharacter, duration, onDone)
	stopOrbit()
	local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not hrp then if onDone then onDone() end return end

	isOrbiting      = true
	skipRequested   = false
	originalCamType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local radius     = 12
	local height     = 5
	local speed      = 0.6
	local smoothCF   = camera.CFrame
	local elapsed    = 0
	local diff       = camera.CFrame.Position - hrp.Position
	local startAngle = math.atan2(diff.Z, diff.X)

	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		if skipRequested or elapsed >= duration then
			stopOrbit()
			if onDone then task.spawn(onDone) end
			return
		end
		if not hrp or not hrp.Parent then
			stopOrbit()
			if onDone then task.spawn(onDone) end
			return
		end
		elapsed += dt
		local angle    = startAngle + (elapsed * speed)
		local targetPos    = hrp.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local targetCFrame = CFrame.new(targetPos, hrp.Position)
		smoothCF      = smoothCF:Lerp(targetCFrame, math.min(dt * 6, 1))
		camera.CFrame = smoothCF
	end)
end

-- ============================================================
-- CINEMATIC CONTROLLER
-- ============================================================
local function showCinematic(donationData)
	local color    = toColor3(donationData.cinematicColor)
	local duration = donationData.cinematicDuration or 8

	resetCinematic()

	-- Update konten
	local priceText = ""
	if donationData.currencyType == "Rupiah" then
		priceText = formatRupiah(donationData.price)
	else
		priceText = tostring(donationData.price) .. " Robux"
	end

	titleLabel.Text    = priceText .. " dari " .. donationData.donorName
	shadow1.Text       = titleLabel.Text
	shadow2.Text       = titleLabel.Text
	subtitleLabel.Text = "Terima kasih atas supportmu yang luar biasa!"

	-- Update warna
	glowCircle.BackgroundColor3 = color
	leftLine.BackgroundColor3   = color
	rightLine.BackgroundColor3  = color
	titleStroke.Color           = color

	cinematicContainer.Visible = true

	-- Bars masuk
	local barsIn = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar,    barsIn, {Size = UDim2.new(1, 0, 0, 60)}):Play()
	TweenService:Create(bottomBar, barsIn, {Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 1, -60)}):Play()
	TweenService:Create(vignette,  TweenInfo.new(0.8), {ImageTransparency = 0.3}):Play()

	task.wait(0.5)

	-- Glow expand
	TweenService:Create(glowCircle, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 200, 0, 200), BackgroundTransparency = 1
	}):Play()

	task.wait(0.3)

	-- Light rays (sementara)
	local rays = {}
	for i = 1, 5 do
		local ray = Instance.new("Frame", mainFrame)
		ray.Size                   = UDim2.new(0, 2, 0, 300)
		ray.Position               = UDim2.new(0.5, -200 + (i * 80), 0.5, -150)
		ray.AnchorPoint            = Vector2.new(0.5, 0.5)
		ray.BackgroundColor3       = color
		ray.BorderSizePixel        = 0
		ray.Rotation               = 15
		ray.BackgroundTransparency = 0.85
		ray.ZIndex                 = 12
		local rg = Instance.new("UIGradient", ray)
		rg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1),
		})
		rg.Rotation = 90
		table.insert(rays, ray)
		local ip = UDim2.new(0.5, -200 + (i * 80), 0.5, -150)
		local ep = UDim2.new(0.5, -200 + (i * 80), 0.5,  150)
		task.spawn(function()
			-- Batas waktu 10 detik agar thread mati jika frame error
			local startTime = os.clock()
			while ray and ray.Parent and (os.clock() - startTime < 10) do
				local mt = TweenService:Create(ray, TweenInfo.new(2, Enum.EasingStyle.Linear), {Position = ep})
				mt:Play() 
				mt.Completed:Wait()

				if ray and ray.Parent then 
					ray.Position = ip 
				end
				task.wait(0.05)
			end

			-- Garbage Collection Paksa jika animasi selesai / stuck
			if ray and ray.Parent then
				ray:Destroy()
			end
		end)

	end

	-- Title zoom in
	titleLabel.Size          = UDim2.new(0, 10, 0, 10)
	titleLabel.TextSize      = 8
	titleLabel.TextTransparency = 0
	titleStroke.Transparency = 0
	shadow1.Size             = UDim2.new(0, 10, 0, 10)
	shadow1.TextSize         = 8
	shadow1.TextTransparency = 0.5
	shadow2.Size             = UDim2.new(0, 10, 0, 10)
	shadow2.TextSize         = 8
	shadow2.TextTransparency = 0.7

	local zoomInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local zoomIn   = TweenService:Create(titleLabel, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44})
	TweenService:Create(shadow1, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44, Position = UDim2.new(0.5, 2, 0, 2)}):Play()
	TweenService:Create(shadow2, zoomInfo, {Size = UDim2.new(1.5, 0, 0, 90), TextSize = 44, Position = UDim2.new(0.5, 4, 0, 4)}):Play()
	zoomIn:Play()
	zoomIn.Completed:Wait()
	
	if skipRequested then resetCinematic() return end

	-- Impact flash
	impactFlash.Visible                = true
	impactFlash.BackgroundTransparency = 0
	TweenService:Create(impactFlash, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()

	-- Screen shake
	task.spawn(function()
		local orig = mainFrame.Position
		for i = 1, 10 do
			local v = math.max(18 - (i * 2), 1)  -- minimum 1 agar random tidak error
			mainFrame.Position = UDim2.new(0.5, math.random(-v, v), 1, -85 + math.random(-v, v))
			task.wait(0.025)
		end
		mainFrame.Position = orig
	end)

	-- Impact rings (sementara)
	for ring = 1, 4 do
		task.spawn(function()
			local ir = Instance.new("Frame", mainFrame)
			ir.Size = UDim2.new(0,0,0,0) ir.Position = UDim2.new(0.5,0,0.5,0)
			ir.AnchorPoint = Vector2.new(0.5,0.5) ir.BackgroundTransparency = 1
			ir.BorderSizePixel = 0 ir.ZIndex = 14
			local rs = Instance.new("UIStroke", ir)
			rs.Color = color rs.Thickness = math.max(8-(ring*1.5),1)
			Instance.new("UICorner", ir).CornerRadius = UDim.new(1,0)
			task.wait(ring * 0.05)
			TweenService:Create(ir, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0,500,0,500)}):Play()
			TweenService:Create(rs, TweenInfo.new(0.8), {Transparency = 1, Thickness = 1}):Play()
			task.wait(0.85)
			if ir and ir.Parent then ir:Destroy() end
		end)
	end

	-- Bounce back
	local bounceInfo = TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	local bb = TweenService:Create(titleLabel, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36})
	TweenService:Create(shadow1, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36, Position = UDim2.new(0.5,2,0,2)}):Play()
	TweenService:Create(shadow2, bounceInfo, {Size = UDim2.new(1,0,0,60), TextSize = 36, Position = UDim2.new(0.5,4,0,4)}):Play()
	bb:Play() bb.Completed:Wait()

	-- Chromatic aberration (sementara)
	local redChrome  = titleLabel:Clone()
	redChrome.TextColor3 = Color3.fromRGB(255,50,50) redChrome.TextTransparency = 0.6
	redChrome.ZIndex = 19
	local s1 = redChrome:FindFirstChildOfClass("UIStroke") if s1 then s1:Destroy() end
	redChrome.Parent = mainFrame

	local blueChrome = titleLabel:Clone()
	blueChrome.TextColor3 = Color3.fromRGB(50,150,255) blueChrome.TextTransparency = 0.6
	blueChrome.ZIndex = 19
	local s2 = blueChrome:FindFirstChildOfClass("UIStroke") if s2 then s2:Destroy() end
	blueChrome.Parent = mainFrame

	for i = 1, 4 do
		local o = 10 - (i*2)
		redChrome.Position  = UDim2.new(0.5,-o,0,0) blueChrome.Position = UDim2.new(0.5,o,0,0)
		task.wait(0.04)
		redChrome.Position  = UDim2.new(0.5,o,0,0)  blueChrome.Position = UDim2.new(0.5,-o,0,0)
		task.wait(0.04)
	end
	TweenService:Create(redChrome,  TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	TweenService:Create(blueChrome, TweenInfo.new(0.3), {TextTransparency = 1}):Play()

	-- Shake residual
	for i = 1, 5 do
		local v = 8 - i
		TweenService:Create(titleLabel, TweenInfo.new(0.035), {Rotation =  v}):Play()
		TweenService:Create(shadow1,    TweenInfo.new(0.035), {Rotation =  v}):Play()
		TweenService:Create(shadow2,    TweenInfo.new(0.035), {Rotation =  v}):Play()
		task.wait(0.035)
		TweenService:Create(titleLabel, TweenInfo.new(0.035), {Rotation = -v}):Play()
		TweenService:Create(shadow1,    TweenInfo.new(0.035), {Rotation = -v}):Play()
		TweenService:Create(shadow2,    TweenInfo.new(0.035), {Rotation = -v}):Play()
		task.wait(0.035)
	end
	TweenService:Create(titleLabel, TweenInfo.new(0.1), {Rotation = 0}):Play()
	TweenService:Create(shadow1,    TweenInfo.new(0.1), {Rotation = 0}):Play()
	TweenService:Create(shadow2,    TweenInfo.new(0.1), {Rotation = 0}):Play()

	task.wait(0.2)
	if redChrome  and redChrome.Parent  then redChrome:Destroy()  end
	if blueChrome and blueChrome.Parent then blueChrome:Destroy() end
	impactFlash.Visible = false
	task.wait(0.2)

	-- Subtitle + lines muncul
	TweenService:Create(subtitleLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
	local lineInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(leftLine,  lineInfo, {Size = UDim2.new(0, 120, 0, 2)}):Play()
	TweenService:Create(rightLine, lineInfo, {Size = UDim2.new(0, 120, 0, 2)}):Play()

	-- Particles (sementara)
	for i = 1, 15 do
		task.spawn(function()
			local p = Instance.new("Frame", mainFrame)
			p.Size = UDim2.new(0, math.random(2,5), 0, math.random(2,5))
			p.Position = UDim2.new(math.random(0,100)/100, 0, 1.2, 0)
			p.BackgroundColor3 = color p.BorderSizePixel = 0
			p.BackgroundTransparency = 0.3 p.ZIndex = 18
			Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
			local pt = TweenService:Create(p, TweenInfo.new(math.random(12,22)/10, Enum.EasingStyle.Linear), {
				Position = UDim2.new(math.random(0,100)/100, 0, -0.5, 0), BackgroundTransparency = 1
			})
			pt:Play() pt.Completed:Wait()
			if p and p.Parent then p:Destroy() end
		end)
	end

	-- 🔥 FIX 1: Jeda menunggu durasi Cinematic ATAU di-skip
	local elapsedCinematic = 0
	while elapsedCinematic < duration and not skipRequested do
		elapsedCinematic += task.wait(0.1)
	end

	-- Fade out
	local fadeOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(titleLabel,    fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(titleStroke,   fadeOut, {Transparency = 1}):Play()
	TweenService:Create(shadow1,       fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(shadow2,       fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(subtitleLabel, fadeOut, {TextTransparency = 1}):Play()
	TweenService:Create(leftLine,      fadeOut, {BackgroundTransparency = 1}):Play()
	TweenService:Create(rightLine,     fadeOut, {BackgroundTransparency = 1}):Play()
	TweenService:Create(vignette,      fadeOut, {ImageTransparency = 1}):Play()

	task.wait(0.3)

	local barsOut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local botOut  = TweenService:Create(bottomBar, barsOut, {Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,1,0)})
	TweenService:Create(topBar, barsOut, {Size = UDim2.new(1,0,0,0)}):Play()
	botOut:Play()
	botOut.Completed:Wait()

	for _, ray in ipairs(rays) do
		if ray and ray.Parent then ray:Destroy() end
	end

	resetCinematic()
end

-- ============================================================
-- QUEUE SYSTEM (SISTEM ANTREAN DONASI)
-- ============================================================
local isPlayingCinematic = false
local cinematicQueue = {}

local function processCinematicQueue()
	-- Jika masih ada cinematic yang main, atau antrean kosong, batalkan
	if isPlayingCinematic or #cinematicQueue == 0 then return end
	isPlayingCinematic = true

	local donationData = table.remove(cinematicQueue, 1)

	task.spawn(playSound)

	local donorPlayer = Players:GetPlayerByUserId(donationData.donorUserId)
	if donorPlayer then
		local character = donorPlayer.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			showSkip(function() skipRequested = true end)
			startOrbitCamera(character, donationData.cinematicDuration or 8, function()
				task.spawn(hideSkip)
			end)
		end
	end

	task.spawn(function()
		showCinematic(donationData)
	end)

	-- Tunggu durasi cinematic selesai sebelum lanjut ke antrean berikutnya
	task.delay(donationData.cinematicDuration or 8, function()
		isPlayingCinematic = false
		processCinematicQueue() -- Lanjut panggil antrean berikutnya
	end)
end

CinematicRemote.OnClientEvent:Connect(function(donationData)
	if not donationData or not donationData.donorName then return end

	if donationData.useCinematic then
		-- Masukkan ke antrean
		table.insert(cinematicQueue, donationData)
		processCinematicQueue()
	end
end)

task.wait(2)
RequestDonationState:FireServer()
