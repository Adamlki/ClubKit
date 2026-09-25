local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer

local function isDonationEffectHidden()
	return _G.HideDonationEffects == true or (_G.IsDonationEffectsHidden and _G.IsDonationEffectsHidden() == true)
end

-- Config
local TARGET_POSITION = (workspace:FindFirstChild("EffectTarget") and workspace.EffectTarget.Position) or Vector3.new(-83.613, -25.66, -439.504)
local effectActive = false
local tickingActive = false

-- Get RemoteEvent
local effectsEvent = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("EffectsEvent")

-- Get VFX from ReplicatedStorage
local vfxFolder = ReplicatedStorage:WaitForChild("VFX")
local blackHoleTemplate = vfxFolder:WaitForChild("Templates"):WaitForChild("Blackhole")

-- Helper Functions
local function formatNumber(number)
	local formatted = tostring(number)
	while true do
		local newFormatted, replacements = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = newFormatted
		if replacements == 0 then
			break
		end
	end
	return formatted
end

local function tweenObject(object, duration, properties)
	TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quint), properties):Play()
end

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

-- Main Effect Function
local function playBlackHoleEffect(donorName, recipientName, amount, userId, currency)
	local targetPart = workspace:FindFirstChild("EffectTarget")
	local TARGET_POSITION = (targetPart and targetPart.Position) or Vector3.new(-83.613, -25.66, -439.504)
	-- ✅ FIXED: Removed isEffectRunning check - server queue handles this

	-- Simpan nilai lighting original saat effect dimulai
	local savedClockTime = Lighting.ClockTime
	local savedFogColor = Lighting.FogColor
	local savedBrightness = Lighting.Brightness

	-- Simpan ColorCorrection original jika ada
	local originalColorCorrection = Lighting:FindFirstChild("ColorCorrection")
	local savedCCBrightness = nil
	local savedCCContrast = nil
	local savedCCSaturation = nil
	local savedCCTintColor = nil

	if originalColorCorrection and originalColorCorrection:IsA("ColorCorrectionEffect") then
		savedCCBrightness = originalColorCorrection.Brightness
		savedCCContrast = originalColorCorrection.Contrast
		savedCCSaturation = originalColorCorrection.Saturation
		savedCCTintColor = originalColorCorrection.TintColor
	end

	-- Create effect folder in workspace
	local activeEffects = workspace:FindFirstChild("ActiveEffects") or workspace
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "BlackHole_" .. tick()
	effectFolder.Parent = activeEffects
	game:GetService("CollectionService"):AddTag(effectFolder, "DonationEffect")

	effectFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end)

	-- Hard Safety Timeout (65s)
	task.delay(65, function()
		if effectFolder and effectFolder.Parent then
			pcall(function() effectFolder:Destroy() end)
		end
	end)

	local meteorRainActive = true
	local CameraShaker = require(script.CameraShaker)

	-- Clone VFX from ReplicatedStorage
	local vfxTemplate = blackHoleTemplate:Clone()
	local objects = vfxTemplate.Objects

	-- Get all components
	local npcModel = objects.NPC:Clone()
	local floorAmbiance = objects.FloorAmbiance:Clone()
	local ambiance = objects.Ambiance:Clone()
	local impactVisuals = objects.ImpactVisuals
	local heavenBall = objects.Heavenball:Clone()
	local whitehole1 = objects.Whitehole:Clone()
	local whitehole2 = objects.Whitehole2:Clone()
	local whitehole3 = objects.Whitehole3:Clone()
	local whitehole4 = objects.Whitehole4:Clone()

	-- Get sounds
	local sounds = vfxTemplate.Sounds:Clone()
	sounds.Parent = effectFolder

	-- Create lighting effects
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Enabled = true
	colorCorrection.Name = "EventColorCorrection"
	colorCorrection.Parent = Lighting

	local bloomEffect = Instance.new("BloomEffect")
	bloomEffect.Enabled = true
	bloomEffect.Name = "SmiteBloom"
	bloomEffect.Size = 20
	bloomEffect.Threshold = 0.1
	bloomEffect.Intensity = -1
	bloomEffect.Parent = Lighting

	local randomRotation = math.random(-180, 180)

	-- Setup floor ambiance
	floorAmbiance.Position = TARGET_POSITION + Vector3.new(0, -0.5, 0)
	floorAmbiance.Parent = effectFolder

	TweenService:Create(floorAmbiance, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play()

	-- Setup sky ambiance
	ambiance.Position = TARGET_POSITION
	ambiance.Size = Vector3.new(1000, 1000, 1000)
	ambiance.CFrame = ambiance.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(randomRotation), 0.5235987755982988))
	ambiance.Position = ambiance.Position + ambiance.CFrame.UpVector * 600
	ambiance.Parent = effectFolder

	-- Create black hole portal
	local blackHoleOrb = objects.Orb:Clone()
	local meteorTemplate = objects.Meteor:Clone()

	local cameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
	end)

	TweenService:Create(colorCorrection, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = Color3.fromRGB(255, 128, 255),
		Brightness = 0.25,
		Saturation = 0.1,
		Contrast = 0.25
	}):Play()

	local portal = blackHoleOrb:Clone()
	portal.Parent = effectFolder
	portal.Position = TARGET_POSITION + Vector3.new(0, 110.3, 0)

	cameraShaker:Start()
	cameraShaker:ShakeSustain(CameraShaker.Presets.Earthquake)

	-- Play ambiance sound
	local ambianceSound = sounds.Ambiance:Clone()
	ambianceSound.Parent = effectFolder
	ambianceSound:Play()

	-- Enable portal particles
	for _, particle in pairs(portal.Attachment:GetChildren()) do
		if particle:IsA("ParticleEmitter") then
			scaleParticleEmitter(particle, 1.75)
			particle.Enabled = true
		end
	end

	-- Enable floor particles
	for _, particle in pairs(floorAmbiance:GetChildren()) do
		if particle:IsA("ParticleEmitter") then
			scaleParticleEmitter(particle, 1.75)
			particle.Enabled = true
		end
	end

	-- Enable sky particles
	for _, particle in pairs(ambiance:GetChildren()) do
		if particle:IsA("ParticleEmitter") then
			scaleParticleEmitter(particle, 2.5)
			particle.Enabled = true
		end
	end

	-- Meteor rain system
	meteorRainActive = true
	local meteorInterval = 0.5

	task.spawn(function()
		while meteorRainActive do
			task.wait(meteorInterval)
			task.spawn(function()
				local scale = math.random(100, 400) / 100
				local fallDuration = math.random(250, 400) / 100
				local height = math.random(500, 750)

				local meteor = meteorTemplate:Clone()
				meteor.Parent = effectFolder
				meteor.Transparency = 1
				meteor.Position = TARGET_POSITION + Vector3.new(math.random(-750, 750), 0, math.random(-750, 750))
				meteor.Size = meteor.Size * scale
				meteor.CFrame = meteor.CFrame:ToWorldSpace(CFrame.Angles(
					math.rad(math.random(-10, 10)),
					math.rad(randomRotation),
					0.5235987755982988
					))
				meteor.Position = meteor.Position + meteor.CFrame.UpVector * height

				-- Setup meteor particles
				for _, descendant in pairs(meteor:GetDescendants()) do
					if descendant:IsA("ParticleEmitter") then
						scaleParticleEmitter(descendant, scale)
						if string.find(descendant.Name, "Meteor_") then
							descendant.Enabled = true
						end
					end
				end

				meteor.Glow.Range = meteor.Glow.Range * scale
				meteor.Glow.Enabled = true
				meteor.Trail0.Position = meteor.Trail0.Position * (scale / 2)
				meteor.Trail1.Position = meteor.Trail1.Position * (scale / 2)
				meteor.Trail.Enabled = true
				meteor.Whoosh.Volume = 0
				meteor.Whoosh.TimePosition = math.random(0, meteor.Whoosh.TimeLength)
				meteor.Whoosh.PlaybackSpeed = 1.5 - scale * 0.15
				meteor.Impact.PlaybackSpeed = 1.5 - scale * 0.15
				meteor.Whoosh.Playing = true

				TweenService:Create(meteor, TweenInfo.new(fallDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Position = meteor.Position + meteor.CFrame.UpVector * -height,
					Orientation = Vector3.new(
						math.random(-180, 180) * 3,
						math.random(-180, 180) * 3,
						math.random(-180, 180) * 3
					)
				}):Play()

				TweenService:Create(meteor, TweenInfo.new(fallDuration * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0
				}):Play()

				TweenService:Create(meteor.Whoosh, TweenInfo.new(fallDuration * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Volume = 1
				}):Play()

				task.wait(fallDuration)

				meteor.Transparency = 1
				meteor.Orientation = Vector3.new(0, 0, 0)
				meteor.Glow.Range = meteor.Glow.Range * 1.5
				meteor.Glow.Brightness = meteor.Glow.Brightness * 3

				TweenService:Create(meteor.Glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Brightness = 0,
					Range = meteor.Glow.Range / 2
				}):Play()

				for _, descendant in pairs(meteor:GetDescendants()) do
					if descendant:IsA("ParticleEmitter") then
						if string.find(descendant.Name, "Meteor_") then
							descendant.Enabled = false
						end
						if string.find(descendant.Name, "Explosion_") then
							descendant:Emit(descendant:GetAttribute("EmitCount"))
						end
					end
				end

				meteor.Trail.Enabled = false
				meteor.Whoosh.Playing = false
				meteor.Impact:Play()

				task.wait(3)
				meteor:Destroy()
			end)
		end
	end)

	-- Portal opening sequence
	task.spawn(function()
		sounds.Summon:Play()
		sounds.Earthquake:Play()
		portal.PortalAmbiance.Playing = true
		portal.PortalOpen1:Play()
		portal.PortalOpen2:Play()

		TweenService:Create(portal.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Volume = 1.5,
			PlaybackSpeed = 1.25
		}):Play()

		TweenService:Create(portal, TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = Vector3.new(50, 50, 50)
		}):Play()

		sounds.CrumbleLoop.Playing = true
		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.5
		}):Play()

		sounds.FireLoop.Playing = true
		TweenService:Create(sounds.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.5,
			PlaybackSpeed = 1
		}):Play()

		cameraShaker:ShakeSustain(CameraShaker.Presets.Earthquake)

		task.wait(7)

		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0
		}):Play()

		cameraShaker:StopSustained(6)

		TweenService:Create(portal.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Volume = 0,
			PlaybackSpeed = 0
		}):Play()
	end)

	-- Heaven ball sequence
	task.wait(math.random(14, 19))

	whitehole1.Parent = effectFolder
	whitehole2.Parent = effectFolder
	whitehole3.Parent = effectFolder
	whitehole4.Parent = effectFolder

	heavenBall.Parent = effectFolder
	local chargeSound = sounds.Charge_2:Clone()
	chargeSound.Parent = heavenBall
	chargeSound:Play()

	task.wait(1.25)
	effectActive = true

	if effectActive then
		tweenObject(heavenBall, 6, {Transparency = 0})

		local endingSound = sounds.ChargeEndSound:Clone()
		endingSound.Parent = heavenBall
		endingSound:Play()

		task.wait(1.5)

		whitehole1:Destroy()
		whitehole2:Destroy()
		whitehole3:Destroy()
		whitehole4:Destroy()
		chargeSound:Destroy()
		endingSound:Destroy()

		sounds.Twinkle:Play()

		TweenService:Create(heavenBall, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = TARGET_POSITION + Vector3.new(-306.869, 8.731, -57.885)
		}):Play()

		task.wait(1.25)
		effectActive = false
	end

	if not effectActive then
		TweenService:Create(heavenBall, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = Vector3.new(50, 50, 50)
		}):Play()

		sounds.CrumbleLoop.Playing = true
		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.5
		}):Play()

		sounds.Sparkle:Play()
		cameraShaker:ShakeSustain(CameraShaker.Presets.Earthquake)

		task.wait(3)
		tickingActive = true
	end

	-- Time tick effect dengan smooth transition
	if tickingActive then
		local tickSound = sounds.Tick:Clone()
		tickSound.Parent = effectFolder
		tickSound.Playing = true

		for i = 1, 8 do
			-- Tween ke siang
			TweenService:Create(Lighting, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				ClockTime = 10,
				FogColor = Color3.fromRGB(144, 228, 248)
			}):Play()
			task.wait(1)

			-- Tween ke malam
			TweenService:Create(Lighting, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				ClockTime = 0,
				FogColor = Color3.fromRGB(0, 0, 0)
			}):Play()
			task.wait(1)
		end

		-- Kembalikan lighting ke normal dengan smooth transition
		TweenService:Create(Lighting, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ClockTime = savedClockTime,
			FogColor = savedFogColor
		}):Play()

		tickSound:Stop()
		tickSound:Destroy()
		task.wait(5)
		tickingActive = false
	end

	-- Final explosion sequence
	if not tickingActive then
		cameraShaker:StopSustained(6)

		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0
		}):Play()

		task.wait(1)

		TweenService:Create(portal, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = Vector3.new(75, 75, 75)
		}):Play()

		TweenService:Create(heavenBall, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = Vector3.new(74, 74, 74)
		}):Play()

		for _, particle in pairs(portal.Attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				scaleParticleEmitter(particle, 2)
			end
		end

		task.wait(10)

		for _, particle in pairs(portal.Attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				particle.Rate = 0
			end
		end

		cameraShaker:ShakeOnce(8, 20, 1, 6)

		-- Brighten beams
		for i = 1, 12 do
			local beam = portal.Beams:FindFirstChild("FlameEffect" .. i)
			if beam then
				TweenService:Create(beam, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
					Brightness = 1.57
				}):Play()
			end
		end

		TweenService:Create(Lighting, TweenInfo.new(1.7), {
			Brightness = 5
		}):Play()

		TweenService:Create(portal, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Position = TARGET_POSITION + Vector3.new(-237.393, 8.731, 33.516)
		}):Play()

		TweenService:Create(heavenBall, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Position = TARGET_POSITION + Vector3.new(-425.182, 11.243, -466.281)
		}):Play()

		portal.FlameEffect1_0.BrightFlare.Enabled = true
		portal.Flames.Enabled = true
		portal.FlameEffect1_0.FlameRing.Enabled = true
		portal.FlameEffect1_0.Flames1.Enabled = true
		portal.FlameEffect1_0.Flames2.Enabled = true
		portal.FlameEffect1_0.Flames3.Enabled = true

		sounds.Drop1:Play()
		sounds.Drop2:Play()
		portal.LaunchSound:Play()

		task.wait(1.7)

		sounds.ExplosionSound:Play()
		sounds.Sparkle:Stop()
		ambianceSound:Destroy()

		bloomEffect.Intensity = 0.75
		bloomEffect.Threshold = 0.05
		colorCorrection.Contrast = 0

		TweenService:Create(bloomEffect, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Intensity = -0.9,
			Threshold = 0.1
		}):Play()

		TweenService:Create(colorCorrection, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Contrast = 0.25
		}):Play()

		cameraShaker:ShakeOnce(12, 4, 1, 6)

		portal.SelectionSphere:Destroy()
		portal.FlameEffect1_0.BrightFlare.Enabled = false
		portal.Flames.Enabled = false
		portal.FlameEffect1_0.FlameRing.Enabled = false
		portal.FlameEffect1_0.Flames1.Enabled = false
		portal.FlameEffect1_0.Flames2.Enabled = false
		portal.FlameEffect1_0.Flames3.Enabled = false

		-- Reset beams
		for i = 1, 12 do
			local beam = portal.Beams:FindFirstChild("FlameEffect" .. i)
			if beam then
				TweenService:Create(beam, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
					Brightness = 0
				}):Play()
			end
		end

		TweenService:Create(Lighting, TweenInfo.new(0.2), {
			Brightness = 150
		}):Play()

		-- PERBAIKAN: Cek apakah ColorCorrection original ada
		if originalColorCorrection and originalColorCorrection:IsA("ColorCorrectionEffect") then
			TweenService:Create(originalColorCorrection, TweenInfo.new(0.05), {
				Brightness = 1.2
			}):Play()

			task.wait(0.05)

			TweenService:Create(originalColorCorrection, TweenInfo.new(3), {
				Brightness = 0.05
			}):Play()
		end

		TweenService:Create(Lighting, TweenInfo.new(7), {
			Brightness = 2.66
		}):Play()

		-- Display donation UI
		impactVisuals.Parent = effectFolder
		impactVisuals.Position = TARGET_POSITION

		TweenService:Create(impactVisuals, TweenInfo.new(30), {
			Position = TARGET_POSITION + Vector3.new(0, 400, 0)
		}):Play()

		impactVisuals.ApplauseLoop:Play()
		impactVisuals.CoinsLoop:Play()
		impactVisuals.ChimeLoop:Play()

		impactVisuals.EmitPoint.Impact_Spark1:Emit(45)
		impactVisuals.EmitPoint.Impact_Spark2:Emit(75)
		impactVisuals.EmitPoint.Impact_Spark3:Emit(35)
		impactVisuals.EmitPoint.Explosion_Glow:Emit(25)
		impactVisuals.EmitPoint.Explosion_Rays:Emit(45)
		impactVisuals.EmitPoint.Explosion_Ring:Emit(5)
		impactVisuals.EmitPoint.Explosion_Flare:Emit(50)
		impactVisuals.EmitPoint.Explosion_ThinRays:Emit(35)
		impactVisuals.EmitPoint.Explosion_Shockwave:Emit(15)

		local uiFrame = impactVisuals.BillboardGuiAnimation.Frame

		uiFrame.RobuxLogo.Size = UDim2.fromScale(0, 0)
		uiFrame.Star.Size = UDim2.fromScale(0, 0)
		uiFrame.TopText.Size = UDim2.fromScale(0, 0)
		uiFrame.MiddleText.Size = UDim2.fromScale(0, 0)
		uiFrame.BottomText.Size = UDim2.fromScale(0, 0)
		uiFrame.TopText.Position = UDim2.fromScale(0.5, 0.5)
		uiFrame.MiddleText.Position = UDim2.fromScale(0.5, 0.5)
		uiFrame.BottomText.Position = UDim2.fromScale(0.5, 0.5)
		uiFrame.TopText.AnchorPoint = Vector2.new(0.5, 0.5)
		uiFrame.MiddleText.AnchorPoint = Vector2.new(0.5, 0.5)
		uiFrame.BottomText.AnchorPoint = Vector2.new(0.5, 0.5)
		uiFrame.TopText.TextWrapped = false
		uiFrame.MiddleText.TextWrapped = false
		uiFrame.BottomText.TextWrapped = false
		uiFrame.RobuxLogo.Rotation = -180
		uiFrame.Star.Rotation = 0
		uiFrame.Star.ImageTransparency = 0.9

		-- Update text
		local prefix = (currency == "Rupiah" and "Rp " or "R$")
		uiFrame.TopText.Text = "@" .. donorName .. " DONATED"
		uiFrame.MiddleText.Text = prefix .. formatNumber(amount)
		uiFrame.BottomText.Text = "TO @" .. recipientName

		TweenService:Create(uiFrame.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1, 1)
		}):Play()

		TweenService:Create(uiFrame.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Rotation = 0
		}):Play()

		TweenService:Create(uiFrame.Star, TweenInfo.new(10), {
			Rotation = 360
		}):Play()

		TweenService:Create(uiFrame.Star, TweenInfo.new(10), {
			ImageTransparency = 1
		}):Play()

		task.wait(0.25)
		uiFrame.TopText.TextWrapped    = false
		uiFrame.MiddleText.TextWrapped = false
		uiFrame.BottomText.TextWrapped = false

		uiFrame.TopText.AnchorPoint    = Vector2.new(0.5, 0.5)
		uiFrame.MiddleText.AnchorPoint = Vector2.new(0.5, 0.5)
		uiFrame.BottomText.AnchorPoint = Vector2.new(0.5, 0.5)

				-- Pastikan Badge Lingkaran Tengah berbentuk bulat sempurna (Circle)
		if uiFrame:FindFirstChild("RobuxLogo") and uiFrame.RobuxLogo:FindFirstChild("Fill") then
			local fill = uiFrame.RobuxLogo.Fill
			local corner = fill:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", fill)
			corner.CornerRadius = UDim.new(1, 0)
			local arc = fill:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint", fill)
			arc.AspectRatio = 1
		end

		uiFrame.TopText.TextScaled     = true
		uiFrame.MiddleText.TextScaled  = true
		uiFrame.BottomText.TextScaled  = true

		TweenService:Create(uiFrame.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(3.5, 0.18),
			Position = UDim2.fromScale(0.5, 0.20)
		}):Play()

		task.wait(0.25)
		TweenService:Create(uiFrame.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(3.8, 0.40),
			Position = UDim2.fromScale(0.5, 0.50)
		}):Play()

		task.wait(0.25)
		TweenService:Create(uiFrame.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(3.5, 0.18),
			Position = UDim2.fromScale(0.5, 0.81)
		}):Play()

		meteorRainActive = false

		TweenService:Create(portal, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()

		TweenService:Create(heavenBall, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()

		impactVisuals.EmitPoint.Sparks.Enabled = true
		impactVisuals.EmitPoint.SparkleExplosion.Enabled = true

		task.wait(1)
		pcall(function() heavenBall:Destroy() end)
		pcall(function() portal:Destroy() end)

		TweenService:Create(impactVisuals.ChimeLoop, TweenInfo.new(40), {Volume = 0}):Play()
		TweenService:Create(impactVisuals.ApplauseLoop, TweenInfo.new(40), {Volume = 0}):Play()
		TweenService:Create(impactVisuals.CoinsLoop, TweenInfo.new(30), {Volume = 0}):Play()

		-- Teks donasi mengambang selama 35 detik (standar, jelas dan terbaca)
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

		for _, particle in pairs(impactVisuals.EmitPoint:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				TweenService:Create(particle, TweenInfo.new(8), {Rate = 0}):Play()
			end
		end

		TweenService:Create(sounds.FireLoop, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0,
			PlaybackSpeed = 0.5
		}):Play()

		if floorAmbiance and floorAmbiance.Parent then
			for _, particle in pairs(floorAmbiance:GetChildren()) do
				if particle:IsA("ParticleEmitter") then
					TweenService:Create(particle, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rate = 0
					}):Play()
				end
			end
		end

		if ambiance and ambiance.Parent then
			for _, particle in pairs(ambiance:GetChildren()) do
				if particle:IsA("ParticleEmitter") then
					TweenService:Create(particle, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rate = 0
					}):Play()
				end
			end
		end

		TweenService:Create(colorCorrection, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TintColor = Color3.fromRGB(255, 255, 255),
			Brightness = 0,
			Saturation = 0,
			Contrast = 0
		}):Play()

		TweenService:Create(bloomEffect, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Intensity = -1
		}):Play()

		TweenService:Create(Lighting, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Brightness = savedBrightness
		}):Play()

		if originalColorCorrection and originalColorCorrection:IsA("ColorCorrectionEffect") and savedCCBrightness then
			TweenService:Create(originalColorCorrection, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Brightness = savedCCBrightness,
				Contrast = savedCCContrast,
				Saturation = savedCCSaturation,
				TintColor = savedCCTintColor
			}):Play()
		end

		task.wait(9)

		cameraShaker:Stop()
		pcall(function() colorCorrection:Destroy() end)
		pcall(function() bloomEffect:Destroy() end)
		pcall(function() sounds:Destroy() end)
		pcall(function() if floorAmbiance and floorAmbiance.Parent then floorAmbiance:Destroy() end end)
		pcall(function() if ambiance and ambiance.Parent then ambiance:Destroy() end end)
		pcall(function() if vfxTemplate and vfxTemplate.Parent then vfxTemplate:Destroy() end end)
		pcall(function() if effectFolder and effectFolder.Parent then effectFolder:Destroy() end end)
	end
end

local lastBlackHoleTime = 0
effectsEvent.OnClientEvent:Connect(function(effectType, donorName, recipientName, amount, userId, currency)
	if isDonationEffectHidden() then
		return -- Hide Effect Donate aktif: Jangan putar efek sama sekali agar HP kentang tidak lag!
	end
	if effectType == "BlackHole" or effectType == "Blackhole" then
		local now = os.clock()
		if now - lastBlackHoleTime < 4 then
			return -- Debounce pencegah efek dobel!
		end
		lastBlackHoleTime = now
		playBlackHoleEffect(donorName, recipientName, amount, userId, currency)
	end
end)

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(player)
	if player == localPlayer then
		-- Clean up any active effects
		local activeEffects = workspace:FindFirstChild("ActiveEffects")
		if activeEffects then
			for _, effect in pairs(activeEffects:GetChildren()) do
				if string.find(effect.Name, "BlackHole_") then
					effect:Destroy()
				end
			end
		end
	end
end)