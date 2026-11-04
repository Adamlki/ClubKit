-- DONOR SPOTLIGHT CONTROLLER

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local CameraLease = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CameraLease"))
local DonorSpotlightRemote = ReplicatedStorage:WaitForChild("DonorSpotlightRemote", 20)

if not DonorSpotlightRemote then
	warn("[DonorSpotlightClient] DonorSpotlightRemote tidak ditemukan di ReplicatedStorage!")
	return
end

local currentSessionId = 0
local activeTween = nil
local activeConnections = {}
local leaseToken = nil

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

-- FAIL-SAFE RESTORE CAMERA
local originalFOV = 70

local function forceRestoreCamera(originalCamType)
	local owned = CameraLease:IsOwner("DonorSpotlight", leaseToken)
	CameraLease:Release("DonorSpotlight", leaseToken)
	leaseToken = nil

	cancelActiveTween()
	cleanupConnections()

	if not owned then return end

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

local function returnToPlayerPOV(originalCamType, onDone)
	if not CameraLease:IsOwner("DonorSpotlight", leaseToken) then
		forceRestoreCamera(originalCamType)
		if onDone then onDone() end
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then
		forceRestoreCamera(originalCamType)
		if onDone then onDone() end
		return
	end

	local localChar = localPlayer.Character
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if not localChar or not localHum or localHum.Health <= 0 or not localHrp then
		forceRestoreCamera(originalCamType)
		if onDone then onDone() end
		return
	end

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

	local elapsed = 0
	while not completed and elapsed < 0.9 do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt
	end

	if conn and conn.Connected then conn:Disconnect() end
	cancelActiveTween()
	forceRestoreCamera(originalCamType)

	if onDone then onDone() end
end

-- MAIN SPOTLIGHT SEQUENCE
local function playDonorSpotlight(donorUserId, donorDisplayName, duration)
	duration = duration or 5

	currentSessionId += 1
	local sessionId = currentSessionId

	cancelActiveTween()
	cleanupConnections()

	local cam = Workspace.CurrentCamera
	if not cam then return end

	if cam.FieldOfView and cam.FieldOfView > 30 and cam.FieldOfView < 120 then
		originalFOV = cam.FieldOfView
	else
		originalFOV = 70
	end

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
		donorPlayer = localPlayer
	end

	if not donorPlayer then return end

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

	local originalCamType = cam.CameraType
	if originalCamType == Enum.CameraType.Scriptable then
		originalCamType = Enum.CameraType.Custom
	end

	local ignoreList = { donorChar }
	if localPlayer.Character then
		table.insert(ignoreList, localPlayer.Character)
	end
	wallRayParams.FilterDescendantsInstances = ignoreList

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

	leaseToken = CameraLease:Acquire("DonorSpotlight", 50)
	if not leaseToken then return end

	cam.CameraType = Enum.CameraType.Scriptable

	local donorHeadPos = donorHrp.Position + Vector3.new(0, 1.4, 0)
	local donorLook = donorHrp.CFrame.LookVector
	local donorRight = donorHrp.CFrame.RightVector
	local frontDir = (donorLook * 0.88 + donorRight * 0.32).Unit
	local testRay = Workspace:Raycast(donorHeadPos, frontDir * 9, wallRayParams)

	if testRay and testRay.Distance < 5 then
		-- Jika depan terhalang tembok, coba cek dari sudut lain yang lebih lapang
		local backDir = (-donorLook * 0.88 + donorRight * 0.32).Unit
		local backRay = Workspace:Raycast(donorHeadPos, backDir * 9, wallRayParams)
		if not backRay or backRay.Distance > testRay.Distance then
			frontDir = backDir
		end
	end

	local startDist = 13.0
	local targetCloseDist = 6.5

	local closeTargetPos = donorHeadPos + (frontDir * targetCloseDist) + Vector3.new(0, 0.4, 0)
	local wallHitClose = Workspace:Raycast(donorHeadPos, closeTargetPos - donorHeadPos, wallRayParams)
	if wallHitClose then
		closeTargetPos = donorHeadPos + (closeTargetPos - donorHeadPos).Unit * math.max(3.5, wallHitClose.Distance - 0.8)
	end

	local focalPoint = donorHeadPos + Vector3.new(0, 0.2, 0)
	local closeTargetCF = CFrame.new(closeTargetPos, focalPoint)

	-- FASE 1: DYNAMIC ZOOM-IN HERO PUSH (~0.85 detik)
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

	-- FASE 2: HERO SHOWCASE / SLOW CINEMATIC DRIFT (NO ROTATION!)
	local remainingDuration = math.max(1.8, duration - 1.8)
	local elapsed = 0
	local basePos = closeTargetPos

	while isRunning and (elapsed < remainingDuration) and (sessionId == currentSessionId) do
		if not CameraLease:IsOwner("DonorSpotlight", leaseToken) then break end
		local dt = RunService.RenderStepped:Wait()
		dt = math.min(dt, 0.05)
		elapsed += dt

		if not donorChar.Parent or not donorHrp.Parent or donorHum.Health <= 0 then
			break
		end

		local currentHead = donorHrp.Position + Vector3.new(0, 1.4, 0)
		local currentFocal = currentHead + Vector3.new(0, 0.2, 0)
		local progress = math.clamp(elapsed / remainingDuration, 0, 1)
		local slowPush = -frontDir * (progress * 0.7)
		local breathingY = Vector3.new(0, math.sin(elapsed * 2.0) * 0.12, 0)
		local currentCamPos = currentHead + (frontDir * targetCloseDist) + slowPush + breathingY
		cam.CFrame = CFrame.new(currentCamPos, currentFocal)
	end

	-- FASE 3: DYNAMIC ZOOM-OUT & TRANSISI PULANG KE POV PEMAIN
	if sessionId == currentSessionId then
		returnToPlayerPOV(originalCamType, function()
			isRunning = false
		end)
	end
end

-- GLOBAL FAIL-SAFE: JIKA LOCAL PLAYER RESPAWN
localPlayer.CharacterAdded:Connect(function()
	currentSessionId += 1
	forceRestoreCamera(Enum.CameraType.Custom)
end)

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
