local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerEffectState = {}
PlayerEffectState.__index = PlayerEffectState

function PlayerEffectState.new(player, config, animationRegistry, notificationEvent)
	local self = setmetatable({}, PlayerEffectState)
	
	self.Player = player
	self.Character = player.Character -- [TAMBAHKAN INI]: Kunci tubuh aslinya
	self.Config = config
	self.AnimationRegistry = animationRegistry
	self.NotificationEvent = notificationEvent
	
	self.FloatingTrack = nil
	self.FlyTrack = nil
	self.FlyAttachment = nil
	self.FlyAlignPosition = nil
	self.FlyAlignOrientation = nil
	self.EquippedWing = nil
	self.SuspendedDanceTracks = nil
	self.ToolBlockConnection = nil
	
	-- Build lookup set of all registered dance and pose numeric IDs for quick check
	self.RegisteredAnimIds = {}
	for _, id in pairs(self.AnimationRegistry.Dances) do
		local numId = self:_getNumericId(id)
		if numId ~= "" then
			self.RegisteredAnimIds[numId] = true
		end
	end
	for _, id in pairs(self.AnimationRegistry.Poses) do
		local numId = self:_getNumericId(id)
		if numId ~= "" then
			self.RegisteredAnimIds[numId] = true
		end
	end

	return self
end

function PlayerEffectState:_getNumericId(id)
	if not id then return "" end
	return string.match(tostring(id), "%d+") or ""
end

function PlayerEffectState:_getItemOffset(itemName, torsoType)
	local offsetConfigs = {
		["Wings1"] = CFrame.new(0, 1, 1),
		["Wings2"] = CFrame.new(0, 1, 0.5),
		["AngelWings"] = CFrame.new(0, 1.2, 1.2),
		["DemonWings"] = CFrame.new(0, 1.2, 1.2),
		["Wing"] = CFrame.new(0, 1, 1),
	}
	local defaultOffset = CFrame.new(0, 1, 1)
	return offsetConfigs[itemName] or defaultOffset
end

function PlayerEffectState:ForceUnequipTools()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end
	local backpack = self.Player:FindFirstChild("Backpack")
	if not backpack then return end
	
	local unequipped = false
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			child.Parent = backpack
			unequipped = true
		end
	end
	
	if unequipped and self.NotificationEvent then
		self.NotificationEvent:FireClient(self.Player, "Efek Aktif", "Alat otomatis disimpan karena kamu sedang terbang/melayang!", 3)
	end
end

function PlayerEffectState:SuspendDance()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not animator then return end
	
	if self.SuspendedDanceTracks then return end
	
	local currentDanceID = char:GetAttribute("CurrentDanceID")
	
	local syncTarget = char:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		local leaderPlayer = Players:FindFirstChild(syncTarget)
		if leaderPlayer and leaderPlayer.Character then
			currentDanceID = leaderPlayer.Character:GetAttribute("CurrentDanceID")
		end
	end
	
	local currentDanceNumeric = self:_getNumericId(currentDanceID)
	
	local suspended = {}
	local foundActive = false
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation then
			local trackNumericId = self:_getNumericId(track.Animation.AnimationId)
			if trackNumericId ~= "" then
				if currentDanceNumeric ~= "" and trackNumericId == currentDanceNumeric then
					foundActive = true
					table.insert(suspended, {
						AnimationId = currentDanceID,
						TimePosition = track.TimePosition,
						Weight = track.WeightTarget,
						Speed = track.Speed
					})
					track:Stop(0.1)
				elseif self.RegisteredAnimIds[trackNumericId] then
					track:Stop(0.1)
				end
			end
		end
	end
	
	if not foundActive and currentDanceID then
		local speedAttr = char:GetAttribute("DanceSpeed") or 1
		table.insert(suspended, {
			AnimationId = currentDanceID,
			TimePosition = 0,
			Weight = 1,
			Speed = speedAttr
		})
	end
	
	self.SuspendedDanceTracks = suspended
end

function PlayerEffectState:ResumeDance()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end
	
	char:SetAttribute("GlobalEffectActive", nil)
	
	if self.ToolBlockConnection then
		self.ToolBlockConnection:Disconnect()
		self.ToolBlockConnection = nil
	end
	
	if self.SuspendedDanceTracks then
		local humanoid = char:FindFirstChild("Humanoid")
		local animator = humanoid and humanoid:FindFirstChild("Animator")
		
		if animator then
			for _, danceData in ipairs(self.SuspendedDanceTracks) do
				local anim = Instance.new("Animation")
				anim.AnimationId = danceData.AnimationId
				local track = animator:LoadAnimation(anim)
				anim:Destroy() -- Cegah memory leak
				
				track:Play()
				track:AdjustWeight(danceData.Weight)
				track:AdjustSpeed(danceData.Speed)
				
				task.defer(function()
					if track.IsPlaying then
						track.TimePosition = danceData.TimePosition
					end
				end)
			end
		end
	end
	
	self.SuspendedDanceTracks = nil
end

function PlayerEffectState:StopCustomAnimations()
	if self.FloatingTrack then
		self.FloatingTrack:Stop()
		self.FloatingTrack:Destroy()
		self.FloatingTrack = nil
	end
	if self.FlyTrack then
		self.FlyTrack:Stop()
		self.FlyTrack:Destroy()
		self.FlyTrack = nil
	end
end

function PlayerEffectState:ApplyFloating()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Anti-Sangkut di kursi
	if humanoid.Sit then
		humanoid.Sit = false
		task.wait(0.1)
	end
	
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

	self:RemoveFly()
	self:ForceUnequipTools()
	self:StopCustomAnimations()
	
	self:SuspendDance()
	char:SetAttribute("GlobalEffectActive", true)

	if not self.ToolBlockConnection then
		self.ToolBlockConnection = char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				if not char:GetAttribute("GlobalEffectActive") then return end
				task.defer(function()
					if self.Player and self.Player:FindFirstChild("Backpack") then
						child.Parent = self.Player.Backpack
						if self.NotificationEvent then
							self.NotificationEvent:FireClient(self.Player, "Efek Aktif", "Alat dikunci saat terbang!", 3)
						end
					end
				end)
			end
		end)
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = self.Config.FloatingAnimationId
	local track = animator:LoadAnimation(anim)
	anim:Destroy() -- FIX: Cegah Memory Leak!
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play()

	self.FloatingTrack = track
end

function PlayerEffectState:RemoveFloating()
	if self.FloatingTrack then
		self.FloatingTrack:Stop()
		self.FloatingTrack:Destroy()
		self.FloatingTrack = nil
	end
end

function PlayerEffectState:ApplyFly()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	
	-- Anti-Sangkut di kursi
	if humanoid.Sit then
		humanoid.Sit = false
		task.wait(0.1) 
	end
	
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

	self:RemoveFloating()
	self:ForceUnequipTools()
	self:StopCustomAnimations()

	self:SuspendDance()
	char:SetAttribute("GlobalEffectActive", true)
	
	-- [FIX FISIKA SEJATI]: Kunci otoritas fisika ke Server agar tidak goyang (rubberband)
	if rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(nil)
	end

	if not self.ToolBlockConnection then
		self.ToolBlockConnection = char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				if not char:GetAttribute("GlobalEffectActive") then return end
				task.defer(function()
					if self.Player and self.Player:FindFirstChild("Backpack") then
						child.Parent = self.Player.Backpack
						if self.NotificationEvent then
							self.NotificationEvent:FireClient(self.Player, "Efek Aktif", "Alat dikunci saat terbang!", 3)
						end
					end
				end)
			end
		end)
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = self.Config.FlyAnimationId
	local track = animator:LoadAnimation(anim)
	anim:Destroy() -- FIX: Cegah Memory Leak!
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play()

	self.FlyTrack = track

	if not self.FlyAttachment or not self.FlyAttachment.Parent then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GlobalFlyAttachment"
		attachment.Parent = rootPart
		self.FlyAttachment = attachment

		local alignPos = Instance.new("AlignPosition")
		alignPos.Name = "GlobalFlyAlignPosition"
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPos.Attachment0 = attachment
		
		local targetY = self.Config.FlyHeight
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {char}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local rayResult = workspace:Raycast(rootPart.Position, Vector3.new(0, targetY + 2, 0), rayParams)
		if rayResult then
			local safeDistance = rayResult.Distance - 3
			targetY = math.max(0, safeDistance)
		end
		
		alignPos.Position = rootPart.Position + Vector3.new(0, targetY, 0)
		alignPos.MaxForce = 1000000
		alignPos.MaxVelocity = self.Config.FlySpeed
		alignPos.Responsiveness = 200
		alignPos.Parent = rootPart
		self.FlyAlignPosition = alignPos
		
		local alignOri = Instance.new("AlignOrientation")
		alignOri.Name = "GlobalFlyAlignOrientation"
		alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOri.Attachment0 = attachment
		
		local lv = rootPart.CFrame.LookVector
		local horizontalLook = Vector3.new(lv.X, 0, lv.Z)
		if horizontalLook.Magnitude < 0.001 then
			horizontalLook = Vector3.new(0, 0, -1)
		else
			horizontalLook = horizontalLook.Unit
		end
		alignOri.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + horizontalLook)
		
		alignOri.MaxTorque = 1000000
		alignOri.Responsiveness = 200
		alignOri.Parent = rootPart
		self.FlyAlignOrientation = alignOri
		
		humanoid.PlatformStand = true
	end
end

function PlayerEffectState:RemoveFly()
	if self.FlyAlignOrientation then
		self.FlyAlignOrientation:Destroy()
		self.FlyAlignOrientation = nil
	end
	if self.FlyAlignPosition then
		self.FlyAlignPosition:Destroy()
		self.FlyAlignPosition = nil
	end
	if self.FlyAttachment then
		self.FlyAttachment:Destroy()
		self.FlyAttachment = nil
	end
	if self.FlyTrack then
		self.FlyTrack:Stop()
		self.FlyTrack:Destroy()
		self.FlyTrack = nil
	end
	
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	
	-- [UBAH INI]: Gunakan self.Character, JANGAN self.Player.Character
	local char = self.Character 
	if char and char.Parent then
		local humanoid = char:FindFirstChild("Humanoid")
		local rootPart = char:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		
		if rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			
			-- Kembalikan hak gerak ke Pemain
			if rootPart:CanSetNetworkOwnership() then
				rootPart:SetNetworkOwner(self.Player)
			end
		end
	end
end

function PlayerEffectState:ApplyWing()
	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	local char = self.Player.Character
	if not char then return end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso then return end
	
	if self.EquippedWing and self.EquippedWing.Parent == char then
		return 
	end

	local ItemModel = ReplicatedStorage:FindFirstChild("Wing")
	if not ItemModel then
		warn("Model 'Wing' tidak ditemukan di ReplicatedStorage!")
		return
	end

	if char:FindFirstChild(ItemModel.Name) then return end

	local item = ItemModel:Clone()
	item.Name = ItemModel.Name 

	local promptInClone = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if promptInClone then promptInClone:Destroy() end

	local itemHandle = item:FindFirstChild("Handle")
	if not itemHandle then
		itemHandle = item:FindFirstChildWhichIsA("BasePart")
		if itemHandle then
			local newHandle = Instance.new("Part")
			newHandle.Name = "Handle"
			newHandle.Size = Vector3.new(0.1, 0.1, 0.1)
			newHandle.Transparency = 1
			newHandle.CanCollide = false
			newHandle.Anchored = false
			newHandle.Parent = item

			for _, part in ipairs(item:GetDescendants()) do -- Gunakan GetDescendants
				if part:IsA("BasePart") and part ~= newHandle then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = newHandle
					weld.Part1 = part
					weld.Parent = part
				end
			end
			itemHandle = newHandle
		end
	end

	if itemHandle then
		local offset = self:_getItemOffset(ItemModel.Name, torso.Name)
		itemHandle.CFrame = torso.CFrame * offset

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = itemHandle
		weld.Parent = itemHandle
	end

	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
			part.Massless = true
		end
	end

	item.Parent = char
	self.EquippedWing = item
end

function PlayerEffectState:RemoveWing()
	if self.EquippedWing then
		self.EquippedWing:Destroy()
		self.EquippedWing = nil
	end
end

function PlayerEffectState:Destroy()
	if self.ToolBlockConnection then
		self.ToolBlockConnection:Disconnect()
		self.ToolBlockConnection = nil
	end

	if not self.Player or typeof(self.Player) ~= "Instance" or not self.Player.Parent then return end
	self:StopCustomAnimations()
	self:RemoveFly()
	self:RemoveWing()
	self:ResumeDance()
	self.Player = nil
end

return PlayerEffectState
