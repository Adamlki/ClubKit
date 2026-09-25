local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players 			= game:GetService("Players")
local TweenService		= game:GetService("TweenService")
local Lighting 			= game:GetService("Lighting")
local RunService 		= game:GetService("RunService")
local Debris 			= game:GetService("Debris")
local SoundService 		= game:GetService("SoundService")

local localPlayer = Players.LocalPlayer

local function isDonationEffectHidden()
	return _G.HideDonationEffects == true or (_G.IsDonationEffectsHidden and _G.IsDonationEffectsHidden() == true)
end

local CONFIG = {
	EFFECT_DURATION = 249,
	TARGET_POSITION = Vector3.new(-83.613, -25.66, -439.504),
	GIANT_SCALE_MULTIPLIER = 53,
}

local DEFAULT_DURATION = 249

local effectsEvent = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("EffectsEvent")

local vfxFolder         = ReplicatedStorage:WaitForChild("VFX")
local starfallTemplate  = vfxFolder:WaitForChild("Templates"):WaitForChild("WingedEndowmentPlayer")
local blackholeTemplate = vfxFolder:WaitForChild("Templates"):WaitForChild("Level7")
local debrisTemplate    = vfxFolder:WaitForChild("Templates"):WaitForChild("Debrish")

local M = CONFIG.EFFECT_DURATION / DEFAULT_DURATION

local function W(t)  return task.wait(t * M) end
local function T(t)  return t * M end
local function TC(t, style, dir, rep, rev, delay)
	return TweenInfo.new(
		t * M,
		style or Enum.EasingStyle.Quad,
		dir   or Enum.EasingDirection.Out,
		rep   or 0,
		rev   or false,
		(delay or 0) * M
	)
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

local function formatNumber(number)
	return tostring(number):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function saveLightingState()
	local state = {
		Brightness        = Lighting.Brightness,
		ClockTime         = Lighting.ClockTime,
		Ambient           = Lighting.Ambient,
		OutdoorAmbient    = Lighting.OutdoorAmbient,
		ColorShift_Top    = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
		FogColor          = Lighting.FogColor,
		FogEnd            = Lighting.FogEnd,
		FogStart          = Lighting.FogStart,
		SunRaysEnabled    = (function() local sr = Lighting:FindFirstChildOfClass('SunRaysEffect') or Lighting:FindFirstChild('SunRays'); return sr and sr.Enabled or nil end)(),
		AmbientReverb     = SoundService.AmbientReverb,
		hasAtmosphere     = false,
		atm               = {},
		savedCC           = {},
		savedBloom        = {},
	}
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		state.hasAtmosphere = true
		state.atm = {
			Density = atm.Density, Offset = atm.Offset,
			Color   = atm.Color,   Decay  = atm.Decay,
			Glare   = atm.Glare,   Haze   = atm.Haze,
		}
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("ColorCorrectionEffect") and child.Name ~= "StarfallCC" then
			table.insert(state.savedCC, {
				ref        = child,
				Brightness = child.Brightness, Contrast   = child.Contrast,
				Saturation = child.Saturation, TintColor  = child.TintColor,
				Enabled    = child.Enabled,
			})
		end
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") and child.Name ~= "StarfallBloom" then
			table.insert(state.savedBloom, {
				ref       = child,
				Size      = child.Size,      Threshold = child.Threshold,
				Intensity = child.Intensity, Enabled   = child.Enabled,
			})
		end
	end
	return state
end

local function restoreLightingState(state, duration)
	duration = duration or 5
	local ti = TweenInfo.new(T(duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	pcall(function()
		TweenService:Create(Lighting, ti, {
			Brightness        = state.Brightness,
			ClockTime         = state.ClockTime,
			Ambient           = state.Ambient,
			OutdoorAmbient    = state.OutdoorAmbient,
			ColorShift_Top    = state.ColorShift_Top,
			ColorShift_Bottom = state.ColorShift_Bottom,
			FogColor          = state.FogColor,
			FogEnd            = state.FogEnd,
			FogStart          = state.FogStart,
		}):Play()
	end)
	pcall(function() SoundService.AmbientReverb = state.AmbientReverb end)
	pcall(function()
		if state.SunRaysEnabled ~= nil then
			local sr = Lighting:FindFirstChildOfClass("SunRaysEffect") or Lighting:FindFirstChild("SunRays")
			if sr then sr.Enabled = state.SunRaysEnabled end
		end
	end)
	pcall(function()
		local effAtm = Lighting:FindFirstChild("StarfallAtmosphere")
		if effAtm then effAtm:Destroy() end
		if state.hasAtmosphere then
			local existing = Lighting:FindFirstChildOfClass("Atmosphere")
			if existing then
				TweenService:Create(existing, ti, {
					Density = state.atm.Density, Offset = state.atm.Offset,
					Glare   = state.atm.Glare,   Haze   = state.atm.Haze,
				}):Play()
				existing.Color = state.atm.Color; existing.Decay = state.atm.Decay
			else
				local newAtm = Instance.new("Atmosphere")
				newAtm.Density = state.atm.Density; newAtm.Offset = state.atm.Offset
				newAtm.Color   = state.atm.Color;   newAtm.Decay  = state.atm.Decay
				newAtm.Glare   = state.atm.Glare;   newAtm.Haze   = state.atm.Haze
				newAtm.Parent  = Lighting
			end
		end
	end)
	pcall(function()
		for _, s in ipairs(state.savedCC) do
			if s.ref and s.ref.Parent then
				TweenService:Create(s.ref, ti, {
					Brightness = s.Brightness, Contrast   = s.Contrast,
					Saturation = s.Saturation, TintColor  = s.TintColor,
				}):Play()
				s.ref.Enabled = s.Enabled
			end
		end
	end)
	pcall(function()
		for _, s in ipairs(state.savedBloom) do
			if s.ref and s.ref.Parent then
				TweenService:Create(s.ref, ti, {
					Size = s.Size, Threshold = s.Threshold, Intensity = s.Intensity,
				}):Play()
				s.ref.Enabled = s.Enabled
			end
		end
	end)
end

local function instantRestoreLightingState(state)
	pcall(function()
		Lighting.Brightness        = state.Brightness
		Lighting.ClockTime         = state.ClockTime
		Lighting.Ambient           = state.Ambient
		Lighting.OutdoorAmbient    = state.OutdoorAmbient
		Lighting.ColorShift_Top    = state.ColorShift_Top
		Lighting.ColorShift_Bottom = state.ColorShift_Bottom
		Lighting.FogColor          = state.FogColor
		Lighting.FogEnd            = state.FogEnd
		Lighting.FogStart          = state.FogStart
	end)
	pcall(function() SoundService.AmbientReverb = state.AmbientReverb end)
	pcall(function()
		if state.SunRaysEnabled ~= nil then
			local sr = Lighting:FindFirstChildOfClass("SunRaysEffect") or Lighting:FindFirstChild("SunRays")
			if sr then sr.Enabled = state.SunRaysEnabled end
		end
	end)
	pcall(function()
		local effAtm = Lighting:FindFirstChild("StarfallAtmosphere")
		if effAtm then effAtm:Destroy() end
		if state.hasAtmosphere and not Lighting:FindFirstChildOfClass("Atmosphere") then
			local newAtm = Instance.new("Atmosphere")
			newAtm.Density = state.atm.Density; newAtm.Offset = state.atm.Offset
			newAtm.Color   = state.atm.Color;   newAtm.Decay  = state.atm.Decay
			newAtm.Glare   = state.atm.Glare;   newAtm.Haze   = state.atm.Haze
			newAtm.Parent  = Lighting
		end
	end)
	for _, s in ipairs(state.savedCC) do
		pcall(function()
			if s.ref and s.ref.Parent then
				s.ref.Brightness = s.Brightness; s.ref.Contrast  = s.Contrast
				s.ref.Saturation = s.Saturation; s.ref.TintColor = s.TintColor
				s.ref.Enabled    = s.Enabled
			end
		end)
	end
	for _, s in ipairs(state.savedBloom) do
		pcall(function()
			if s.ref and s.ref.Parent then
				s.ref.Size      = s.Size;      s.ref.Threshold = s.Threshold
				s.ref.Intensity = s.Intensity; s.ref.Enabled   = s.Enabled
			end
		end)
	end
end

local EFFECT_INSTANCE_NAMES_SF = { "StarfallCC", "StarfallBloom", "StarfallAtmosphere" }
local function destroyEffectLightingInstances()
	for _, name in ipairs(EFFECT_INSTANCE_NAMES_SF) do
		local inst = Lighting:FindFirstChild(name)
		if inst then pcall(function() inst:Destroy() end) end
	end
end

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

	local applySuccess = pcall(function()
		humanoid:ApplyDescription(description)
	end)

	return applySuccess
end

local function setGiantTransparency(giantModel, transparency)
	local objects    = giantModel:FindFirstChild("Objects")
	local explosion  = giantModel:FindFirstChild("Explosion")
	local explosion2 = giantModel:FindFirstChild("Explosion2")
	for _, d in pairs(giantModel:GetDescendants()) do
		if (d:IsA("BasePart") or d:IsA("Decal"))
			and d.Name ~= "HumanoidRootPart" and d.Name ~= "PortalPosition" and d.Name ~= "FloorLevel"
			and not (objects   and d:IsDescendantOf(objects))
			and not (explosion  and d:IsDescendantOf(explosion))
			and not (explosion2 and d:IsDescendantOf(explosion2)) then
			d.Transparency = transparency
		end
	end
	local wings = giantModel:FindFirstChild("EndowmentWings")
	if wings then
		for _, part in pairs(wings:GetChildren()) do
			if part:IsA("BasePart") then part.Transparency = transparency end
		end
	end
	if explosion then
		for _, part in pairs(explosion:GetChildren()) do
			if part:IsA("MeshPart") then part.Transparency = 1 end
		end
	end
	if explosion2 then
		for _, part in pairs(explosion2:GetChildren()) do
			if part:IsA("MeshPart") then part.Transparency = 1 end
		end
	end
end

local function playStarfallEffect(donorName, recipientName, amount, userId, currency)
	local targetPart = workspace:FindFirstChild("EffectTarget")
	local TARGET_POSITION = (targetPart and targetPart.Position) or CONFIG.TARGET_POSITION

	M = CONFIG.EFFECT_DURATION / DEFAULT_DURATION

	local savedState = saveLightingState()

	local activeEffects = workspace:FindFirstChild("ActiveEffects") or workspace
	local effectFolder = Instance.new("Folder")
	effectFolder.Name = "Starfall_" .. tick()
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

	-- Anti-Player-Death: Cegah SEMUA part efek menabrak, melempar (fling), atau membunuh pemain!
	effectFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end)

	local trashFolder = Instance.new("Folder")
	trashFolder.Name = "Trash"; trashFolder.Parent = effectFolder

	local CameraShaker = require(script.CameraShaker)

	local currentWingedGiant = nil
	local currentWings = nil
	local currentArms  = nil

	local function createBodyTrail(part)
		task.spawn(function()
			local tp = part:Clone()
			tp.Color = Color3.fromRGB(255,0,255); tp.Anchored = true
			tp.Size = Vector3.new(part.Size.X*.9, part.Size.Y*.9, part.Size.Z*.9)
			tp.Transparency = 0.3; tp.Parent = trashFolder; tp:ClearAllChildren()
			W(0.5); tp:Destroy()
		end)
	end

	local function createHandTrail(part)
		task.spawn(function()
			local tp = part:Clone()
			tp.Color = Color3.fromRGB(255,0,255); tp.Anchored = true
			tp.Size = Vector3.new(part.Size.X*1.25, part.Size.Y*1.25, part.Size.Z*1.25)
			tp.Transparency = 0.3; tp.Parent = trashFolder; tp:ClearAllChildren()
			TweenService:Create(tp, TweenInfo.new(T(0.5), Enum.EasingStyle.Linear), {Transparency=1}):Play()
			W(0.5); tp:Destroy()
		end)
	end

	task.spawn(function()
		while currentWingedGiant do
			task.wait(T(0.05))
			if not currentWingedGiant then break end
			pcall(function()
				createBodyTrail(currentWingedGiant.LeftFoot);    createBodyTrail(currentWingedGiant.RightFoot)
				createBodyTrail(currentWingedGiant.RightLowerLeg); createBodyTrail(currentWingedGiant.LeftLowerLeg)
				createBodyTrail(currentWingedGiant.LeftUpperLeg);  createBodyTrail(currentWingedGiant.RightUpperLeg)
				createBodyTrail(currentWingedGiant.LowerTorso);    createBodyTrail(currentWingedGiant.UpperTorso)
				createBodyTrail(currentWingedGiant.LeftHand);      createBodyTrail(currentWingedGiant.RightHand)
				createBodyTrail(currentWingedGiant.RightLowerArm); createBodyTrail(currentWingedGiant.LeftLowerArm)
				createBodyTrail(currentWingedGiant.LeftUpperArm);  createBodyTrail(currentWingedGiant.RightUpperArm)
				createBodyTrail(currentWingedGiant.Head)
			end)
		end
	end)

	task.spawn(function()
		while currentArms do
			task.wait(0)
			if not currentArms then break end
			pcall(function()
				createHandTrail(currentArms.LeftHand); createHandTrail(currentArms.RightHand)
			end)
		end
	end)

	task.spawn(function()
		while currentWings do
			task.wait(T(0.05))
			if not currentWings then break end
			pcall(function()
				createBodyTrail(currentWings.Halo);        createBodyTrail(currentWings.HaloStar1)
				createBodyTrail(currentWings.HaloStar2);   createBodyTrail(currentWings.LeftDiamond)
				createBodyTrail(currentWings.LeftStar1);   createBodyTrail(currentWings.LeftStar2)
				createBodyTrail(currentWings.LeftStar3);   createBodyTrail(currentWings.LeftStar4)
				createBodyTrail(currentWings.LeftStar5);   createBodyTrail(currentWings.LeftWing1)
				createBodyTrail(currentWings.LeftWing2);   createBodyTrail(currentWings.LeftWing3)
				createBodyTrail(currentWings.LeftWing4);   createBodyTrail(currentWings.LeftWing5)
				createBodyTrail(currentWings.RightDiamond); createBodyTrail(currentWings.RightStar1)
				createBodyTrail(currentWings.RightStar2);  createBodyTrail(currentWings.RightStar3)
				createBodyTrail(currentWings.RightStar4);  createBodyTrail(currentWings.RightStar5)
				createBodyTrail(currentWings.RightWing1);  createBodyTrail(currentWings.RightWing2)
				createBodyTrail(currentWings.RightWing3);  createBodyTrail(currentWings.RightWing4)
				createBodyTrail(currentWings.RightWing5)
			end)
		end
	end)

	local giantModel  = starfallTemplate:Clone()
	local blackhole   = blackholeTemplate:Clone()
	local debrisModel = debrisTemplate:Clone()

	local cameraShaker = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
	end)
	cameraShaker:Start()

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Enabled = true; colorCorrection.Name = "StarfallCC"
	colorCorrection.Parent  = Lighting

	local bloomEffect = Instance.new("BloomEffect")
	bloomEffect.Enabled = true; bloomEffect.Name = "StarfallBloom"
	bloomEffect.Size = 20; bloomEffect.Threshold = 0.1; bloomEffect.Intensity = -1
	bloomEffect.Parent = Lighting

	local atmosphere = script.Atmosphere:Clone()
	atmosphere.Name  = "StarfallAtmosphere"
	atmosphere.Parent = Lighting

	local disconnectConn
	disconnectConn = Players.PlayerRemoving:Connect(function(player)
		if player ~= localPlayer then return end
		disconnectConn:Disconnect()
		currentWingedGiant = nil; currentWings = nil; currentArms = nil
		pcall(function() cameraShaker:Stop() end)
		destroyEffectLightingInstances()
		instantRestoreLightingState(savedState)
		pcall(function() effectFolder:Destroy() end)
	end)

	giantModel.PrimaryPart = giantModel.FloorLevel
	giantModel:SetPrimaryPartCFrame(CFrame.new(TARGET_POSITION.X, TARGET_POSITION.Y, TARGET_POSITION.Z))
	giantModel:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(
		CFrame.Angles(0, math.rad(math.random(-180,180)), 0)
		))
	giantModel:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(CFrame.new(0, 600, 2250)))
	giantModel.PrimaryPart = giantModel.HumanoidRootPart

	giantModel.Parent = effectFolder

	local objects = giantModel.Objects
	objects.Parent = effectFolder

	local wings = giantModel.EndowmentWings
	wings.Parent = effectFolder

	local appearanceSuccess = setGiantAppearance(userId or 1, giantModel)
	pcall(function()
		giantModel:ScaleTo(CONFIG.GIANT_SCALE_MULTIPLIER)
	end)
	disableCollision(giantModel)

	wings.Parent = giantModel

	setGiantTransparency(giantModel, 1)

	local portal = objects.Portal
	local star   = objects.Star

	local sounds = giantModel.Sounds
	sounds.Name = "StarfallDonationEffect_Sounds"; sounds.Parent = workspace

	portal.Position    = giantModel.PortalPosition.Position
	portal.Orientation = giantModel.PortalPosition.Orientation

	star.Parent = effectFolder
	star:SetPrimaryPartCFrame(CFrame.new(TARGET_POSITION.X, TARGET_POSITION.Y, TARGET_POSITION.Z))
	star:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(
		CFrame.Angles(0, math.rad(math.random(-180,180)), 0)
		))
	star:SetPrimaryPartCFrame(giantModel.FloorLevel.CFrame:ToWorldSpace(CFrame.new(0, 600, 2250)))

	portal.Parent = effectFolder

	local floorAmbiance = objects:FindFirstChild("FloorAmbiAnce") or objects:FindFirstChild("FloorAmbiance")
	if floorAmbiance then
		floorAmbiance.Position = TARGET_POSITION + Vector3.new(0,-0.5,0)
		floorAmbiance.Parent = effectFolder
		TweenService:Create(floorAmbiance, TC(10), { Size = Vector3.new(2048,1,2048) }):Play()
		for _, particle in pairs(floorAmbiance:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				scaleParticleEmitter(particle, 2.5); particle.Enabled = true
			end
		end
	end

	debrisModel.Parent = effectFolder
	local isSpawningDebris = true
	local currentDebrisWait = 0.10525

	local blockTemplate = script:FindFirstChild("10MBlock")
	task.spawn(function()
		while isSpawningDebris do
			task.wait(currentDebrisWait * M)
			if not effectFolder or not effectFolder.Parent or not isSpawningDebris then
				isSpawningDebris = false
				break
			end
			if not blockTemplate then break end
			task.spawn(function()
				if not effectFolder or not effectFolder.Parent or not trashFolder or not trashFolder.Parent then return end
				local side = math.random(1,4)
				local dp = blockTemplate:Clone()
				dp.Anchored = true; dp.CanCollide = false; dp.CanTouch = false; dp.CanQuery = false; dp.Name = "Block"; dp.Parent = trashFolder
				local sd = 3925
				if side==1 then dp.Position = TARGET_POSITION + Vector3.new(-sd,-852.154,math.random(-3675,3864))
				elseif side==2 then dp.Position = TARGET_POSITION + Vector3.new(math.random(-3685,3874),-852.154,3584.024)
				elseif side==3 then dp.Position = TARGET_POSITION + Vector3.new(sd+28.652,-852.154,math.random(-3715,2854))
				else dp.Position = TARGET_POSITION + Vector3.new(math.random(-3725,3854),-852.154,-3895.976) end
				local sz = math.random(1000,1500)
				dp.Size = Vector3.new(sz,sz,sz)
				TweenService:Create(dp, TweenInfo.new(T(math.random(1,3))), {
					Position    = dp.Position + Vector3.new(0,math.random(4150,5250),0),
					Rotation    = Vector3.new(math.random(50,75),math.random(50,75),math.random(50,75)),
					Size        = Vector3.new(0,0,0),
					Color       = Color3.fromRGB(105,3,230),
					Transparency= 1
				}):Play()
				task.wait(T(30)); dp:Destroy()
			end)
		end
	end)

	pcall(function()
		local ksp = game:GetService("KeyframeSequenceProvider")
		local kf = giantModel:FindFirstChild("AnimSaves") and (giantModel.AnimSaves:FindFirstChild("Imported Animation Clip") or giantModel.AnimSaves:FindFirstChild("Automatic Save"))
		if kf then
			local localId = ksp:RegisterKeyframeSequence(kf)
			if localId then
				giantModel.Animations.Giant_MainAnimation.AnimationId = localId
			end
		end
	end)

	local mainAnimation
	pcall(function()
		mainAnimation = giantModel.Humanoid:LoadAnimation(giantModel.Animations.Giant_MainAnimation)
	end)

	local wingsAnimation
	pcall(function()
		wingsAnimation = giantModel.EndowmentWings.AnimationController.Animator:LoadAnimation(giantModel.EndowmentWings.IdleAnimation)
	end)

	giantModel.Highlight.Enabled = true

	local sr = Lighting:FindFirstChildOfClass("SunRaysEffect") or Lighting:FindFirstChild("SunRays")
	if sr then sr.Enabled = false end

	TweenService:Create(Lighting,        TC(6), { Brightness = 0 }):Play()
	TweenService:Create(colorCorrection, TC(6), { Brightness = -0.2 }):Play()

	sounds.Summon:Play(); sounds.Ambiance:Play()

	W(3)
	TweenService:Create(Lighting, TC(3), { Brightness = -2 }):Play()

	W(0.5)

	disableCollision(star)
	star.Star1.Size = Vector3.new(1,2,3); star.Star2.Size = Vector3.new(1,2,3)
	star.Circle.Size = Vector3.new(0,0,0); star.Circle.Transparency = 0
	sounds.RiseBeamStart:Play()

	TweenService:Create(star.Star1,  TC(1, Enum.EasingStyle.Sine), { Orientation = star.Star1.Orientation  + Vector3.new(90,0,0) }):Play()
	TweenService:Create(star.Circle, TC(0.7), { Size = Vector3.new(2048,1,2048) }):Play()
	TweenService:Create(star.Star2,  TC(1, Enum.EasingStyle.Sine), { Orientation = star.Star2.Orientation  + Vector3.new(90,0,0) }):Play()
	TweenService:Create(star.Circle, TC(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
	TweenService:Create(star.Star1,  TC(0.5), { Size = Vector3.new(50,2048,1200) }):Play()
	TweenService:Create(star.Star2,  TC(0.5), { Size = Vector3.new(50,2048,1200) }):Play()

	W(0.5)

	TweenService:Create(star.Star1, TC(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0,2048,0) }):Play()
	TweenService:Create(star.Star2, TC(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0,2048,0) }):Play()

	W(0.5)
	star:Destroy()

	setGiantTransparency(giantModel, 0)

	local floorAmbianceRef = objects:FindFirstChild("FloorAmbiAnce") or objects:FindFirstChild("FloorAmbiance")
	if floorAmbianceRef then floorAmbianceRef.Transparency = 1 end
	giantModel.FloorLevel.Transparency       = 1
	giantModel.HumanoidRootPart.Transparency = 1
	giantModel.PortalPosition.Transparency   = 1
	portal.Transparency                      = 1
	giantModel.Head.Transparency             = 1

	TweenService:Create(colorCorrection, TC(0.5), { Brightness = 0 }):Play()
	TweenService:Create(Lighting,        TC(3),   { Brightness = -2 }):Play()
	TweenService:Create(Lighting,        TC(0.5), { Brightness = 3 }):Play()

	pcall(function()
		if mainAnimation then
			mainAnimation:Play()
			if M ~= 1.0 then mainAnimation:AdjustSpeed(1 / M) end
		end
	end)
	pcall(function()
		if wingsAnimation then
			wingsAnimation:Play()
			if M ~= 1.0 then wingsAnimation:AdjustSpeed(1 / M) end
		end
	end)

	cameraShaker:ShakeOnce(1.5, 2, T(0.1), T(2.425))

	sounds.RiseBeamOpen1:Play(); sounds.RiseBeamOpen2:Play(); sounds.RiseBeamLoop:Play()
	Lighting.Brightness = 10

	W(3)

	TweenService:Create(portal.Beam,            TC(3, Enum.EasingStyle.Elastic), { Width0=12500, Width1=350 }):Play()
	TweenService:Create(portal.Bea2,            TC(3, Enum.EasingStyle.Elastic), { Width0=11500, Width1=350 }):Play()
	TweenService:Create(portal.Bea4,            TC(3, Enum.EasingStyle.Elastic), { Width0=10600, Width1=350 }):Play()
	TweenService:Create(portal["Black circles"],TC(3, Enum.EasingStyle.Elastic), { Width0=9600,  Width1=350 }):Play()

	TweenService:Create(sounds.Ambiance, TC(5, Enum.EasingStyle.Linear), { Volume=0.5 }):Play()
	TweenService:Create(Lighting,        TC(5), { Brightness=3 }):Play()
	TweenService:Create(colorCorrection, TC(10), {
		TintColor = Color3.fromRGB(255,200,255),
		Brightness=0.25, Saturation=0.1, Contrast=0.25
	}):Play()

	local wingsAttachment = Instance.new("Attachment", giantModel.UpperTorso)
	wingsAttachment.Name = "WingsWeld"
	giantModel.EndowmentWings.CharacterWeld.Attachment1 = wingsAttachment

	currentWingedGiant = giantModel
	currentWings = giantModel.EndowmentWings

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
		if mainAnimation then
			pcall(function()
				mainAnimation:GetMarkerReachedSignal(name):Connect(function()
					triggerMarker(name)
				end)
			end)
		end
	end

	registerMarker("ChargeApperance", function()
		script.ScreenGui.Vignette.ImageTransparency = 1
		sounds.ApperanceCharge:Play()
		script.ScreenGui.Enabled = true
		TweenService:Create(script.ScreenGui.Vignette, TC(1.7), { ImageTransparency=0 }):Play()
	end)

	registerMarker("Reveal", function()
		for _, part in pairs(giantModel.Explosion2:GetChildren()) do
			if part:IsA("MeshPart") then
				part.Transparency = 0
				TweenService:Create(part, TC(0.75), { Transparency=1 }):Play()
			end
		end
		currentDebrisWait = 0.067525
		cameraShaker:ShakeOnce(3, 6, T(1), T(4))
		currentWingedGiant = nil; currentWings = nil

		script.ScreenGui.Enabled = true
		script.ScreenGui.Vignette.ImageColor3 = Color3.fromRGB(255,0,255)
		TweenService:Create(script.ScreenGui.Vignette, TC(7), { ImageTransparency=1 }):Play()
		TweenService:Create(giantModel.Highlight, TC(0.25), { FillTransparency=1 }):Play()

		TweenService:Create(giantModel.Explosion2["Meshes/EXPLODE low_Cube"],     TC(0.75), { Size=Vector3.new(1917.519,2008.192,2032.428) }):Play()
		TweenService:Create(giantModel.Explosion2["Meshes/EXPLODE low_Cube.001"], TC(0.75), { Size=Vector3.new(2021.985,2048,2048) }):Play()
		TweenService:Create(giantModel.Explosion2["Meshes/EXPLODE low_Cube.002"], TC(0.75), { Size=Vector3.new(2048,2048,2048) }):Play()
		TweenService:Create(giantModel.Explosion2["Meshes/EXPLODE low_Cube.003"], TC(0.75), { Size=Vector3.new(21977.896,2037.572,2048) }):Play()

		sounds.PlayerAppear1:Play(); sounds.PlayerAppear2:Play(); sounds.PlayerAppear3:Play()
		TweenService:Create(Lighting, TweenInfo.new(0), { Brightness=15 }):Play()

		for _, triangle in pairs(script.ScreenGui.Triangles.Triangles:GetChildren()) do
			triangle.ImageColor3 = Color3.fromRGB(255,255,255); triangle.ImageTransparency = 0
		end
		task.spawn(function()
			for _, triangle in pairs(script.ScreenGui.Triangles.Triangles:GetChildren()) do
				TweenService:Create(triangle, TC(3), { ImageTransparency=1 }):Play()
			end
		end)
	end)

	registerMarker("PingSound", function()
		W(0.25)
		currentArms = giantModel
		sounds.Ping:Play()

		for handIndex = 1, 2 do
			local starObj = objects.Star2:Clone()
			starObj.Star.BillboardGui.Enabled = true
			starObj.PrimaryPart = starObj.Star
			starObj.Star.BillboardGui.AlwaysOnTop = true
			starObj.Star.Position = handIndex==1 and giantModel.LeftHand.Position or giantModel.RightHand.Position
			starObj.Parent = effectFolder

			local frame = starObj.Star.BillboardGui.Frame
			TweenService:Create(frame.Circle1,    TC(0.25,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out), {Size=UDim2.fromScale(1,1)}):Play()
			TweenService:Create(frame.Circle1,    TC(0.25,Enum.EasingStyle.Cubic,Enum.EasingDirection.In),  {ImageTransparency=1}):Play()
			TweenService:Create(frame.Circle2,    TC(0.25,Enum.EasingStyle.Cubic,Enum.EasingDirection.In),  {ImageTransparency=1}):Play()
			TweenService:Create(frame,            TC(1,  Enum.EasingStyle.Cubic,Enum.EasingDirection.Out),  {Size=UDim2.fromScale(0.7,0.7)}):Play()
			TweenService:Create(frame,            TC(0.7,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out),  {Rotation=-90}):Play()
			TweenService:Create(frame.ImageLabel1,TC(0.25,Enum.EasingStyle.Cubic,Enum.EasingDirection.In),  {Size=UDim2.fromScale(1,0)}):Play()
			TweenService:Create(frame.ImageLabel2,TC(0.25,Enum.EasingStyle.Cubic,Enum.EasingDirection.In),  {Size=UDim2.fromScale(1,0)}):Play()
			Debris:AddItem(starObj, T(1))
		end
		sounds.HandsSwing:Play()
	end)

	registerMarker("Clap", function()
		currentArms = nil

		local lp = script.HandParticle:Clone(); lp.Parent = giantModel.LeftHand;  lp.Enabled = true
		local rp = script.HandParticle:Clone(); rp.Parent = giantModel.RightHand; rp.Enabled = true

		for _, part in pairs(giantModel.Explosion:GetChildren()) do
			if part:IsA("MeshPart") then
				part.Transparency = 0
				TweenService:Create(part, TC(0.75), { Transparency=1 }):Play()
			end
		end

		blackhole.Parent = effectFolder
		sounds.HandsClap:Play(); sounds.EnergyLoop:Play()

		local bhp = TARGET_POSITION + Vector3.new(0, 329.417, 0)
		TweenService:Create(blackhole.Fill,              TC(1,Enum.EasingStyle.Bounce,Enum.EasingDirection.In), {Position=bhp}):Play()
		TweenService:Create(blackhole.Core,              TC(1,Enum.EasingStyle.Bounce,Enum.EasingDirection.In), {Position=bhp}):Play()
		TweenService:Create(blackhole.Outline,           TC(1,Enum.EasingStyle.Bounce,Enum.EasingDirection.In), {Position=bhp}):Play()
		TweenService:Create(blackhole.FormationParticles,TC(1,Enum.EasingStyle.Bounce,Enum.EasingDirection.In), {Position=bhp}):Play()

		for _, crack in pairs(blackhole.Rift.Outline:GetChildren()) do
			if crack.Name=="Crack" then crack.Shards:Emit(10) end
		end
		blackhole.Rift.Inline.Center.Explosion:Play();    blackhole.Rift.Inline.Center.Glass:Play()
		blackhole.Rift.Inline.Center.Impact:Play()
		blackhole.Rift.Inline.Center.RiftAmbiance1:Play(); blackhole.Rift.Inline.Center.RiftAmbiance2:Play()
		blackhole.Rift.Inline.Center.Shockwave:Emit(3);   blackhole.Rift.Inline.Center.FastShockwave:Emit(3)
		blackhole.Rift.Inline.Center.Flare:Emit(10);      blackhole.Rift.Inline.Center.Flash:Emit(10)

		cameraShaker:ShakeOnce(0.75, 8, T(0.1), T(6))

		TweenService:Create(giantModel.Explosion["Meshes/EXPLODE low_Cube"],     TC(0.75), {Size=Vector3.new(1917.519,2008.192,2032.428)}):Play()
		TweenService:Create(giantModel.Explosion["Meshes/EXPLODE low_Cube.001"], TC(0.75), {Size=Vector3.new(2021.985,2048,2048)}):Play()
		TweenService:Create(giantModel.Explosion["Meshes/EXPLODE low_Cube.002"], TC(0.75), {Size=Vector3.new(2048,2048,2048)}):Play()
		TweenService:Create(giantModel.Explosion["Meshes/EXPLODE low_Cube.003"], TC(0.75), {Size=Vector3.new(21977.896,2037.572,2048)}):Play()

		W(10)
	end)

	registerMarker("OrbFormation", function()
		portal:Destroy()
		TweenService:Create(script.ScreenGui.Vignette, TC(1), {ImageColor3=Color3.fromRGB(0,0,0)}):Play()

		local bhp = TARGET_POSITION + Vector3.new(0, 329.417, 0)

		blackhole.Core.EnergyLoop1.Volume=0; blackhole.Core.EnergyLoop2.Volume=0; blackhole.Core.EnergyLoop3.Volume=0
		blackhole.Core.EnergyLoop1:Play(); blackhole.Core.EnergyLoop2:Play(); blackhole.Core.EnergyLoop3:Play()
		sounds.OrbChargeLoop:Play(); sounds.OrbChargeLoop.Volume=0

		TweenService:Create(blackhole.FormationParticles.Streaks,           TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=500}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.CoreCharge, TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=27.5}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.BigDots,    TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=100}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.Dots,       TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=100}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.StarDots,   TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=100}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.Streaks,    TC(7,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {TimeScale=1,Rate=100}):Play()

		TweenService:Create(blackhole.Core.EnergyLoop1, TC(6,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Volume=1.25}):Play()
		TweenService:Create(blackhole.Core.EnergyLoop2, TC(6,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Volume=1.25}):Play()
		TweenService:Create(blackhole.Core.EnergyLoop3, TC(6,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Volume=1.25}):Play()
		TweenService:Create(sounds.OrbChargeLoop, TC(6.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Volume=1,PlaybackSpeed=1.25}):Play()

		W(1)
		for _, part in pairs(blackhole.Rift.Inline:GetChildren()) do
			if part:IsA("Part") then TweenService:Create(part, TC(3,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Transparency=1}):Play() end
		end
		for _, part in pairs(blackhole.Rift.Outline:GetChildren()) do
			if part:IsA("Part") then TweenService:Create(part, TC(2,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Transparency=1}):Play() end
		end
		TweenService:Create(blackhole.Rift.Inline.Center.RiftAmbiance1, TC(3,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Volume=0}):Play()
		TweenService:Create(blackhole.Rift.Inline.Center.RiftAmbiance2, TC(3,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Volume=0}):Play()

		TweenService:Create(blackhole.Fill,              TC(3.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Position=bhp}):Play()
		TweenService:Create(blackhole.Core,              TC(3.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Position=bhp}):Play()
		TweenService:Create(blackhole.FormationParticles,TC(3.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Position=bhp}):Play()
		TweenService:Create(blackhole.Outline,           TC(3.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut), {Position=bhp}):Play()

		W(6)
		TweenService:Create(sounds.OrbChargeLoop, TC(3,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {PlaybackSpeed=1.3}):Play()
	end)

	registerMarker("OrbLaunch", function()
		cameraShaker:ShakeOnce(6, 20, T(0.75), T(6))
		blackhole.Rift.Inline.Center.FastShockwave:Emit(3)

		TweenService:Create(script.ScreenGui.Lines1, TC(1.7), {ImageTransparency=0}):Play()
		TweenService:Create(script.ScreenGui.Lines2, TC(1.7), {ImageTransparency=0}):Play()

		TweenService:Create(blackhole.FormationParticles.Streaks,           TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.BigDots,    TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.CoreCharge, TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.Dots,       TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.StarDots,   TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()
		TweenService:Create(blackhole.FormationParticles.Center.Streaks,    TC(0.05,Enum.EasingStyle.Linear), {Rate=0}):Play()

		for i = 1, 12 do
			TweenService:Create(blackhole.Beams["FlameEffect"..i], TC(1.7,Enum.EasingStyle.Linear), {Brightness=1.57}):Play()
		end
		TweenService:Create(Lighting, TC(1.7), {Brightness=25}):Play()
		for _, beam in pairs(blackhole.Beams:GetChildren()) do
			if beam:IsA("Beam") then beam.Enabled = true end
		end

		blackhole.Core.FlameEffect1_0.BrightFlare.Enabled = true
		blackhole.Outline.Flames.Enabled = true
		blackhole.Core.FlameEffect1_0.FlameRing.Enabled  = true
		blackhole.Core.FlameEffect1_0.Flames1.Enabled    = true
		blackhole.Core.FlameEffect1_0.Flames2.Enabled    = true
		blackhole.Core.FlameEffect1_0.Flames3.Enabled    = true

		blackhole.Core.LaunchSound:Play(); sounds.Drop1:Play(); sounds.Drop2:Play()

		TweenService:Create(blackhole.FormationParticles, TC(1.7,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position=TARGET_POSITION}):Play()
		TweenService:Create(blackhole.Fill,               TC(1.7,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position=TARGET_POSITION}):Play()
		TweenService:Create(blackhole.Outline,            TC(1.7,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position=TARGET_POSITION}):Play()
		TweenService:Create(blackhole.Core,               TC(1.7,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position=TARGET_POSITION}):Play()
		TweenService:Create(sounds.OrbChargeLoop, TC(1,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut), {Volume=0,PlaybackSpeed=1.5}):Play()

		W(1.675)
		pcall(function() blackhole:Destroy() end)
		sounds.OrbChargeLoop:Stop()

		bloomEffect.Intensity=0.75; bloomEffect.Threshold=0.05; colorCorrection.Contrast=0
		TweenService:Create(bloomEffect,     TC(10), {Intensity=-0.9,Threshold=0.1}):Play()
		TweenService:Create(colorCorrection, TC(10), {Contrast=0.25}):Play()

		cameraShaker:ShakeOnce(8, 20, T(0.5), T(12))
		sounds.EnergyLoop:Stop(); sounds.ExplosionSound:Play()

		script.ScreenGui.Enabled = true
		for _, triangle in pairs(script.ScreenGui.Triangles.Triangles:GetChildren()) do
			triangle.ImageColor3 = Color3.fromRGB(133,85,255); triangle.ImageTransparency = 0
		end
		task.spawn(function()
			W(0.5)
			for _, triangle in pairs(script.ScreenGui.Triangles.Triangles:GetChildren()) do
				TweenService:Create(triangle, TC(6), {ImageTransparency=1}):Play()
			end
		end)

		TweenService:Create(script.ScreenGui.Lines1, TC(0.05), {ImageTransparency=1}):Play()
		TweenService:Create(script.ScreenGui.Lines2, TC(0.05), {ImageTransparency=1}):Play()

		TweenService:Create(Lighting,          TC(0.2),  {Brightness=150}):Play()
		TweenService:Create(colorCorrection,   TC(0.05), {Brightness=1.2}):Play()
		TweenService:Create(colorCorrection,   TC(3),    {Brightness=0.05}):Play()
		TweenService:Create(Lighting,          TC(7),    {Brightness=25}):Play()

		currentWingedGiant = nil

		local impactVisuals = objects.ImpactVisuals
		impactVisuals.Parent   = effectFolder
		impactVisuals.Position = TARGET_POSITION

		scaleParticleEmitter(impactVisuals.EmitPoint.Explosion_Shockwave, 30)
		impactVisuals.EmitPoint.Impact_Spark1:Emit(100);    impactVisuals.EmitPoint.Impact_Spark2:Emit(100)
		impactVisuals.EmitPoint.Impact_Spark3:Emit(100);    impactVisuals.EmitPoint.Explosion_Glow:Emit(5)
		impactVisuals.EmitPoint.Explosion_Rays:Emit(100);   impactVisuals.EmitPoint.Explosion_Ring:Emit(1)
		impactVisuals.EmitPoint.Explosion_Flare:Emit(10);   impactVisuals.EmitPoint.Explosion_ThinRays:Emit(250)
		impactVisuals.EmitPoint.Explosion_Shockwave:Emit(25)

		impactVisuals.ApplauseLoop.Playing = true
		impactVisuals.ChimeLoop.Playing    = true
		impactVisuals.CoinsLoop.Playing    = true

		local frame = impactVisuals.BillboardGuiAnimation.Frame
		frame.TopText.Visible    = true
		frame.BottomText.Visible = true
		local prefix = (currency == "Rupiah" and "Rp " or "R$")
		frame.TopText.Text       = "@"..donorName.." DONATED"
		frame.MiddleText.Text    = prefix..formatNumber(amount)
		frame.BottomText.Text    = "TO @"..recipientName

		-- Anti-Overlap Layout: Pastikan teks 1 baris tanpa wrapping dan tidak tumpang-tindih
		frame.TopText.TextWrapped    = false
		frame.MiddleText.TextWrapped = false
		frame.BottomText.TextWrapped = false

		frame.TopText.AnchorPoint    = Vector2.new(0.5, 0.5)
		frame.MiddleText.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BottomText.AnchorPoint = Vector2.new(0.5, 0.5)

		frame.RobuxLogo.Size         = UDim2.fromScale(0,0)
		frame.RobuxLogo.Rotation     = -180
		frame.Star.Size              = UDim2.fromScale(0,0)
		frame.BottomText.Size        = UDim2.fromScale(0,0)
		frame.BottomText.Position    = UDim2.fromScale(0.5,0.5)
		frame.MiddleText.Size        = UDim2.fromScale(0,0)
		frame.MiddleText.Position    = UDim2.fromScale(0.5,0.5)
		frame.TopText.Position       = UDim2.fromScale(0.5,0.5)
		frame.TopText.Size           = UDim2.fromScale(0,0)
		frame.Parent.Enabled         = true

		TweenService:Create(impactVisuals, TC(20), {Position=TARGET_POSITION+Vector3.new(0,400,0)}):Play()

		TweenService:Create(frame.RobuxLogo, TC(10,Enum.EasingStyle.Elastic), {Size=UDim2.fromScale(1,1)}):Play()
		TweenService:Create(frame.RobuxLogo, TC(15,Enum.EasingStyle.Elastic), {Rotation=0}):Play()
		TweenService:Create(frame.Star,      TC(5, Enum.EasingStyle.Elastic), {Size=UDim2.fromScale(1.5,1.5)}):Play()
		TweenService:Create(frame.Star,      TC(15),                          {Rotation=360}):Play()

		-- Pastikan TextScaled selalu aktif agar teks membesar maksimal
				-- Pastikan Badge Lingkaran Tengah berbentuk bulat sempurna (Circle)
		if frame:FindFirstChild("RobuxLogo") and frame.RobuxLogo:FindFirstChild("Fill") then
			local fill = frame.RobuxLogo.Fill
			local corner = fill:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", fill)
			corner.CornerRadius = UDim.new(1, 0)
			local arc = fill:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint", fill)
			arc.AspectRatio = 1
		end

		frame.TopText.TextScaled     = true
		frame.MiddleText.TextScaled  = true
		frame.BottomText.TextScaled  = true

		-- TopText (donor name): Y = 0.20, Height = 0.18, Width = 3.5 (Teks BESAR & jelas)
		TweenService:Create(frame.TopText,
			TC(5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out,0,false,0.2),
			{Size=UDim2.fromScale(3.5, 0.18), Position=UDim2.fromScale(0.5, 0.20)}):Play()

		-- MiddleText (nominal): Y = 0.50, Height = 0.40, Width = 3.8 (Nominal SANGAT BESAR & menonjol, tanpa wrap)
		TweenService:Create(frame.MiddleText,
			TC(5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out,0,false,0.4),
			{Size=UDim2.fromScale(3.8, 0.40), Position=UDim2.fromScale(0.5, 0.50)}):Play()

		-- BottomText (recipient): Y = 0.81, Height = 0.18, Width = 3.5 (Teks BESAR & jelas)
		TweenService:Create(frame.BottomText,
			TC(5,Enum.EasingStyle.Elastic,Enum.EasingDirection.Out,0,false,0.6),
			{Size=UDim2.fromScale(3.5, 0.18), Position=UDim2.fromScale(0.5, 0.81)}):Play()
		TweenService:Create(frame.Star,
			TC(10,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,5),
			{ImageTransparency=1,ImageColor3=Color3.fromRGB(0,255,255)}):Play()

		impactVisuals.EmitPoint.Sparks.Enabled           = true
		impactVisuals.EmitPoint.SparkleExplosion.Enabled = true
		TweenService:Create(impactVisuals.EmitPoint.Sparks,           TC(45,Enum.EasingStyle.Quint,Enum.EasingDirection.In), {Rate=0}):Play()
		TweenService:Create(impactVisuals.EmitPoint.SparkleExplosion, TC(45,Enum.EasingStyle.Quint,Enum.EasingDirection.In), {Rate=0}):Play()
		TweenService:Create(impactVisuals.ChimeLoop,    TC(55), {Volume=0,PlaybackSpeed=0.75}):Play()
		TweenService:Create(impactVisuals.ApplauseLoop, TC(60), {Volume=0}):Play()
		TweenService:Create(impactVisuals.CoinsLoop,    TC(50), {Volume=0,PlaybackSpeed=1}):Play()

		W(30)
		local uiScale = frame:FindFirstChildOfClass("UIScale") or frame:FindFirstChild("UIScale")
		if uiScale then
			TweenService:Create(uiScale, TC(15,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Scale=0}):Play()
		else
			TweenService:Create(frame, TC(15,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)}):Play()
		end
		TweenService:Create(impactVisuals,  TC(15,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Size=Vector3.new(0.001,0.001,0.001)}):Play()

		W(30)
		pcall(function() impactVisuals:Destroy() end)

		W(15)
		TweenService:Create(colorCorrection, TC(30), {TintColor=Color3.fromRGB(255,255,255),Brightness=0,Saturation=0,Contrast=0}):Play()
		TweenService:Create(bloomEffect,     TC(30), {Intensity=-1}):Play()

		W(15)
		if floorAmbiance then
			for _, particle in pairs(floorAmbiance:GetChildren()) do
				if particle:IsA("ParticleEmitter") then
					TweenService:Create(particle, TC(60), {Rate=0}):Play()
				end
			end
		end

		W(60)
		pcall(function() floorAmbiance:Destroy() end)
	end)

	registerMarker("DisappearStart", function()
		sounds.PlayerStartVanishing:Play()
		TweenService:Create(bloomEffect, TC(0.5), {Intensity=0,Size=30,Threshold=0}):Play()
	end)

	registerMarker("Disappear", function()
		restoreLightingState(savedState, 9)

		script.ScreenGui.Vignette.ImageColor3          = Color3.fromRGB(255,255,255)
		script.ScreenGui.Vignette.BackgroundColor3     = Color3.fromRGB(255,255,255)
		script.ScreenGui.Vignette.ImageTransparency    = 0
		script.ScreenGui.Vignette.BackgroundTransparency = 0
		TweenService:Create(script.ScreenGui.Vignette, TC(9, Enum.EasingStyle.Linear), {ImageTransparency=1}):Play()
		TweenService:Create(script.ScreenGui.Vignette, TC(7, Enum.EasingStyle.Linear), {BackgroundTransparency=1}):Play()

		local particlePart = Instance.new("Part", effectFolder)
		particlePart.Position = giantModel.UpperTorso.Position
		script.Vanish:Clone().Parent = particlePart
		particlePart.Vanish:Emit(15)

		currentWingedGiant = nil; currentWings = nil; currentArms = nil

		pcall(function() giantModel:Destroy()      end)
		pcall(function() bloomEffect:Destroy()     end)
		pcall(function() colorCorrection:Destroy() end)
		pcall(function() atmosphere:Destroy()      end)
		destroyEffectLightingInstances()

		isSpawningDebris = false

		sounds.PlayerVanish1:Play(); sounds.PlayerVanish2:Play(); sounds.PlayerVanish3:Play()

		W(10)
		pcall(function() particlePart:Destroy() end)
		pcall(function() debrisModel:Destroy()  end)
		pcall(function() sounds:Destroy()       end)

		for _, cube in pairs(trashFolder:GetChildren()) do
			if cube.Name=="Block" then pcall(function() cube:Destroy() end) end
		end

		W(30)
		cameraShaker:Stop()
		pcall(function() effectFolder:Destroy() end)
		pcall(function() disconnectConn:Disconnect() end)
	end)

	-- Fallback Timer dengan timing persis KeyframeSequence
	-- Hanya berjalan jika animasi gagal diputar!
	task.spawn(function()
		task.wait(2.0 * M)
		if mainAnimation and mainAnimation.IsPlaying and mainAnimation.Length > 10 then
			return
		end
		task.wait((2.933 - 2.0) * M)
		triggerMarker("ChargeApperance")
		task.wait((5.033 - 2.933) * M)
		triggerMarker("Reveal")
		task.wait((9.825 - 5.033) * M)
		triggerMarker("PingSound")
		task.wait((11.075 - 9.825) * M)
		triggerMarker("Clap")
		task.wait((11.508 - 11.075) * M)
		triggerMarker("OrbFormation")
		task.wait((18.183 - 11.508) * M)
		triggerMarker("OrbLaunch")
		task.wait((27.492 - 18.183) * M)
		triggerMarker("DisappearStart")
		task.wait((30.000 - 27.492) * M)
		triggerMarker("Disappear")
	end)

	-- Hard Safety Timeout (60s)
	task.delay(60, function()
		if effectFolder and effectFolder.Parent then
			pcall(function() effectFolder:Destroy() end)
		end
	end)
end

local lastStarfallTime = 0
effectsEvent.OnClientEvent:Connect(function(effectType, donorName, recipientName, amount, userId, currency)
	if isDonationEffectHidden() then
		return -- Hide Effect Donate aktif: Jangan putar efek sama sekali agar HP kentang tidak lag!
	end
	if effectType == "Starfall" then
		local now = os.clock()
		if now - lastStarfallTime < 4 then
			return -- Debounce pencegah dobel
		end
		lastStarfallTime = now
		task.spawn(function()
			local ok, err = pcall(playStarfallEffect, donorName, recipientName, amount, userId, currency)
			if not ok then
				warn("[Starfall ERROR]", err)
				destroyEffectLightingInstances()
				local ae = workspace:FindFirstChild("ActiveEffects")
				if ae then
					for _, f in ipairs(ae:GetChildren()) do
						if f.Name:find("^Starfall_") then pcall(function() f:Destroy() end) end
					end
				end
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player ~= localPlayer then return end
	destroyEffectLightingInstances()
	local ae = workspace:FindFirstChild("ActiveEffects")
	if ae then
		for _, f in ipairs(ae:GetChildren()) do
			if f.Name:find("^Starfall_") then pcall(function() f:Destroy() end) end
		end
	end
end)