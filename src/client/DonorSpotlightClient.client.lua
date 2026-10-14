-- ============================================================
-- DonorSpotlightClient (Cinematic Camera Spotlight on Donor)
-- Optimized for Mobile: Zero Memory Leak, No Stuck Camera, Smooth Transitions
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local DonorSpotlightRemote = ReplicatedStorage:WaitForChild("DonorSpotlightRemote", 20)

if not DonorSpotlightRemote then
	warn("[DonorSpotlightClient] DonorSpotlightRemote tidak ditemukan di ReplicatedStorage!")
	return
end

-- State Management (Thread & Session Safety)
local currentSessionId = 0
local activeTween = nil
local activeConnections = {}

-- Raycast params untuk deteksi dinding (mencegah kamera tembus tembok saat orbit)
local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
wallRayParams.IgnoreWater = true

local function cleanupConnections()
	for _, conn in ipairs(activeConnections) do
		if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(activeConnections)
end

local function cancelActiveTween()
	if activeTween then
		pcall(function() activeTween:Cancel() end)
		activeTween = nil
	end
end

-- ============================================================
-- FAIL-SAFE RESTORE CAMERA (PASTIKAN KAMERA TIDAK PERNAH NYANGKUT)
-- ============================================================
local originalFOV = 70

local function forceRestoreCamera(originalCamType)
	cancelActiveTween()
	cleanupConnections()

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local localChar = localPlayer.Character
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")

	cam.FieldOfView = originalFOV
	cam.CameraType = originalCamType or Enum.CameraType.Custom
	if localHum and localHum.Health > 0 then
		cam.CameraSubject = localHum
	end
end

-- Transisi halus kembali ke POV pemain sendiri (ZOOM OUT & PULL BACK)
local function returnToPlayerPOV(originalCamType, onDone)
	local cam = Workspace.CurrentCamera
	if not cam then
		forceRestoreCamera(originalCamType)
		if onDone then onDone() end
		return
	end

	local localChar = localPlayer.Character
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")

	-- Jika karakter pemain mati atau tidak ada, langsung pulihkan tanpa animasi
	if not localChar or not localHum or localHum.Health <= 0 or not localHrp then
		forceRestoreCamera(originalCamType)
		if onDone then onDone() end
		return
	end

	-- Hitung posisi kamera di belakang bahu/kepala pemain lokal dengan proteksi dinding
	local lookVec = localHrp.CFrame.LookVector
	local headPos = localHrp.Position + Vector3.new(0, 1.5, 0)
	local returnOffset = -(lookVec * 11) + Vector3.new(0, 3.5, 0)
	local wallHit = Workspace:Raycast(headPos, returnOffset, wallRayParams)
	local targetReturnPos
	if wallHit then
		targetReturnPos = headPos + returnOffset.Unit * math.max(3.0, wallHit.Distance - 0.5)
	else
		targetReturnPos = localHrp.Position + returnOffset
	end
	local targetLookAt = headPos
	local targetReturnCF = CFrame.new(targetReturnPos, targetLookAt)

	cancelActiveTween()

	-- Buat tween ZOOM OUT & transisi pulang (0.8 detik, smooth quad out)
	local returnTween = TweenService:Create(
		cam,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ 
			CFrame = targetReturnCF,
			FieldOfView = originalFOV
		}
	)
	activeTween = returnTween

	local completed = false
	local conn
	conn = returnTween.Completed:Connect(function()
		completed = true
		if conn then conn:Disconnect() end
	end)

	returnTween:Play()

	-- Tunggu maksimal 0.9 detik dengan proteksi timeout agar tidak hang
	local elapsed = 0
	while not completed and elapsed < 0.9 do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt
	end

	if conn and conn.Connected then conn:Disconnect() end
	cancelActiveTween()

	-- Kembalikan kontrol kamera sepenuhnya ke Roblox PlayerScripts
	forceRestoreCamera(originalCamType)

	if onDone then onDone() end
end

-- ============================================================
-- MAIN SPOTLIGHT SEQUENCE (CINEMATIC ZOOM-IN & ZOOM-OUT)
-- ============================================================
local function playDonorSpotlight(donorUserId, donorDisplayName, duration)
	duration = duration or 5 -- Total 5 detik

	-- Buat session ID baru untuk membatalkan animasi sebelumnya (Anti Race-Condition)
	currentSessionId += 1
	local sessionId = currentSessionId

	cancelActiveTween()
	cleanupConnections()

	local cam = Workspace.CurrentCamera
	if not cam then return end

	-- Simpan FOV asli pemain
	if cam.FieldOfView and cam.FieldOfView > 30 and cam.FieldOfView < 120 then
		originalFOV = cam.FieldOfView
	else
		originalFOV = 70
	end

	-- Cari pemain donor (Mendukung ID negatif di Studio dan DisplayName)
	local donorPlayer = nil
	if donorUserId and tonumber(donorUserId) then
		donorPlayer = Players:GetPlayerByUserId(tonumber(donorUserId))
	end
	if not donorPlayer and donorDisplayName then
		local searchName = tostring(donorDisplayName):lower()
		for _, p in ipairs(Players:GetPlayers()) do
			if p.DisplayName:lower() == searchName or p.Name:lower() == searchName then
				donorPlayer = p
				break
			end
		end
	end
	if not donorPlayer and #Players:GetPlayers() == 1 then
		-- Fallback khusus Studio test play single player
		donorPlayer = localPlayer
	end

	-- Jika donor tidak ada di server, batal
	if not donorPlayer then return end

	-- Tunggu karakter donor siap (maks 1.5 detik)
	local donorChar = donorPlayer.Character
	local waited = 0
	while waited < 1.5 and (not donorChar or not donorChar:FindFirstChild("HumanoidRootPart")) do
		waited += task.wait(0.15)
		if sessionId ~= currentSessionId then return end
		donorChar = donorPlayer.Character
	end

	if not donorChar or sessionId ~= currentSessionId then return end
	local donorHrp = donorChar:FindFirstChild("HumanoidRootPart")
	local donorHum = donorChar:FindFirstChildOfClass("Humanoid")
	if not donorHrp or not donorHum or donorHum.Health <= 0 then return end

	-- Simpan CameraType awal (Custom / Follow dsb)
	local originalCamType = cam.CameraType
	if originalCamType == Enum.CameraType.Scriptable then
		originalCamType = Enum.CameraType.Custom
	end

	-- Setup Raycast Ignore List (Karakter donor & pemain lokal diabaikan agar tidak dianggap dinding)
	local ignoreList = { donorChar }
	if localPlayer.Character then
		table.insert(ignoreList, localPlayer.Character)
	end
	wallRayParams.FilterDescendantsInstances = ignoreList

	-- Proteksi Event: Jika donor mati / leave, atau local player mati / respawn -> segera kembalikan kamera!
	local isRunning = true
	local function abortSpotlight()
		if not isRunning then return end
		isRunning = false
		if sessionId == currentSessionId then
			returnToPlayerPOV(originalCamType)
		end
	end

	table.insert(activeConnections, donorHum.Died:Connect(abortSpotlight))
	table.insert(activeConnections, donorChar.AncestryChanged:Connect(function(_, parent)
		if not parent then abortSpotlight() end
	end))

	local localChar = localPlayer.Character
	if localChar then
		local myHum = localChar:FindFirstChildOfClass("Humanoid")
		if myHum then
			table.insert(activeConnections, myHum.Died:Connect(abortSpotlight))
		end
	end

	-- Alihkan kamera ke mode Scriptable
	cam.CameraType = Enum.CameraType.Scriptable

	local donorHeadPos = donorHrp.Position + Vector3.new(0, 1.4, 0)
	local donorLook = donorHrp.CFrame.LookVector
	local donorRight = donorHrp.CFrame.RightVector

	-- Sudut Heroic Front 3/4 (Depan agak serong kanan donor, menghadap donor)
	local frontDir = (donorLook * 0.88 + donorRight * 0.32).Unit

	-- Cek apakah depan donor terhalang tembok (misal mepet dinding)
	local testRay = Workspace:Raycast(donorHeadPos, frontDir * 9, wallRayParams)
	if testRay and testRay.Distance < 5 then
		-- Jika depan terhalang tembok, coba cek dari sudut lain yang lebih lapang
		local backDir = (-donorLook * 0.88 + donorRight * 0.32).Unit
		local backRay = Workspace:Raycast(donorHeadPos, backDir * 9, wallRayParams)
		if not backRay or backRay.Distance > testRay.Distance then
			frontDir = backDir
		end
	end

	-- Jarak awal establishing (jauh) vs jarak close-up (zoom in)
	local startDist = 13.0
	local targetCloseDist = 6.5

	-- Posisi kamera Zoom-In (fokus ke dada & wajah donor dengan sudut sedikit mendongak / hero angle)
	local closeTargetPos = donorHeadPos + (frontDir * targetCloseDist) + Vector3.new(0, 0.4, 0)
	local wallHitClose = Workspace:Raycast(donorHeadPos, closeTargetPos - donorHeadPos, wallRayParams)
	if wallHitClose then
		closeTargetPos = donorHeadPos + (closeTargetPos - donorHeadPos).Unit * math.max(3.5, wallHitClose.Distance - 0.8)
	end

	-- Target fokus kamera (titik wajah/kepala donor)
	local focalPoint = donorHeadPos + Vector3.new(0, 0.2, 0)
	local closeTargetCF = CFrame.new(closeTargetPos, focalPoint)

	-- ============================================================
	-- FASE 1: DYNAMIC ZOOM-IN HERO PUSH (~0.85 detik)
	-- Kamera melesat mendekat ke donor dan FOV menegang (fokus sinematik)
	-- ============================================================
	cancelActiveTween()
	local cinematicFOV = math.clamp(originalFOV - 20, 46, 54) -- Efek lensa portrait/telephoto

	local zoomInTween = TweenService:Create(
		cam,
		TweenInfo.new(0.85, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ 
			CFrame = closeTargetCF,
			FieldOfView = cinematicFOV
		}
	)
	activeTween = zoomInTween

	local inDone = false
	local inConn = zoomInTween.Completed:Connect(function()
		inDone = true
	end)
	zoomInTween:Play()

	local inElapsed = 0
	while not inDone and inElapsed < 0.95 do
		local dt = RunService.RenderStepped:Wait()
		inElapsed += dt
		if sessionId ~= currentSessionId or not isRunning then
			if inConn then inConn:Disconnect() end
			cancelActiveTween()
			forceRestoreCamera(originalCamType)
			return
		end
	end
	if inConn then inConn:Disconnect() end
	cancelActiveTween()

	if sessionId ~= currentSessionId or not isRunning then
		forceRestoreCamera(originalCamType)
		return
	end

	-- ============================================================
	-- FASE 2: HERO SHOWCASE / SLOW CINEMATIC DRIFT (NO ROTATION!)
	-- Kamera tetap di depan donor, melakukan slow push & subtle breathing
	-- Durasi ~2.8 detik agar avatar donor terlihat jelas, gagah, & menonjol
	-- ============================================================
	local remainingDuration = math.max(1.8, duration - 1.8)
	local elapsed = 0
	local basePos = closeTargetPos

	while isRunning and (elapsed < remainingDuration) and (sessionId == currentSessionId) do
		local dt = RunService.RenderStepped:Wait()
		dt = math.min(dt, 0.05) -- Clamp jika HP drop FPS
		elapsed += dt

		-- Validasi donor masih hidup & ada
		if not donorChar.Parent or not donorHrp.Parent or donorHum.Health <= 0 then
			break
		end

		local currentHead = donorHrp.Position + Vector3.new(0, 1.4, 0)
		local currentFocal = currentHead + Vector3.new(0, 0.2, 0)

		-- Efek subtle breathing / steady dolly push (tanpa muter sama sekali!)
		local progress = math.clamp(elapsed / remainingDuration, 0, 1)
		-- Perlahan makin mendekat 0.7 stud secara halus (dolly-in slow motion)
		local slowPush = -frontDir * (progress * 0.7)
		-- Sentuhan floating gimbal sangat halus
		local breathingY = Vector3.new(0, math.sin(elapsed * 2.0) * 0.12, 0)

		local currentCamPos = currentHead + (frontDir * targetCloseDist) + slowPush + breathingY
		cam.CFrame = CFrame.new(currentCamPos, currentFocal)
	end

	-- ============================================================
	-- FASE 3: DYNAMIC ZOOM-OUT & TRANSISI PULANG KE POV PEMAIN (~0.85s)
	-- FOV melebar kembali ke normal dan kamera pulang ke POV
	-- ============================================================
	if sessionId == currentSessionId then
		returnToPlayerPOV(originalCamType, function()
			isRunning = false
		end)
	end
end

-- ============================================================
-- GLOBAL FAIL-SAFE: JIKA LOCAL PLAYER RESPAWN
-- ============================================================
localPlayer.CharacterAdded:Connect(function()
	currentSessionId += 1
	forceRestoreCamera(Enum.CameraType.Custom)
end)

-- Listener Remote dari Server
DonorSpotlightRemote.OnClientEvent:Connect(function(donorUserId, donorDisplayName, duration)
	task.spawn(function()
		local ok, err = pcall(function()
			playDonorSpotlight(donorUserId, donorDisplayName, duration or 5)
		end)
		if not ok then
			warn("[DonorSpotlightClient] Error:", err)
			forceRestoreCamera(Enum.CameraType.Custom)
		end
	end)
end)

