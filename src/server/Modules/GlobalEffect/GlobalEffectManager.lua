local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerEffectState = require(script.Parent.PlayerEffectState)

local GlobalEffectManager = {}
GlobalEffectManager.__index = GlobalEffectManager

function GlobalEffectManager.new()
	local self = setmetatable({}, GlobalEffectManager)
	
	self.Config = {
		FloatingAnimationId = "rbxassetid://112082806790047", 
		FlyAnimationId = "rbxassetid://81229486815853",      
		FlyHeight = 50,                         
		FlySpeed = 2,                           
	}
	
	self.ActiveEffects = {
		Camera360 = false,
		Floating = false,
		Fly = false,
		Wing = false,
	}
	
	self.PlayerStates = {}
	
	return self
end

function GlobalEffectManager:Init()
	self.RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))
	
	local syncServer = ServerScriptService:WaitForChild("SyncServer")
	self.AnimationRegistry = require(syncServer:WaitForChild("Modules"):WaitForChild("AnimationRegistry"))
	
	self:_setupRemotes()
	self:_setupEvents()
end

function GlobalEffectManager:_setupRemotes()
	local GlobalEffectRemotes = ReplicatedStorage:FindFirstChild("GlobalEffectRemotes")
	if not GlobalEffectRemotes then
		GlobalEffectRemotes = Instance.new("Folder")
		GlobalEffectRemotes.Name = "GlobalEffectRemotes"
		GlobalEffectRemotes.Parent = ReplicatedStorage
	end

	self.ToggleEffectEvent = GlobalEffectRemotes:FindFirstChild("ToggleEffect")
	if not self.ToggleEffectEvent then
		self.ToggleEffectEvent = Instance.new("RemoteEvent")
		self.ToggleEffectEvent.Name = "ToggleEffect"
		self.ToggleEffectEvent.Parent = GlobalEffectRemotes
	end

	self.CameraEffectEvent = GlobalEffectRemotes:FindFirstChild("CameraEffect")
	if not self.CameraEffectEvent then
		self.CameraEffectEvent = Instance.new("RemoteEvent")
		self.CameraEffectEvent.Name = "CameraEffect"
		self.CameraEffectEvent.Parent = GlobalEffectRemotes
	end

	self.CheckOwnerFunction = GlobalEffectRemotes:FindFirstChild("CheckOwner")
	if not self.CheckOwnerFunction then
		self.CheckOwnerFunction = Instance.new("RemoteFunction")
		self.CheckOwnerFunction.Name = "CheckOwner"
		self.CheckOwnerFunction.Parent = GlobalEffectRemotes
	end

	self.NotificationEvent = GlobalEffectRemotes:FindFirstChild("NotificationEvent")
	if not self.NotificationEvent then
		self.NotificationEvent = Instance.new("RemoteEvent")
		self.NotificationEvent.Name = "NotificationEvent"
		self.NotificationEvent.Parent = GlobalEffectRemotes
	end
	
	self.ToggleNotificationEvent = GlobalEffectRemotes:FindFirstChild("ToggleNotification")
	if not self.ToggleNotificationEvent then
		self.ToggleNotificationEvent = Instance.new("RemoteEvent")
		self.ToggleNotificationEvent.Name = "ToggleNotification"
		self.ToggleNotificationEvent.Parent = GlobalEffectRemotes
	end

	self.ToggleFollowEvent = GlobalEffectRemotes:FindFirstChild("ToggleFollow")
	if not self.ToggleFollowEvent then
		self.ToggleFollowEvent = Instance.new("RemoteEvent")
		self.ToggleFollowEvent.Name = "ToggleFollow"
		self.ToggleFollowEvent.Parent = GlobalEffectRemotes
	end
	
	self.CheckOwnerFunction.OnServerInvoke = function(player)
		for _, id in ipairs(self.RoleSystem.Config.OwnerIds) do
			if player.UserId == id then
				return true
			end
		end
		return false
	end
	
	self.ToggleEffectEvent.OnServerEvent:Connect(function(player, effectName, isActive)
		self:_handleToggleEffect(player, effectName, isActive)
	end)
	
	self.ToggleFollowEvent.OnServerEvent:Connect(function(player, isFollowing)
		player:SetAttribute("FollowGlobalEffect", isFollowing)
		self:UpdatePlayerEffects(player)
		
		if isFollowing and self.ActiveEffects.Camera360 then
			self.CameraEffectEvent:FireClient(player, true)
		elseif not isFollowing and self.ActiveEffects.Camera360 then
			self.CameraEffectEvent:FireClient(player, false)
		end
	end)
end

function GlobalEffectManager:_handleToggleEffect(player, effectName, isActive)
	local isOwner = false
	for _, id in ipairs(self.RoleSystem.Config.OwnerIds) do
		if player.UserId == id then
			isOwner = true
			break
		end
	end
	
	if not isOwner then
		warn(player.Name .. " mencoba menggunakan Global Effect tapi bukan Owner!")
		return
	end
	
	if effectName == "ClearAll" then
		self:ClearAllEffects()
		return
	end

	local wasActive = false
	for _, state in pairs(self.ActiveEffects) do
		if state then wasActive = true end
	end

	if self.ActiveEffects[effectName] ~= nil then
		self.ActiveEffects[effectName] = isActive
		
		local isNowActive = false
		for _, state in pairs(self.ActiveEffects) do
			if state then isNowActive = true end
		end

		if not wasActive and isNowActive then
			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("FollowGlobalEffect", true)
			end
			self.ToggleNotificationEvent:FireAllClients(true)
		elseif wasActive and not isNowActive then
			self.ToggleNotificationEvent:FireAllClients(false)
		end
		
		if effectName == "Camera360" then
			-- Send 360 only to those following
			for _, p in ipairs(Players:GetPlayers()) do
				local isFollowing = p:GetAttribute("FollowGlobalEffect")
				if isFollowing == nil then isFollowing = true end
				if isFollowing then
					self.CameraEffectEvent:FireClient(p, isActive)
				end
			end
		else
			self:UpdateAllPlayers()
		end
	end
end

function GlobalEffectManager:ClearAllEffects()
	local was360Active = self.ActiveEffects.Camera360
	
	self.ActiveEffects.Camera360 = false
	self.ActiveEffects.Floating = false
	self.ActiveEffects.Fly = false
	self.ActiveEffects.Wing = false
	
	self.ToggleNotificationEvent:FireAllClients(false)
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("FollowGlobalEffect", true)
	end
	
	self:UpdateAllPlayers()
	
	if was360Active then
		self.CameraEffectEvent:FireAllClients(false)
	end
end

function GlobalEffectManager:GetPlayerState(player)
	if not self.PlayerStates[player] then
		self.PlayerStates[player] = PlayerEffectState.new(player, self.Config, self.AnimationRegistry, self.NotificationEvent)
	end
	return self.PlayerStates[player]
end

function GlobalEffectManager:_onCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	
	if character:GetAttribute("EffectLoaded") then return end
	character:SetAttribute("EffectLoaded", true)
	
	-- Clear old state before applying to new char
	if self.PlayerStates[player] then
		self.PlayerStates[player]:Destroy()
		self.PlayerStates[player] = nil
	end
	
	local state = self:GetPlayerState(player)
	
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			if self.ActiveEffects.Floating or self.ActiveEffects.Fly then
				task.defer(function()
					local backpack = player:FindFirstChild("Backpack")
					if backpack and child.Parent == character then
						child.Parent = backpack
						if self.NotificationEvent then
							self.NotificationEvent:FireClient(player, "Tidak Bisa Memakai Alat", "Kamu tidak bisa memakai alat saat Global Effect sedang aktif!", 3)
						end
					end
				end)
			end
		end
	end)
	
	character:GetAttributeChangedSignal("RefreshTrigger"):Connect(function()
		-- 🔥 FIX: Hancurkan state lama, dan pastikan kita membuat instance State baru!
		state:Destroy()
		self.PlayerStates[player] = nil
		
		task.wait(0.5)
		
		-- Buat state baru untuk karakter yang sudah di-refresh
		state = self:GetPlayerState(player)
		
		if self.ActiveEffects.Floating then state:ApplyFloating() end
		if self.ActiveEffects.Fly then state:ApplyFly() end
		if self.ActiveEffects.Wing then state:ApplyWing() end
	end)
	
	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	
	if not humanoid or not rootPart then return end
	
	task.wait(0.5) 
	
	if not character.Parent or not player.Character or player.Character ~= character then return end
	
	self:UpdatePlayerEffects(player)
end

function GlobalEffectManager:_setupEvents()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAppearanceLoaded:Connect(function(char)
			self:_onCharacterAdded(char)
		end)
		
		player.CharacterAdded:Connect(function(char)
			task.delay(3, function()
				if player.Character == char and not char:GetAttribute("EffectLoaded") then
					char:SetAttribute("EffectLoaded", true)
					self:_onCharacterAdded(char)
				end
			end)
		end)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		local isOwner = false
		for _, id in ipairs(self.RoleSystem.Config.OwnerIds) do
			if player.UserId == id then
				isOwner = true
				break
			end
		end
		
		if isOwner then
			local otherOwnerOnline = false
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then
					for _, id in ipairs(self.RoleSystem.Config.OwnerIds) do
						if p.UserId == id then
							otherOwnerOnline = true
							break
						end
					end
				end
				if otherOwnerOnline then break end
			end
			
			if not otherOwnerOnline then
				self:ClearAllEffects()
			end
		end

		-- 🔥 FIX MEMORY LEAK: Hapus state SETELAH ClearAllEffects()
		-- agar fungsi UpdateAllPlayers() tidak membuat State baru untuk player yang akan keluar!
		if self.PlayerStates[player] then
			self.PlayerStates[player]:Destroy()
			self.PlayerStates[player] = nil
		end
	end)
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function() self:_onCharacterAdded(player.Character) end)
		end
		player.CharacterAppearanceLoaded:Connect(function(char)
			self:_onCharacterAdded(char)
		end)
		
		player.CharacterAdded:Connect(function(char)
			task.delay(3, function()
				if player.Character == char and not char:GetAttribute("EffectLoaded") then
					char:SetAttribute("EffectLoaded", true)
					self:_onCharacterAdded(char)
				end
			end)
		end)
	end
end

function GlobalEffectManager:UpdateAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		self:UpdatePlayerEffects(player)
	end
end

function GlobalEffectManager:UpdatePlayerEffects(player)
	if player.Character then
		local state = self:GetPlayerState(player)
		local isFollowing = player:GetAttribute("FollowGlobalEffect")
		if isFollowing == nil then isFollowing = true end
		
		local shouldFloating = self.ActiveEffects.Floating and isFollowing
		local shouldFly = self.ActiveEffects.Fly and isFollowing
		local shouldWing = self.ActiveEffects.Wing and isFollowing

		player:SetAttribute("GlobalEffectAirborne", shouldFloating or shouldFly)

		if shouldFloating or shouldFly then
			local CarryEventsFolder = ServerStorage:FindFirstChild("CarryEvents")
			if CarryEventsFolder then
				local ForceEndCarryFunc = CarryEventsFolder:FindFirstChild("ForceEndCarryFunc")
				if ForceEndCarryFunc then
					pcall(function()
						local dropped = ForceEndCarryFunc:Invoke(player)
						if dropped and self.NotificationEvent then
							self.NotificationEvent:FireClient(player, "Global Effect Aktif", "Carry otomatis dilepas karena efek sedang aktif!", 3)
						end
					end)
				end
			end
		end

		if shouldFloating then
			if not state.FloatingTrack then
				state:ApplyFloating()
			end
		else
			if state.FloatingTrack then
				state:RemoveFloating()
			end
		end

		if shouldFly then
			if not state.FlyTrack then
				state:ApplyFly()
			end
		else
			if state.FlyTrack then
				state:RemoveFly()
			end
		end
		
		if not shouldFloating and not shouldFly then
			state:ResumeDance()
		end

		if shouldWing then
			state:ApplyWing()
		else
			state:RemoveWing()
		end
	end
end

return GlobalEffectManager
