local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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
local smiteTemplate = vfxFolder:WaitForChild("Templates"):WaitForChild("Smite")

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

local GIANT_SCALE_MULTIPLIER = 53

local function setGiantAppearance(userId, giantModel)
	local humanoid = giantModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local descSuccess, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)

	if not descSuccess or not description then
		return false
	end

	-- PENTING: jangan kalikan HeightScale/WidthScale/DepthScale/HeadScale di sini.
	-- Roblox punya bug dimana layered clothing (Jacket/TShirt/Pants/Shoes) hilang
	-- atau gagal ikut scale kalau nilai-nilai ini > 5. Jadi description dipakai
	-- apa adanya (ukuran asli player), lalu perbesaran *10 dilakukan lewat
	-- giantModel:ScaleTo() setelah appearance & accessories ter-load penuh.
	local applySuccess = pcall(function()
		humanoid:ApplyDescription(description)
	end)

	return applySuccess
end

local randomRotation = math.random(-180, 180)

-- Main Effect Function
local function playSmiteEffect(donorName, recipientName, amount, userId, currency)
	local targetPart = workspace:FindFirstChild("EffectTarget")
	local TARGET_POSITION = (targetPart and targetPart.Position) or Vector3.new(-83.613, -25.66, -439.504)
	-- ✅ FIXED: Removed isEffectRunning check - server queue handles this

	-- Create effect folder in workspace
	local activeEffects = workspace:FindFirstChild("ActiveEffects") or workspace
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "Smite_" .. tick()
	effectFolder.Parent = activeEffects
	game:GetService("CollectionService"):AddTag(effectFolder, "DonationEffect")

	local function disableCollision(inst)
		if not inst then return end
		if inst:IsA("BasePart") then
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
		end
		for _, part in ipairs(inst:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
	end

	effectFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end)

	local CameraShaker = require(script.CameraShaker)

	-- Clone main components from ReplicatedStorage
	local giantModel = smiteTemplate:Clone()
	local diamondHammer = giantModel.DiamondHammer

	-- Make everything invisible initially (except hammer parts that will be used)
	for _, descendant in pairs(giantModel:GetDescendants()) do
		if (descendant:IsA("BasePart") or descendant:IsA("Decal")) and descendant.Name ~= "HumanoidRootPart" and 
			(descendant:IsDescendantOf(diamondHammer) == false or descendant:IsDescendantOf(giantModel.Objects) == false) then
			descendant.Transparency = 1
		end
	end

	-- Scale particles
	scaleParticleEmitter(diamondHammer.Handle.MainDiamondCenter.Shockwave, 60)
	scaleParticleEmitter(diamondHammer.Handle.MainDiamondCenter.ChargeGlow, 50)
	scaleParticleEmitter(diamondHammer.Handle.MainDiamondCenter.ChargeRays, 50)
	scaleParticleEmitter(diamondHammer.Handle.BaseFrontOffset.Shockwave, 10)

	diamondHammer.Handle.Transparency = 1
	diamondHammer.Handle.Diamonds.Transparency = 1
	diamondHammer.Handle.CanCollide = false

	giantModel.Parent = effectFolder

	local meteorTemplate = giantModel.Objects.Meteor:Clone()
	local floorAmbiance = giantModel.Objects.FloorAmbiance:Clone()
	local ambiance = giantModel.Objects.Ambiance:Clone()
	local impactVisuals = giantModel.Objects.ImpactVisuals:Clone()
	local portal = giantModel.Objects.Portal:Clone()

	giantModel.Objects:Destroy()

	local sounds = giantModel.Sounds
	sounds.Parent = workspace
	sounds.Name = "SmiteDonationEffect_Sounds"

	local animator = giantModel.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", giantModel.Humanoid)
	local animation = animator:LoadAnimation(giantModel.Animations.Giant_MainAnimation)

	-- Create lighting effects
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Enabled = true
	colorCorrection.Name = "SmiteColorCorrection"
	colorCorrection.Parent = game.Lighting

	local bloomEffect = Instance.new("BloomEffect")
	bloomEffect.Enabled = true
	bloomEffect.Name = "SmiteBloom"
	bloomEffect.Size = 20
	bloomEffect.Threshold = 0.1
	bloomEffect.Intensity = -1
	bloomEffect.Parent = game.Lighting

	local cameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
	end)

	cameraShaker:Start()

	-- Position giant
	giantModel.PrimaryPart = giantModel.FloorLevel
	giantModel:SetPrimaryPartCFrame(CFrame.new(TARGET_POSITION.X, TARGET_POSITION.Y, TARGET_POSITION.Z))
	giantModel:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(math.random(-180, 180)), 0)))
	giantModel:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(CFrame.new(25, 0, 365)))
	giantModel.PrimaryPart = giantModel.HumanoidRootPart

	-- Setup portal
	local portalClone = portal:Clone()
	portal.PortalAmbiance.Volume = 0
	portal.PortalAmbiance.PlaybackSpeed = 0
	portalClone.CFrame = giantModel.FloorLevel.CFrame
	portalClone.Parent = effectFolder
	giantModel.FloorLevel:Destroy()

	-- Setup eye attachments
	local leftEyeAttachment = giantModel.Head.LeftEyeAttachment
	local rightEyeAttachment = giantModel.Head.RightEyeAttachment
	leftEyeAttachment.Parent = nil
	rightEyeAttachment.Parent = nil
	diamondHammer.Parent = nil

	-- Set giant appearance using improved method
	local appearanceSuccess = setGiantAppearance(userId, giantModel)

	-- Scale seluruh body + clothing + accessories bareng-bareng (bukan lewat
	-- HumanoidDescription, biar Jacket/TShirt/Pants/Shoes ikut ke-scale dengan benar).
	-- Dilakukan SEBELUM diamondHammer/eye attachment di-reattach, supaya prop-prop
	-- itu tetap pakai ukuran template aslinya dan tidak ikut kena scale dobel.
	pcall(function()
		giantModel:ScaleTo(GIANT_SCALE_MULTIPLIER)
	end)

	-- Reattach hammer and eyes
	diamondHammer.Parent = giantModel
	diamondHammer.Weld.Attachment0 = giantModel.RightHand.RightGripAttachment
	leftEyeAttachment.Parent = giantModel.Head
	rightEyeAttachment.Parent = giantModel.Head
	leftEyeAttachment.Position = Vector3.new(-6, 11, -32)
	rightEyeAttachment.Position = Vector3.new(6, 11, -32)

	-- Portal opening
	sounds.Summon:Play()
	portalClone.Transparency = 0
	portalClone.Sparks.Enabled = true
	portalClone.Appearance.Enabled = true

	TweenService:Create(portalClone.Sparks, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Rate = 40
	}):Play()

	TweenService:Create(portalClone.Appearance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Rate = 40
	}):Play()

	TweenService:Create(portalClone, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(400, 1, 400)
	}):Play()

	TweenService:Create(portalClone.OuterLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Width0 = 400,
		Width1 = 600
	}):Play()

	TweenService:Create(portalClone.InnerLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Width0 = 200,
		Width1 = 300
	}):Play()

	portalClone.PortalAmbiance.Playing = true
	portalClone.PortalOpen1:Play()
	portalClone.PortalOpen2:Play()

	TweenService:Create(portalClone.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Volume = 0.5,
		PlaybackSpeed = 1.25
	}):Play()

	-- Meteor rain system
	local meteorRainActive = true
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

				for _, descendant in pairs(meteor:GetDescendants()) do
					if descendant:IsA("ParticleEmitter") then
						scaleParticleEmitter(descendant, scale)
						if string.find(descendant.Name, "Meteor_") then
							descendant.Enabled = true
						end
					end
				end

				local initGlow = meteor:FindFirstChild("Glow")
				if initGlow then
					initGlow.Range = initGlow.Range * scale
					initGlow.Enabled = true
				end
				if meteor:FindFirstChild("Trail0") then meteor.Trail0.Position = meteor.Trail0.Position * (scale / 2) end
				if meteor:FindFirstChild("Trail1") then meteor.Trail1.Position = meteor.Trail1.Position * (scale / 2) end
				if meteor:FindFirstChild("Trail") then meteor.Trail.Enabled = true end
				if meteor:FindFirstChild("Whoosh") then
					meteor.Whoosh.Volume = 0
					meteor.Whoosh.TimePosition = math.random(0, math.max(0, math.floor(meteor.Whoosh.TimeLength)))
					meteor.Whoosh.PlaybackSpeed = 1.5 - scale * 0.15
					meteor.Whoosh.Playing = true
				end
				if meteor:FindFirstChild("Impact") then
					meteor.Impact.PlaybackSpeed = 1.5 - scale * 0.15
				end

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
					Volume = 0.1
				}):Play()

				task.wait(fallDuration)

				meteor.Transparency = 1
				meteor.Orientation = Vector3.new(0, 0, 0)
				local glow = meteor:FindFirstChild("Glow")
				if glow then
					glow.Range = glow.Range * 1.5
					glow.Brightness = glow.Brightness * 3
					TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Brightness = 0,
						Range = glow.Range / 2
					}):Play()
				end

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

				if meteor:FindFirstChild("Trail") then meteor.Trail.Enabled = false end
				if meteor:FindFirstChild("Whoosh") then meteor.Whoosh.Playing = false end
				if meteor:FindFirstChild("Impact") then meteor.Impact:Play() end

				task.wait(3)
				meteor:Destroy()
			end)
		end
	end)

	-- Setup ambiance
	floorAmbiance.Position = TARGET_POSITION + Vector3.new(0, -0.5, 0)
	floorAmbiance.Parent = effectFolder

	TweenService:Create(floorAmbiance, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play()

	ambiance.Position = TARGET_POSITION
	ambiance.Size = Vector3.new(1000, 1000, 1000)
	ambiance.CFrame = ambiance.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(randomRotation), 0.5235987755982988))
	ambiance.Position = ambiance.Position + ambiance.CFrame.UpVector * 600
	ambiance.Parent = effectFolder

	task.spawn(function()
		for _, particle in pairs(floorAmbiance:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				scaleParticleEmitter(particle, 1.25)
				particle.Enabled = true
			end
		end

		for _, particle in pairs(ambiance:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				scaleParticleEmitter(particle, 1.75)
				particle.Enabled = true
			end
		end
	end)

	TweenService:Create(colorCorrection, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = Color3.fromRGB(255, 130, 108),
		Brightness = 0.1,
		Saturation = 0.1,
		Contrast = 0.15
	}):Play()

	TweenService:Create(bloomEffect, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Intensity = -0.95
	}):Play()

	-- Flame effect handler
	local function updateFlameEffect(transparency)
		local sequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, transparency),
			NumberSequenceKeypoint.new(1, 1)
		})

		for _, beam in pairs(diamondHammer.Effects.Beams:GetChildren()) do
			if beam:IsA("Beam") and string.find(beam.Name, "FlameEffect") then
				beam.Enabled = true
				beam.Transparency = sequence
			end
		end
	end

	local flameConnection = giantModel.Values.Hammer_FlameEffectTransparency.Changed:Connect(updateFlameEffect)
	updateFlameEffect(1)

	-- Marker Dispatcher & Fallback Engine
	local markerCallbacks = {}
	local triggeredMarkers = {}

	local function triggerMarker(name)
		if triggeredMarkers[name] then return end
		triggeredMarkers[name] = true
		local cb = markerCallbacks[name]
		if cb then
			task.spawn(cb)
		end
	end

	local function registerMarker(name, cb)
		markerCallbacks[name] = cb
		pcall(function()
			animation:GetMarkerReachedSignal(name):Connect(function()
				triggerMarker(name)
			end)
		end)
	end

	registerMarker("Eye lense flare", function()
		sounds.LenseFlareEyes:Play()
		giantModel.Head.LeftEyeAttachment.Flare.Enabled = true
		giantModel.Head.LeftEyeAttachment.FlareFlash:Emit(1)
		giantModel.Head.RightEyeAttachment.Flare.Enabled = true
		giantModel.Head.RightEyeAttachment.FlareFlash:Emit(1)
	end)

	registerMarker("HammerAppear", function()
		diamondHammer.Handle.AppearSound.Playing = true
		diamondHammer.Handle.AppearSound.Volume = 0
		diamondHammer.Handle.AppearSound.PlaybackSpeed = 0.75

		TweenService:Create(diamondHammer.Handle.AppearSound, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Volume = 0.1
		}):Play()

		TweenService:Create(diamondHammer.Handle.AppearSound, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			PlaybackSpeed = 1.5
		}):Play()

		diamondHammer.Handle.HammerBaseOutline.Sparkles.Enabled = true
		diamondHammer.Handle.HammerBaseOutline.Appearance.Enabled = true
		diamondHammer.Handle.HammerHandleBase.Appearance.Enabled = true

		TweenService:Create(diamondHammer.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Rate = 15
		}):Play()

		TweenService:Create(diamondHammer.Handle.HammerBaseOutline.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Rate = 30
		}):Play()

		TweenService:Create(diamondHammer.Handle.HammerHandleBase.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Rate = 25
		}):Play()

		TweenService:Create(diamondHammer.Handle, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Transparency = 0
		}):Play()

		TweenService:Create(diamondHammer.Handle.Diamonds, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Transparency = 0.1
		}):Play()
	end)

	registerMarker("ChargeSwing", function()
		diamondHammer.Handle.ChargeSound1:Play()
		diamondHammer.Handle.ChargeSound2:Play()
		diamondHammer.Handle.ChargeSound3:Play()
		diamondHammer.Handle.MainChargeSound:Play()

		for _, attachment in pairs(diamondHammer.Handle:GetChildren()) do
			if attachment:IsA("Attachment") and string.find(attachment.Name, "DiamondCenter") then
				attachment.Flare.Enabled = true
			end
		end

		diamondHammer.Handle.MainDiamondCenter.Shockwave:Emit(1)
		diamondHammer.Handle.MainDiamondCenter.ChargeGlow.Enabled = true
		diamondHammer.Handle.MainDiamondCenter.ChargeRays.Enabled = true

		TweenService:Create(diamondHammer.Handle.MainDiamondCenter.ChargeRays, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TimeScale = 1
		}):Play()

		TweenService:Create(diamondHammer.Handle.MainDiamondCenter.ChargeGlow, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TimeScale = 1
		}):Play()
	end)

	registerMarker("SwingStart", function()
		diamondHammer.Handle.ChargeEndSound:Play()
		diamondHammer.Handle.MainDiamondCenter.Shockwave:Emit(3)
		diamondHammer.Handle.MainDiamondCenter.ChargeGlow.Enabled = false
		diamondHammer.Handle.MainDiamondCenter.ChargeRays.Enabled = false

		TweenService:Create(diamondHammer.Handle.MainChargeSound, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Volume = 0.25
		}):Play()

		diamondHammer.Handle.BaseCenter.Wind.Volume = 0
		diamondHammer.Handle.BaseCenter.Wind.PlaybackSpeed = 0.5
		diamondHammer.Handle.BaseCenter.Wind.Playing = true

		TweenService:Create(diamondHammer.Handle.BaseCenter.Wind, TweenInfo.new(3.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Volume = 0.25,
			PlaybackSpeed = 2.5
		}):Play()

		TweenService:Create(giantModel.Values.Hammer_FlameEffectTransparency, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Value = 0
		}):Play()

		diamondHammer.Handle.HammerBase.Flames.Enabled = true
		diamondHammer.Handle.BaseFrontOffset.Shockwave.Enabled = true

		TweenService:Create(diamondHammer.Handle.HammerBase.Flames, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Rate = 20
		}):Play()

		TweenService:Create(diamondHammer.Handle.BaseFrontOffset.Shockwave, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Rate = 10
		}):Play()

		for _, trail in pairs(diamondHammer.Effects.Trails:GetChildren()) do
			trail.Enabled = true
		end
	end)

	registerMarker("SwingEnd", function()
		meteorInterval = 0.25
		diamondHammer.Handle.MainChargeSound:Stop()
		sounds.Rumble:Play()

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

		TweenService:Create(giantModel.Values.Hammer_FlameEffectTransparency, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = 1
		}):Play()

		diamondHammer.Handle.BaseFrontOffset.Shockwave.Enabled = false

		TweenService:Create(diamondHammer.Handle.HammerBase.Flames, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rate = 0
		}):Play()

		for _, trail in pairs(diamondHammer.Effects.Trails:GetChildren()) do
			trail.Enabled = false
		end

		diamondHammer.Handle.BaseCenter.Wind.Playing = false

		for _, sound in pairs(diamondHammer.Handle.BaseCenter:GetChildren()) do
			if sound:IsA("Sound") and string.find(sound.Name, "Impact_") then
				sound:Play()
			end
		end

		for _, attachment in pairs(diamondHammer.Handle:GetChildren()) do
			if attachment:IsA("Attachment") and string.find(attachment.Name, "DiamondCenter") then
				attachment.Flare.Enabled = false
			end
		end

		cameraShaker:ShakeOnce(6, 6, 0.25, 5)

		-- Impact visuals
		local impact = impactVisuals:Clone()
		impact.Position = TARGET_POSITION
		impact.Parent = effectFolder

		scaleParticleEmitter(impact.EmitPoint.Impact_FractalBurst, 10)
		scaleParticleEmitter(impact.EmitPoint.Impact_RaysBurst, 25)
		scaleParticleEmitter(impact.EmitPoint.Impact_Shockwave, 30)
		scaleParticleEmitter(impact.EmitPoint.Impact_Spark1, 10)
		scaleParticleEmitter(impact.EmitPoint.Impact_Spark2, 10)
		scaleParticleEmitter(impact.EmitPoint.Impact_Spark3, 10)
		scaleParticleEmitter(impact.EmitPoint.Impact_SparkleExplosion, 10)
		scaleParticleEmitter(impact.EmitPoint.SparkleExplosion, 7.5)
		scaleParticleEmitter(impact.EmitPoint.Sparks, 5)

		for _, particle in pairs(impact.EmitPoint:GetChildren()) do
			if particle:IsA("ParticleEmitter") and string.find(particle.Name, "Impact_") then
				particle:Emit(particle:GetAttribute("EmitCount"))
			end
		end

		impact.ApplauseLoop.Playing = true
		impact.ChimeLoop.Playing = true
		impact.CoinsLoop.Playing = true

		local uiFrame = impact.BillboardGuiAnimation.Frame
		uiFrame.TopText.Visible = true
		uiFrame.BottomText.Visible = true

		-- Update text
		local prefix = (currency == "Rupiah" and "Rp " or "R$")
		local formattedAmount = tostring(amount):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
		uiFrame.TopText.Text = "@" .. donorName .. " DONATED"
		uiFrame.MiddleText.Text = prefix .. formattedAmount
		uiFrame.BottomText.Text = "TO @" .. recipientName

		-- Anti-Overlap Layout: Pastikan teks 1 baris tanpa wrapping dan tidak tumpang-tindih
		uiFrame.TopText.TextWrapped    = false
		uiFrame.MiddleText.TextWrapped = false
		uiFrame.BottomText.TextWrapped = false

		uiFrame.TopText.AnchorPoint    = Vector2.new(0.5, 0.5)
		uiFrame.MiddleText.AnchorPoint = Vector2.new(0.5, 0.5)
		uiFrame.BottomText.AnchorPoint = Vector2.new(0.5, 0.5)

		uiFrame.RobuxLogo.Size         = UDim2.fromScale(0, 0)
		uiFrame.RobuxLogo.Rotation     = -180
		uiFrame.Star.Size              = UDim2.fromScale(0, 0)
		uiFrame.BottomText.Size        = UDim2.fromScale(0, 0)
		uiFrame.BottomText.Position    = UDim2.fromScale(0.5, 0.5)
		uiFrame.MiddleText.Size        = UDim2.fromScale(0, 0)
		uiFrame.MiddleText.Position    = UDim2.fromScale(0.5, 0.5)
		uiFrame.TopText.Position       = UDim2.fromScale(0.5, 0.5)
		uiFrame.TopText.Size           = UDim2.fromScale(0, 0)
		uiFrame.Parent.Enabled         = true

		TweenService:Create(impact, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = TARGET_POSITION + Vector3.new(0, 400, 0)
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

		-- Pastikan TextScaled selalu aktif agar teks membesar maksimal
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

		-- TopText: Y = 0.20, Height = 0.18, Width = 3.5 (Teks BESAR & jelas)
		TweenService:Create(uiFrame.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2), {
			Size = UDim2.fromScale(3.5, 0.18),
			Position = UDim2.fromScale(0.5, 0.20)
		}):Play()

		-- MiddleText: Y = 0.50, Height = 0.40, Width = 3.8 (Nominal SANGAT BESAR & menonjol, tanpa wrap)
		TweenService:Create(uiFrame.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.4), {
			Size = UDim2.fromScale(3.8, 0.40),
			Position = UDim2.fromScale(0.5, 0.50)
		}):Play()

		-- BottomText: Y = 0.81, Height = 0.18, Width = 3.5 (Teks BESAR & jelas)
		TweenService:Create(uiFrame.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.6), {
			Size = UDim2.fromScale(3.5, 0.18),
			Position = UDim2.fromScale(0.5, 0.81)
		}):Play()

		TweenService:Create(uiFrame.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
			ImageTransparency = 1,
			ImageColor3 = Color3.fromRGB(0, 255, 255)
		}):Play()

		impact.EmitPoint.Sparks.Enabled = true
		impact.EmitPoint.SparkleExplosion.Enabled = true

		TweenService:Create(impact.EmitPoint.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Rate = 0
		}):Play()

		TweenService:Create(impact.EmitPoint.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			Rate = 0
		}):Play()

		TweenService:Create(impact.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Volume = 0,
			PlaybackSpeed = 0.75
		}):Play()

		TweenService:Create(impact.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Volume = 0
		}):Play()

		TweenService:Create(impact.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Volume = 0,
			PlaybackSpeed = 1
		}):Play()

		-- Teks donasi mengambang gagah di udara selama 40 detik (cukup lama untuk dibaca semua orang)
		task.wait(40)

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

		-- SINKRON: Begitu teks donasi mulai mengecil, kembalikan langit merah & efek api ke normal!
		meteorRainActive = false

		TweenService:Create(sounds.FireLoop, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0,
			PlaybackSpeed = 0.5
		}):Play()

		TweenService:Create(colorCorrection, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TintColor = Color3.fromRGB(255, 255, 255),
			Brightness = 0,
			Saturation = 0,
			Contrast = 0
		}):Play()

		TweenService:Create(bloomEffect, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Intensity = -1
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

		task.wait(9)

		cameraShaker:Stop()
		pcall(function() colorCorrection:Destroy() end)
		pcall(function() bloomEffect:Destroy() end)
		pcall(function() sounds:Destroy() end)
		pcall(function() if floorAmbiance and floorAmbiance.Parent then floorAmbiance:Destroy() end end)
		pcall(function() if ambiance and ambiance.Parent then ambiance:Destroy() end end)
		pcall(function() if impact and impact.Parent then impact:Destroy() end end)
		pcall(function() if effectFolder and effectFolder.Parent then effectFolder:Destroy() end end)
	end)

	registerMarker("Release", function()
		giantModel.Head.LeftEyeAttachment.Flare.Enabled = false
		giantModel.Head.RightEyeAttachment.Flare.Enabled = false
	end)

	local appearanceParticle = giantModel.Particles.Appearance

	registerMarker("Fade", function()
		-- Beri waktu raksasa & palu berdiri gagah di tanah lebih lama (8 detik tambahan) sebelum mulai memudar
		task.wait(8)

		local fadeSound = sounds.GiantFade:Clone()
		fadeSound.Volume = 0
		fadeSound.PlaybackSpeed = 1.5
		fadeSound.Parent = giantModel.UpperTorso
		fadeSound.Playing = true

		TweenService:Create(fadeSound, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Volume = 0.7
		}):Play()

		TweenService:Create(fadeSound, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			PlaybackSpeed = 0.5
		}):Play()

		for _, descendant in pairs(giantModel:GetDescendants()) do
			if (descendant:IsA("BasePart") or descendant:IsA("Decal")) and descendant.Name ~= "HumanoidRootPart" then
				if not descendant:IsA("Decal") then
					local particle = appearanceParticle:Clone()
					particle.Parent = descendant
					particle.Enabled = true

					TweenService:Create(particle, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
						Rate = 30
					}):Play()
				end

				TweenService:Create(descendant, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1
				}):Play()
			end
		end

		TweenService:Create(diamondHammer.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Rate = 0
		}):Play()

		TweenService:Create(diamondHammer.Handle.HammerBaseOutline.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Rate = 70
		}):Play()

		TweenService:Create(diamondHammer.Handle.HammerHandleBase.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Rate = 40
		}):Play()

		TweenService:Create(diamondHammer.Handle, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()

		TweenService:Create(diamondHammer.Handle.Diamonds, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()
	end)

	registerMarker("FadeEnd", function()
		flameConnection:Disconnect()
		task.wait(3)
		if giantModel and giantModel.Parent then
			giantModel:Destroy()
		end
		-- PENTING: JANGAN destroy effectFolder di sini!
		-- Biarkan impact (teks donasi & koin) tetap mengambang di langit sampai durasinya selesai.
	end)

	pcall(function()
		animation:Play()
	end)

	-- Fallback Timer dengan timing persis KeyframeSequence (total 40s)
	-- Hanya berjalan jika animasi GAGAL diputar atau permission diblokir!
	task.spawn(function()
		task.wait(2.0)
		-- Jika animasi sedang bermain secara normal, biarkan marker animasi yang mengontrol waktu hantam palu!
		if animation and animation.IsPlaying and animation.Length > 10 then
			return
		end

		task.wait(8.25 - 2.0)
		triggerMarker("Eye lense flare")
		task.wait(11.12 - 8.25)
		triggerMarker("HammerAppear")
		task.wait(13.77 - 11.12)
		triggerMarker("ChargeSwing")
		task.wait(18.93 - 13.77)
		triggerMarker("SwingStart")
		task.wait(22.80 - 18.93)
		triggerMarker("SwingEnd")
		task.wait(23.73 - 22.80)
		triggerMarker("Release")
		task.wait(29.43 - 23.73)
		triggerMarker("Fade")
		task.wait(39.97 - 29.43)
		triggerMarker("FadeEnd")
	end)

	task.spawn(function()
		sounds.Earthquake:Play()
		sounds.CrumbleLoop.Volume = 0
		sounds.CrumbleLoop.Playing = true

		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.1
		}):Play()

		sounds.FireLoop.Volume = 0
		sounds.FireLoop.PlaybackSpeed = 0.5
		sounds.FireLoop.Playing = true

		TweenService:Create(sounds.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0.1,
			PlaybackSpeed = 1
		}):Play()

		cameraShaker:ShakeSustain(CameraShaker.Presets.Earthquake)

		for _, descendant in pairs(giantModel:GetDescendants()) do
			if (descendant:IsA("BasePart") or descendant:IsA("Decal")) and descendant.Name ~= "HumanoidRootPart" and not descendant:IsDescendantOf(diamondHammer) then
				TweenService:Create(descendant, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0
				}):Play()
			end
		end

		task.wait(7)

		TweenService:Create(sounds.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Volume = 0
		}):Play()

		cameraShaker:StopSustained(6)

		TweenService:Create(portalClone.Sparks, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Rate = 0
		}):Play()

		TweenService:Create(portalClone.Appearance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Rate = 0
		}):Play()

		TweenService:Create(portalClone, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Size = Vector3.new(0, 1, 0)
		}):Play()

		TweenService:Create(portalClone.OuterLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Width0 = 0,
			Width1 = 0
		}):Play()

		TweenService:Create(portalClone.InnerLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Width0 = 0,
			Width1 = 0
		}):Play()

		TweenService:Create(portalClone.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Volume = 0,
			PlaybackSpeed = 0
		}):Play()

		portalClone.PortalClose1.PlayOnRemove = true
		task.wait(5)
		portalClone:Destroy()
	end)

	-- Selesai: Pembersihan & pengembalian pencahayaan ditangani secara tersinkronisasi di SwingEnd saat teks donasi selesai
end

local lastSmiteTime = 0
effectsEvent.OnClientEvent:Connect(function(effectType, donorName, recipientName, amount, userId, currency)
	if isDonationEffectHidden() then
		return -- Hide Effect Donate aktif: Jangan putar efek sama sekali agar HP kentang tidak lag!
	end
	if effectType == "Smite" or effectType == "Hammer" then
		local now = os.clock()
		if now - lastSmiteTime < 4 then
			return -- Debounce pencegah efek dobel!
		end
		lastSmiteTime = now
		playSmiteEffect(donorName, recipientName, amount, userId or 1, currency)
	end
end)

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(player)
	if player == localPlayer then
		-- Clean up any active effects
		local activeEffects = workspace:FindFirstChild("ActiveEffects")
		if activeEffects then
			for _, effect in pairs(activeEffects:GetChildren()) do
				if string.find(effect.Name, "Smite_") then
					effect:Destroy()
				end
			end
		end
	end
end)