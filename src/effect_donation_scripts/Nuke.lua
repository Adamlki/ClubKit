local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local function isDonationEffectHidden()
	return _G.HideDonationEffects == true or (_G.IsDonationEffectsHidden and _G.IsDonationEffectsHidden() == true)
end

-- Config
local TARGET_POSITION = (workspace:FindFirstChild("EffectTarget") and workspace.EffectTarget.Position) or Vector3.new(-83.613, -25.66, -439.504)

-- Get RemoteEvent
local effectsEvent = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("EffectsEvent")

-- Get VFX from ReplicatedStorage
local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local nukeTemplate = vfxFolder:WaitForChild("Templates"):WaitForChild("Nuke")

-- Helper Functions
local function scaleParticleEmitter(emitter, scale)
	emitter.Speed = NumberRange.new(emitter.Speed.Min * scale, emitter.Speed.Max * scale)
	emitter.Acceleration = emitter.Acceleration * scale

	local keypoints = emitter.Size.Keypoints
	local newKeypoints = {}

	for i = 1, #keypoints do
		table.insert(newKeypoints, NumberSequenceKeypoint.new(
			keypoints[i].Time,
			keypoints[i].Value * scale,
			keypoints[i].Envelope * scale
			))
	end

	emitter.Size = NumberSequence.new(newKeypoints)
end

-- Fireworks helper function
local FIREWORK_SOUNDS = { 138080762, 269146157, 160248505, 242458749, 160248459, 160248479, 160248493, 4583102108 }

local function launchFireworkRocket(rocketTemplate, spawnPos, spreadDist, parentFolder)
	if not rocketTemplate or not parentFolder or not parentFolder.Parent then return end

	local rocket = rocketTemplate:Clone()
	rocket.Color = Color3.fromHSV(math.random(0, 100) / 100, math.random(75, 100) / 100, 1)
	rocket.Position = spawnPos + Vector3.new(math.random(-spreadDist, spreadDist), 0, math.random(-spreadDist, spreadDist))
	rocket.Velocity = Vector3.new(0, math.random(250, 400), 0)
	rocket.CanCollide = false
	rocket.CanTouch = false
	rocket.CanQuery = false
	rocket.Parent = parentFolder

	task.spawn(function()
		pcall(function()
			rocket.Trail.Color = ColorSequence.new(rocket.Color)
			rocket.Flares1.Color = ColorSequence.new(rocket.Color)
			rocket.Flares2.Color = ColorSequence.new(rocket.Color)
			rocket.Flares3.Color = ColorSequence.new(rocket.Color)
			rocket.SparkleExplosion.Color = ColorSequence.new(rocket.Color)
			rocket.EmitPoint.Flames.Color = ColorSequence.new(rocket.Color)
			rocket.Particles.Flare.Color = ColorSequence.new(rocket.Color)
			rocket.ExplosionFlare.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 200, 100), NumberSequenceKeypoint.new(1, 50, 25) })
			rocket.ExplosionFlare.Color = ColorSequence.new(rocket.Color)
			rocket.BodyForce.Force = Vector3.new(0, rocket:GetMass() * workspace.Gravity, 0)

			local sndLaunch = Instance.new("Sound")
			sndLaunch.Name = "Launch"
			sndLaunch.Parent = rocket
			sndLaunch.RollOffMinDistance = 20
			sndLaunch.PlaybackSpeed = math.random(90, 110) / 100
			sndLaunch.SoundId = "rbxassetid://947384308"
			sndLaunch.Volume = 1.15

			local sndBang = Instance.new("Sound")
			sndBang.Name = "Bang"
			sndBang.Parent = rocket
			sndBang.RollOffMinDistance = 50
			sndBang.PlaybackSpeed = math.random(90, 110) / 100
			sndBang.SoundId = "rbxassetid://" .. FIREWORK_SOUNDS[math.random(1, #FIREWORK_SOUNDS)]
			sndBang.Volume = 3

			rocket.Anchored = false
			sndLaunch:Play()
			task.wait(math.random(75, 200) / 100)

			if not rocket.Parent then return end

			rocket.Transparency = 1
			rocket.Anchored = true
			rocket.CanCollide = false
			rocket.Trail.Enabled = false
			rocket.EmitPoint.Flames.Enabled = false
			rocket.Orientation = Vector3.new(math.random(-180, 180), math.random(-180, 180), math.random(-180, 180))

			for v7 = 1, 16 do
				local flarePart = Instance.new("Part")
				flarePart.CastShadow = false
				flarePart.Color = rocket.Color
				flarePart.Material = Enum.Material.Neon
				flarePart.Name = "FireworkFlare"
				flarePart.CFrame = rocket.CFrame:ToWorldSpace(CFrame.Angles(math.rad(v7 * 22.5), 0, 0))
				flarePart.Position = rocket.Position
				flarePart.Anchored = true
				flarePart.CanCollide = false
				flarePart.CanTouch = false
				flarePart.CanQuery = false
				flarePart.Shape = Enum.PartType.Ball
				flarePart.Size = Vector3.new(3, 3, 3)
				flarePart.Transparency = 1
				flarePart.Velocity = flarePart.CFrame.LookVector * 50
				flarePart.Parent = parentFolder

				local att0 = Instance.new("Attachment", flarePart)
				att0.Position = Vector3.new(0, flarePart.Size.Y * 0.5, 0)
				local att1 = Instance.new("Attachment", flarePart)
				att1.Position = Vector3.new(0, flarePart.Size.Y * -0.5, 0)

				local trailClone = rocket.Trail:Clone()
				trailClone.Attachment0 = att0
				trailClone.Attachment1 = att1
				trailClone.Lifetime = 2.5
				trailClone.Enabled = true
				trailClone.Parent = flarePart

				local bf = Instance.new("BodyForce", flarePart)
				bf.Force = Vector3.new(0, flarePart:GetMass() * workspace.Gravity - 40, 0)
				flarePart.Anchored = false

				local flareClone = rocket.Particles.Flare:Clone()
				flareClone.Enabled = true
				flareClone.Parent = flarePart

				task.spawn(function()
					task.wait(3.5)
					if flarePart.Parent then
						trailClone.Enabled = false
						flareClone.Enabled = false
						flarePart.Anchored = true
						task.wait(2)
						if flarePart.Parent then flarePart:Destroy() end
					end
				end)
			end

			rocket.Flares1:Emit(20)
			rocket.Flares2:Emit(15)
			rocket.Flares3:Emit(10)
			rocket.ExplosionFlare:Emit(5)
			rocket.SparkleExplosion:Emit(25)
			sndBang:Play()
			task.wait(6)
			if rocket.Parent then rocket:Destroy() end
		end)
	end)
end


-- Main Effect Function
local function playNukeEffect(donorName, recipientName, amount, userId, currency)
	local targetPart = workspace:FindFirstChild("EffectTarget")
	local TARGET_POSITION = (targetPart and targetPart.Position) or Vector3.new(-83.613, -25.66, -439.504)
	-- FIXED: Removed isEffectRunning check - server queue handles this

	-- Check if player has effects enabled
	if localPlayer:GetAttribute('GlobalEffects') == false then
		return
	end

	-- Create single effect folder for everything
	local activeEffects = workspace:FindFirstChild("ActiveEffects") or workspace
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "Nuke_" .. tick()
	effectFolder.Parent = activeEffects
	game:GetService("CollectionService"):AddTag(effectFolder, "DonationEffect")

	effectFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end)

	local CameraShaker = require(script.CameraShaker)

	-- Clone nuke model from ReplicatedStorage
	local nuke = nukeTemplate:Clone()
	local nukeCFrame = nuke.NukeValues.NukeCFrame
	local uiFrame = nuke.BillboardGuiAnimation.Frame
	uiFrame.TextLabels.TopText.Visible = true
	uiFrame.TextLabels.BottomText.Visible = true

	local centerEmitPoint = nuke.CenterEmitPoint
	local thrustEmitPoint = nuke.ThrustEmitPoint

	-- Create bloom effect
	local bloomEffect = Instance.new("BloomEffect")
	bloomEffect.Enabled = true
	bloomEffect.Name = "NukeBloom"
	bloomEffect.Size = 15
	bloomEffect.Threshold = 0.25
	bloomEffect.Intensity = -1
	bloomEffect.Parent = game.Lighting

	local objects = nuke.Objects
	local confettiBox = objects.ConfettiBox:Clone()

	-- Move confetti to effect folder immediately
	confettiBox.Parent = effectFolder

	objects.ConfettiBox:Destroy()
	objects:Destroy()

	local cameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
	end)

	cameraShaker:Start()

	nuke.Position = TARGET_POSITION

	-- Scale particles
	scaleParticleEmitter(thrustEmitPoint.Flame, 5)
	scaleParticleEmitter(thrustEmitPoint.Shockwave, 15)
	scaleParticleEmitter(thrustEmitPoint.BigShockwave, 50)
	scaleParticleEmitter(thrustEmitPoint.Flame2, 5)
	scaleParticleEmitter(thrustEmitPoint.Flame3, 5)
	scaleParticleEmitter(thrustEmitPoint.Flame4, 5)
	scaleParticleEmitter(thrustEmitPoint.Flame5, 10)
	scaleParticleEmitter(thrustEmitPoint.Smoke, 1.5)
	scaleParticleEmitter(thrustEmitPoint.SmokePreLaunch, 3)
	scaleParticleEmitter(thrustEmitPoint.SmokeLaunch, 4)
	scaleParticleEmitter(thrustEmitPoint.SmokeRing, 4)
	scaleParticleEmitter(nuke.Sparkles, 2.5)
	scaleParticleEmitter(nuke.Sparks, 3)
	scaleParticleEmitter(centerEmitPoint.Rays1, 25)
	scaleParticleEmitter(centerEmitPoint.Rays2, 25)
	scaleParticleEmitter(centerEmitPoint.Rays3, 25)
	scaleParticleEmitter(centerEmitPoint.SmoothRaysBig, 7.5)
	scaleParticleEmitter(centerEmitPoint.RaysBig, 8)
	scaleParticleEmitter(centerEmitPoint.SparkleExplosion, 4)
	scaleParticleEmitter(centerEmitPoint.Spark3, 25)

	nuke.CFrame = script.NukeCFrame.Value
	nuke.AlignPosition.Position = nuke.Position
	nuke.AlignOrientation.CFrame = nuke.CFrame
	nukeCFrame.Value = nuke.CFrame
	nuke.Anchored = false

	-- Parent nuke to effect folder
	nuke.Parent = effectFolder

	local heartbeatConnection = RunService.Heartbeat:Connect(function()
		nuke.AlignPosition.Position = nukeCFrame.Value.Position
		nuke.AlignOrientation.CFrame = nukeCFrame.Value
	end)

	task.wait(1)

	script.Alarm:Play()
	nuke.Sparkles.Enabled = false
	thrustEmitPoint.SmokePreLaunch.Enabled = true
	thrustEmitPoint.SmokePreLaunch.Rate = 0
	nuke.PreThruster:Play()
	nuke.PreThruster.Volume = 0
	nuke.PreThruster.PlaybackSpeed = 0.1

	TweenService:Create(nuke.PreThruster, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = 1,
		PlaybackSpeed = 0.5
	}):Play()

	TweenService:Create(thrustEmitPoint.SmokePreLaunch, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rate = 100
	}):Play()

	task.wait(5)

	cameraShaker:ShakeSustain(CameraShaker.Presets.Earthquake)
	nuke.Sparkles.Enabled = true
	thrustEmitPoint.SmokePreLaunch.Enabled = false
	thrustEmitPoint.SmokeLaunch:Emit(50)
	nuke.AlignPosition.Responsiveness = 25
	nuke.AlignOrientation.Responsiveness = 25
	nuke.PreLaunch:Play()
	nuke.Thruster2:Play()

	TweenService:Create(nuke.Thruster2, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		PlaybackSpeed = 1.5,
		Volume = 3
	}):Play()

	TweenService:Create(nuke.PreThruster, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = 1,
		PlaybackSpeed = 1
	}):Play()

	for _, particle in pairs(thrustEmitPoint:GetChildren()) do
		if not string.find(particle.Name, "Flame") then
			particle.Enabled = true
		end
	end

	thrustEmitPoint.SmokeRing.Enabled = false
	thrustEmitPoint.SmokeLaunch.Enabled = false
	thrustEmitPoint.Shockwave.Enabled = false
	thrustEmitPoint.BigShockwave.Enabled = false
	thrustEmitPoint.Flare.Enabled = false

	centerEmitPoint.Rays1.Enabled = true
	centerEmitPoint.Rays2.Enabled = true
	centerEmitPoint.Rays3.Enabled = true

	for i = 1, 10 do
		nukeCFrame.Value = nukeCFrame.Value:ToWorldSpace(CFrame.Angles(0, 0, 0.17453292519943295))
		nukeCFrame.Value = nukeCFrame.Value:ToWorldSpace(CFrame.new(0, 25, 0))
		task.wait(i * 0.0125)
	end

	nuke.AlignPosition.Responsiveness = 10
	nuke.AlignOrientation.Responsiveness = 10
	nukeCFrame.Value = CFrame.new(nukeCFrame.Value.Position, TARGET_POSITION):ToWorldSpace(CFrame.Angles(-1.5707963267948966, 0, 0))

	task.wait(0.5)

	bloomEffect.Intensity = 1
	bloomEffect.Size = 20

	TweenService:Create(bloomEffect, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Intensity = -1,
		Size = 10
	}):Play()

	nuke.AlignPosition.Responsiveness = 50
	nuke.AlignOrientation.Responsiveness = 50
	thrustEmitPoint.SmokeRing:Emit(50)
	thrustEmitPoint.Flame:Emit(25)
	thrustEmitPoint.Flame2:Emit(25)
	thrustEmitPoint.Flame3:Emit(25)
	thrustEmitPoint.Flame4:Emit(25)
	thrustEmitPoint.Flame5:Emit(25)
	thrustEmitPoint.Shockwave.Enabled = true
	thrustEmitPoint.BigShockwave:Emit(1)
	nuke.Launch:Play()
	nuke.Thruster:Play()

	for _, particle in pairs(thrustEmitPoint:GetChildren()) do
		particle.Enabled = true
	end

	thrustEmitPoint.SmokeRing.Enabled = false
	thrustEmitPoint.SmokeLaunch.Enabled = false
	thrustEmitPoint.BigShockwave.Enabled = false
	thrustEmitPoint.Flare:Emit(10)

	TweenService:Create(nukeCFrame, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Value = CFrame.new(TARGET_POSITION + Vector3.new(0, -1, 0), TARGET_POSITION):ToWorldSpace(CFrame.Angles(1.5707963267948966, 0, 0))
	}):Play()

	task.wait(2.6)

	cameraShaker:StopSustained(0)
	cameraShaker:ShakeOnce(4, 6, 0.25, 4)
	script.Alarm:Stop()

	bloomEffect.Intensity = 1
	bloomEffect.Size = 30

	TweenService:Create(bloomEffect, TweenInfo.new(5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {
		Intensity = -1,
		Size = 10
	}):Play()

	nuke.Anchored = true
	nuke.Transparency = 1
	nuke.Size = Vector3.new(0, 0, 0)
	nuke.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	nuke.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	nuke.CFrame = nukeCFrame.Value
	nuke.PreThruster:Stop()
	nuke.Thruster:Stop()
	nuke.Thruster2:Stop()
	nuke.Explosion.TimePosition = 0.75
	nuke.Explosion:Play()
	nuke.ChimeLoop:Play()
	nuke.ApplauseLoop:Play()
	nuke.CoinsLoop:Play()

	-- Update text
	local prefix = (currency == "Rupiah" and "Rp " or "R$")
	local formattedAmount = tostring(amount):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
	uiFrame.TextLabels.TopText.Text = "@" .. donorName .. " DONATED"
	uiFrame.TextLabels.MiddleText.Text = prefix .. formattedAmount
	uiFrame.TextLabels.BottomText.Text = "TO @" .. recipientName

	uiFrame.RobuxLogo.Size = UDim2.fromScale(0, 0)
	uiFrame.RobuxLogo.Rotation = -180
	uiFrame.Star.Size = UDim2.fromScale(0, 0)
	uiFrame.TextLabels.BottomText.Size = UDim2.fromScale(0, 0)
	uiFrame.TextLabels.BottomText.Position = UDim2.fromScale(0.5, 0.5)
	uiFrame.TextLabels.MiddleText.Size = UDim2.fromScale(0, 0)
	uiFrame.TextLabels.MiddleText.Position = UDim2.fromScale(0.5, 0.5)
	uiFrame.TextLabels.TopText.Position = UDim2.fromScale(0.5, 0.5)
	uiFrame.TextLabels.TopText.Size = UDim2.fromScale(0, 0)
	uiFrame.Parent.Enabled = true

	TweenService:Create(nuke, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = TARGET_POSITION + Vector3.new(0, 250, 0)
	}):Play()

	TweenService:Create(uiFrame.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1)
	}):Play()

	TweenService:Create(uiFrame.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Rotation = 0
	}):Play()

	TweenService:Create(uiFrame.Star, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.5, 1.5)
	}):Play()

	TweenService:Create(uiFrame.Star, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 360
	}):Play()

	TweenService:Create(uiFrame.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
		ImageTransparency = 1,
		ImageColor3 = Color3.fromRGB(255, 255, 0)
	}):Play()

	uiFrame.TextLabels.TopText.TextWrapped    = false
	uiFrame.TextLabels.MiddleText.TextWrapped = false
	uiFrame.TextLabels.BottomText.TextWrapped = false

	uiFrame.TextLabels.TopText.AnchorPoint    = Vector2.new(0.5, 0.5)
	uiFrame.TextLabels.MiddleText.AnchorPoint = Vector2.new(0.5, 0.5)
	uiFrame.TextLabels.BottomText.AnchorPoint = Vector2.new(0.5, 0.5)

		-- Pastikan Badge Lingkaran Tengah berbentuk bulat sempurna (Circle)
	if uiFrame:FindFirstChild("RobuxLogo") and uiFrame.RobuxLogo:FindFirstChild("Fill") then
		local fill = uiFrame.RobuxLogo.Fill
		local corner = fill:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", fill)
		corner.CornerRadius = UDim.new(1, 0)
		local arc = fill:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint", fill)
		arc.AspectRatio = 1
	end

	uiFrame.TextLabels.TopText.TextScaled     = true
	uiFrame.TextLabels.MiddleText.TextScaled  = true
	uiFrame.TextLabels.BottomText.TextScaled  = true

	TweenService:Create(uiFrame.TextLabels.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2), {
		Size = UDim2.fromScale(3.5, 0.18),
		Position = UDim2.fromScale(0.5, 0.20)
	}):Play()

	TweenService:Create(uiFrame.TextLabels.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.4), {
		Size = UDim2.fromScale(3.8, 0.40),
		Position = UDim2.fromScale(0.5, 0.50)
	}):Play()

	TweenService:Create(uiFrame.TextLabels.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.6), {
		Size = UDim2.fromScale(3.5, 0.18),
		Position = UDim2.fromScale(0.5, 0.81)
	}):Play()

	for _, particle in pairs(thrustEmitPoint:GetChildren()) do
		particle.Enabled = false
	end

	nuke.Sparkles.Enabled = false

	for _, particle in pairs(centerEmitPoint:GetChildren()) do
		particle.Enabled = false
	end

	centerEmitPoint.SparkleExplosion:Emit(100)
	centerEmitPoint.Shockwave:Emit(15)
	centerEmitPoint.FractalBurst:Emit(3)
	centerEmitPoint.RaysBig:Emit(20)
	centerEmitPoint.Spark1:Emit(100)
	centerEmitPoint.Spark2:Emit(100)
	centerEmitPoint.Spark3:Emit(50)

	-- Confetti / aksesoris berjatuhan (Robux, Confetti, Sparkles)
	confettiBox.Position = TARGET_POSITION + Vector3.new(0, 250, 0)

	TweenService:Create(confettiBox, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1000, 100, 1000)
	}):Play()

	-- Status aktifnya aksesoris yang berjatuhan & kembang api
	local isFallingActive = true
	local rocketTemplate = script.Scripts.SpawnFireworks:FindFirstChild("FireworksRocket")
	local spreadDist = (script.Scripts.SpawnFireworks:FindFirstChild("SpreadDistance") and script.Scripts.SpawnFireworks.SpreadDistance.Value) or 150

	-- 1. Aksesoris Berjatuhan
	task.spawn(function()
		local particles = confettiBox:GetChildren()
		for _, particle in pairs(particles) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
			end
		end

		-- Durasi aksesoris berjatuhan (35 detik perayaan)
		task.wait(35)

		-- STOP EFEK BERJATUHAN: Matikan emitter
		isFallingActive = false -- Otomatis men-stop kembang api pada detik yang sama persis!

		for _, particle in pairs(particles) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end

		task.wait(8)
		if confettiBox and confettiBox.Parent then
			confettiBox.Size = Vector3.new(0, 0, 0)
		end
	end)

	-- 2. Kembang Api: Menembak HANYA SELAMA aksesoris berjatuhan (isFallingActive == true)
	-- Begitu efek berjatuhan habis/stop, kembang api LANGSUNG BERHENTI menembak!
	if rocketTemplate then
		task.spawn(function()
			while isFallingActive and effectFolder and effectFolder.Parent do
				launchFireworkRocket(rocketTemplate, TARGET_POSITION, spreadDist, effectFolder)
				task.wait(0.75)
			end
		end)
	end

	nuke.Sparks.Enabled = true
	centerEmitPoint.SparkleExplosion.Enabled = true

	TweenService:Create(nuke.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Rate = 0
	}):Play()

	TweenService:Create(centerEmitPoint.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Rate = 0
	}):Play()

	TweenService:Create(nuke.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Volume = 0,
		PlaybackSpeed = 0.75
	}):Play()

	TweenService:Create(nuke.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Volume = 0
	}):Play()

	TweenService:Create(nuke.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Volume = 0,
		PlaybackSpeed = 1
	}):Play()

	task.wait(35)

	local uiScale = uiFrame:FindFirstChildOfClass("UIScale") or uiFrame:FindFirstChild("UIScale")
	if uiScale then
		TweenService:Create(uiScale, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0
		}):Play()
	else
		TweenService:Create(uiFrame, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()
	end

	task.wait(10)
	uiFrame.Parent.Enabled = false

	cameraShaker:Stop()
	pcall(function() bloomEffect:Destroy() end)
	pcall(function() heartbeatConnection:Disconnect() end)

	-- Destroy entire folder at once cleanly
	pcall(function() effectFolder:Destroy() end)
end

local lastNukeTime = 0
effectsEvent.OnClientEvent:Connect(function(effectType, donorName, recipientName, amount, userId, currency)
	if isDonationEffectHidden() then
		return -- Hide Effect Donate aktif: Jangan putar efek sama sekali agar HP kentang tidak lag!
	end
	if effectType == "Nuke" then
		local now = os.clock()
		if now - lastNukeTime < 4 then
			return -- Debounce pencegah efek dobel!
		end
		lastNukeTime = now
		playNukeEffect(donorName, recipientName, amount, userId, currency)
	end
end)

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(player)
	if player == localPlayer then
		-- Clean up any active effects
		local activeEffects = workspace:FindFirstChild("ActiveEffects")
		if activeEffects then
			for _, effect in pairs(activeEffects:GetChildren()) do
				if string.find(effect.Name, "Nuke_") then
					effect:Destroy()
				end
			end
		end
	end
end)