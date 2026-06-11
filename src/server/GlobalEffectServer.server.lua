local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create RemoteEvents
local GlobalEffectRemotes = ReplicatedStorage:FindFirstChild("GlobalEffectRemotes")
if not GlobalEffectRemotes then
	GlobalEffectRemotes = Instance.new("Folder")
	GlobalEffectRemotes.Name = "GlobalEffectRemotes"
	GlobalEffectRemotes.Parent = ReplicatedStorage
end

local ToggleEffectEvent = GlobalEffectRemotes:FindFirstChild("ToggleEffect")
if not ToggleEffectEvent then
	ToggleEffectEvent = Instance.new("RemoteEvent")
	ToggleEffectEvent.Name = "ToggleEffect"
	ToggleEffectEvent.Parent = GlobalEffectRemotes
end

local CameraEffectEvent = GlobalEffectRemotes:FindFirstChild("CameraEffect")
if not CameraEffectEvent then
	CameraEffectEvent = Instance.new("RemoteEvent")
	CameraEffectEvent.Name = "CameraEffect"
	CameraEffectEvent.Parent = GlobalEffectRemotes
end

local CheckOwnerFunction = GlobalEffectRemotes:FindFirstChild("CheckOwner")
if not CheckOwnerFunction then
	CheckOwnerFunction = Instance.new("RemoteFunction")
	CheckOwnerFunction.Name = "CheckOwner"
	CheckOwnerFunction.Parent = GlobalEffectRemotes
end

local NotificationEvent = GlobalEffectRemotes:FindFirstChild("NotificationEvent")
if not NotificationEvent then
	NotificationEvent = Instance.new("RemoteEvent")
	NotificationEvent.Name = "NotificationEvent"
	NotificationEvent.Parent = GlobalEffectRemotes
end

local ServerStorage = game:GetService("ServerStorage")
local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

local ServerScriptService = game:GetService("ServerScriptService")
local SyncServer = ServerScriptService:WaitForChild("SyncServer")
local AnimationRegistry = require(SyncServer:WaitForChild("Modules"):WaitForChild("AnimationRegistry"))

local function getNumericId(id)
	if not id then return "" end
	return string.match(tostring(id), "%d+") or ""
end

-- Build lookup set of all registered dance and pose numeric IDs
local RegisteredAnimIds = {}
for _, id in pairs(AnimationRegistry.Dances) do
	local numId = getNumericId(id)
	if numId ~= "" then
		RegisteredAnimIds[numId] = true
	end
end
for _, id in pairs(AnimationRegistry.Poses) do
	local numId = getNumericId(id)
	if numId ~= "" then
		RegisteredAnimIds[numId] = true
	end
end

CheckOwnerFunction.OnServerInvoke = function(player)
	for _, id in ipairs(RoleSystem.Config.OwnerIds) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

-- ==========================================
-- ⚙️ KONFIGURASI GLOBAL
-- ==========================================
local Config = {
	FloatingAnimationId = "rbxassetid://112082806790047", -- Ganti dengan ID Animasi Floating
	FlyAnimationId = "rbxassetid://81229486815853",      -- Ganti dengan ID Animasi Fly
	FlyHeight = 50,                         -- Batas terbang (studs)
	FlySpeed = 2,                           -- Kecepatan terbang ke atas (studs per second), kecilkan untuk lebih lambat
}

-- Kategori items untuk Wing
local itemCategories = {
	["Wings1"] = "Wings",
	["Wings2"] = "Wings", 
	["AngelWings"] = "Wings",
	["DemonWings"] = "Wings",
	["Wing"] = "Wings", -- Nama model default yang kamu sebut
}

local offsetConfigs = {
	["Wings1"] = CFrame.new(0, 1, 1),
	["Wings2"] = CFrame.new(0, 1, 0.5),
	["AngelWings"] = CFrame.new(0, 1.2, 1.2),
	["DemonWings"] = CFrame.new(0, 1.2, 1.2),
	["Wing"] = CFrame.new(0, 1, 1), -- Offset untuk model Wing
}

local function getItemOffset(itemName, torsoType)
	local isR15 = (torsoType == "UpperTorso")
	local defaultOffset = CFrame.new(0, 1, 1)
	return offsetConfigs[itemName] or defaultOffset
end

-- ==========================================
-- STATE AKTIF
-- ==========================================
local ActiveEffects = {
	Camera360 = false,
	Floating = false,
	Fly = false,
	Wing = false,
}

-- Tabel untuk melacak object/track yang sedang aktif per player
local PlayerStates = {}

local function getPlayerState(player)
	if not PlayerStates[player] then
		PlayerStates[player] = {
			FloatingTrack = nil,
			FlyTrack = nil,
			FlyAttachment = nil,
			FlyAlignPosition = nil,
			FlyAlignOrientation = nil,
			EquippedWing = nil,
			SuspendedDanceTracks = nil,
		}
	end
	return PlayerStates[player]
end

-- ==========================================
-- FUNGSI EFEK & STATE DANCE
-- ==========================================

local function suspendDance(player)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	if not animator then return end
	
	local state = getPlayerState(player)
	if state.SuspendedDanceTracks then return end -- Sudah tersimpan, jangan ditimpa
	
	local currentDanceID = char:GetAttribute("CurrentDanceID")
	
	-- Cek apakah dia follower
	local syncTarget = char:GetAttribute("Syncing")
	if syncTarget and syncTarget ~= "" then
		local leaderPlayer = Players:FindFirstChild(syncTarget)
		if leaderPlayer and leaderPlayer.Character then
			currentDanceID = leaderPlayer.Character:GetAttribute("CurrentDanceID")
		end
	end
	
	local currentDanceNumeric = getNumericId(currentDanceID)
	
	local suspended = {}
	local foundActive = false
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation then
			local trackNumericId = getNumericId(track.Animation.AnimationId)
			if trackNumericId ~= "" then
				-- Jika track ini cocok dengan tarian aktif saat ini, simpan untuk nanti di-resume
				if currentDanceNumeric ~= "" and trackNumericId == currentDanceNumeric then
					foundActive = true
					table.insert(suspended, {
						AnimationId = currentDanceID, -- Simpan original formatnya
						TimePosition = track.TimePosition,
						Weight = track.WeightTarget,
						Speed = track.Speed
					})
					track:Stop(0.1)
				elseif RegisteredAnimIds[trackNumericId] then
					-- Jika ini tarian/pose lain yang terdaftar, stop juga agar tidak double/tumpang tindih
					track:Stop(0.1)
				end
			end
		end
	end
	
	-- Failsafe jika track tidak ditemukan di server tetapi tarian aktif di atribut
	if not foundActive and currentDanceID then
		local speedAttr = char:GetAttribute("DanceSpeed") or 1
		table.insert(suspended, {
			AnimationId = currentDanceID,
			TimePosition = 0,
			Weight = 1,
			Speed = speedAttr
		})
	end
	
	state.SuspendedDanceTracks = suspended
end

local function resumeDance(player)
	local char = player.Character
	if not char then return end
	
	-- Jangan resume jika salah satu efek animasi custom (Floating/Fly) masih aktif
	if ActiveEffects.Floating or ActiveEffects.Fly then return end
	
	char:SetAttribute("GlobalEffectActive", nil)
	
	local state = getPlayerState(player)
	state.SuspendedDanceTracks = nil
end

-- Menghentikan semua animasi custom (Floating/Fly) untuk player
local function stopCustomAnimations(player)
	local state = getPlayerState(player)
	if state.FloatingTrack then
		state.FloatingTrack:Stop()
		state.FloatingTrack:Destroy()
		state.FloatingTrack = nil
	end
	if state.FlyTrack then
		state.FlyTrack:Stop()
		state.FlyTrack:Destroy()
		state.FlyTrack = nil
	end
end

local function forceUnequipTools(player)
	local char = player.Character
	if not char then return end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	
	local unequipped = false
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			child.Parent = backpack
			unequipped = true
		end
	end
	
	if unequipped and NotificationEvent then
		NotificationEvent:FireClient(player, "Efek Aktif", "Alat otomatis disimpan karena kamu sedang terbang/melayang!", 3)
	end
end

-- Floating
local function applyFloating(player)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

	forceUnequipTools(player)
	stopCustomAnimations(player)
	
	-- Sembunyikan tarian (jangan distop agar tak rusak)
	suspendDance(player)
	char:SetAttribute("GlobalEffectActive", true)

	local anim = Instance.new("Animation")
	anim.AnimationId = Config.FloatingAnimationId
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4 -- Paksa menimpa dance
	track.Looped = true
	track:Play()

	getPlayerState(player).FloatingTrack = track
end

-- Fly
local function applyFly(player)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)

	forceUnequipTools(player)
	stopCustomAnimations(player)

	-- Sembunyikan tarian (jangan distop agar tak rusak)
	suspendDance(player)
	char:SetAttribute("GlobalEffectActive", true)

	local anim = Instance.new("Animation")
	anim.AnimationId = Config.FlyAnimationId
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play()

	local state = getPlayerState(player)
	state.FlyTrack = track

	-- Membuat efek melayang ke atas
	if not state.FlyAttachment or not state.FlyAttachment.Parent then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GlobalFlyAttachment"
		attachment.Parent = rootPart
		state.FlyAttachment = attachment

		local alignPos = Instance.new("AlignPosition")
		alignPos.Name = "GlobalFlyAlignPosition"
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPos.Attachment0 = attachment
		alignPos.Position = rootPart.Position + Vector3.new(0, Config.FlyHeight, 0)
		alignPos.MaxForce = 1000000 -- Diperbesar agar kuat menahan beban
		alignPos.MaxVelocity = Config.FlySpeed
		alignPos.Responsiveness = 200
		alignPos.Parent = rootPart
		state.FlyAlignPosition = alignPos
		
		-- AlignOrientation agar tidak goyang/tumble
		local alignOri = Instance.new("AlignOrientation")
		alignOri.Name = "GlobalFlyAlignOrientation"
		alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOri.Attachment0 = attachment
		alignOri.CFrame = rootPart.CFrame
		alignOri.MaxTorque = 1000000
		alignOri.Responsiveness = 200
		alignOri.Parent = rootPart
		state.FlyAlignOrientation = alignOri
		
		-- Supaya kakinya tidak ketekuk (Animasi Fall bawaan Roblox dimatikan)
		humanoid.PlatformStand = true
	end
end

local function removeFly(player)
	local state = getPlayerState(player)
	if state.FlyAlignOrientation then
		state.FlyAlignOrientation:Destroy()
		state.FlyAlignOrientation = nil
	end
	if state.FlyAlignPosition then
		state.FlyAlignPosition:Destroy()
		state.FlyAlignPosition = nil
	end
	if state.FlyAttachment then
		state.FlyAttachment:Destroy()
		state.FlyAttachment = nil
	end
	
	-- Kembalikan pemain ke state normal
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		local rootPart = char:FindFirstChild("HumanoidRootPart")
		if humanoid then
			humanoid.PlatformStand = false
			-- Paksa state ke Freefall agar karakter langsung jatuh ke tanah
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		
		-- Pastikan velocity di-reset agar tidak nyangkut
		if rootPart then
			rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end
end

-- Wing
local function applyWing(player)
	local char = player.Character
	if not char then return end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso then return end
	
	local state = getPlayerState(player)
	if state.EquippedWing and state.EquippedWing.Parent == char then
		return -- Sudah pakai
	end

	-- Cari model Wing di ReplicatedStorage
	local ItemModel = ReplicatedStorage:FindFirstChild("Wing")
	if not ItemModel then
		warn("Model 'Wing' tidak ditemukan di ReplicatedStorage!")
		return
	end

	-- Cek apakah sudah ada wing di chara agar tidak double
	if char:FindFirstChild(ItemModel.Name) then return end

	local item = ItemModel:Clone()
	item.Name = ItemModel.Name 

	-- Hapus ProximityPrompt jika ada
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

			for _, part in ipairs(item:GetChildren()) do
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
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = itemHandle
		weld.Parent = itemHandle

		local offset = getItemOffset(ItemModel.Name, torso.Name)
		itemHandle.CFrame = torso.CFrame * offset
	end

	-- Non-collide semua parts agar tidak mengganggu pergerakan pemain
	for _, part in ipairs(item:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = false
		end
	end

	item.Parent = char
	state.EquippedWing = item
end

local function removeWing(player)
	local state = getPlayerState(player)
	if state.EquippedWing then
		state.EquippedWing:Destroy()
		state.EquippedWing = nil
	end
end

-- ==========================================
-- UPDATE SEMUA PLAYER
-- ==========================================
local function UpdateAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			-- Floating
			if ActiveEffects.Floating then
				if not getPlayerState(player).FloatingTrack then
					applyFloating(player)
				end
			else
				if getPlayerState(player).FloatingTrack then
					getPlayerState(player).FloatingTrack:Stop()
					getPlayerState(player).FloatingTrack:Destroy()
					getPlayerState(player).FloatingTrack = nil
				end
				resumeDance(player)
			end

			-- Fly
			if ActiveEffects.Fly then
				if not getPlayerState(player).FlyTrack then
					applyFly(player)
				end
			else
				if getPlayerState(player).FlyTrack then
					getPlayerState(player).FlyTrack:Stop()
					getPlayerState(player).FlyTrack:Destroy()
					getPlayerState(player).FlyTrack = nil
				end
				removeFly(player)
				resumeDance(player)
			end

			-- Wing
			if ActiveEffects.Wing then
				applyWing(player)
			else
				removeWing(player)
			end
		end
	end
end

-- Terapkan efek ke player baru yang join / respawn
local function OnCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end
	
	if character:GetAttribute("EffectLoaded") then return end
	character:SetAttribute("EffectLoaded", true)
	
	-- BERSIHKAN STATE DARI KARAKTER LAMA SEBELUM TERAPKAN KE KARAKTER BARU
	local state = getPlayerState(player)
	if state.FlyAlignOrientation then state.FlyAlignOrientation:Destroy(); state.FlyAlignOrientation = nil end
	if state.FlyAlignPosition then state.FlyAlignPosition:Destroy(); state.FlyAlignPosition = nil end
	if state.FlyAttachment then state.FlyAttachment:Destroy(); state.FlyAttachment = nil end
	if state.EquippedWing then state.EquippedWing:Destroy(); state.EquippedWing = nil end
	state.FloatingTrack = nil
	state.FlyTrack = nil
	state.SuspendedDanceTracks = nil
	
	-- Mencegah equip tool saat efek aktif
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			if ActiveEffects.Floating or ActiveEffects.Fly then
				task.defer(function()
					local backpack = player:FindFirstChild("Backpack")
					if backpack and child.Parent == character then
						child.Parent = backpack
						if NotificationEvent then
							NotificationEvent:FireClient(player, "Tidak Bisa Memakai Alat", "Kamu tidak bisa memakai alat saat Global Effect sedang aktif!", 3)
						end
					end
				end)
			end
		end
	end)
	
	-- MENDENGARKAN EVENT REFRESH (/RE) DARI REFRESH.SERVER.LUA
	character:GetAttributeChangedSignal("RefreshTrigger"):Connect(function()
		-- Bersihkan sisa-sisa efek yang hancur dihajar ApplyDescription
		local state = getPlayerState(player)
		if state.FlyAlignOrientation then state.FlyAlignOrientation:Destroy(); state.FlyAlignOrientation = nil end
		if state.FlyAlignPosition then state.FlyAlignPosition:Destroy(); state.FlyAlignPosition = nil end
		if state.FlyAttachment then state.FlyAttachment:Destroy(); state.FlyAttachment = nil end
		if state.EquippedWing then state.EquippedWing:Destroy(); state.EquippedWing = nil end
		state.FloatingTrack = nil
		state.FlyTrack = nil
		state.SuspendedDanceTracks = nil
		
		-- Beri waktu sejenak agar Roblox merakit ulang torso/rig
		task.wait(0.5)
		
		-- Pasang ulang
		if ActiveEffects.Floating then applyFloating(player) end
		if ActiveEffects.Fly then applyFly(player) end
		if ActiveEffects.Wing then applyWing(player) end
	end)
	
	-- Tunggu sampai karakter benar-benar siap secara struktur fisik
	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	
	if not humanoid or not rootPart then return end
	
	-- Tidak perlu wait terlalu lama jika kita menggunakan CharacterAppearanceLoaded
	task.wait(0.5) 
	
	-- Pastikan karakter masih hidup dan valid setelah menunggu
	if not character.Parent or not player.Character or player.Character ~= character then return end
	
	if ActiveEffects.Floating then
		applyFloating(player)
	end
	if ActiveEffects.Fly then
		applyFly(player)
	end
	if ActiveEffects.Wing then
		applyWing(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(OnCharacterAdded)
	
	-- Fallback jika CharacterAppearanceLoaded gagal terpanggil (beberapa custom character loader tidak mentrigger ini)
	player.CharacterAdded:Connect(function(char)
		task.delay(3, function()
			if player.Character == char and not char:GetAttribute("EffectLoaded") then
				char:SetAttribute("EffectLoaded", true)
				OnCharacterAdded(char)
			end
		end)
	end)
end)

-- Handle player yang sudah ada
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(OnCharacterAdded, player.Character)
	end
	player.CharacterAppearanceLoaded:Connect(OnCharacterAdded)
	
	player.CharacterAdded:Connect(function(char)
		task.delay(3, function()
			if player.Character == char and not char:GetAttribute("EffectLoaded") then
				char:SetAttribute("EffectLoaded", true)
				OnCharacterAdded(char)
			end
		end)
	end)
end

-- ==========================================
-- LISTENER REMOTE
-- ==========================================
ToggleEffectEvent.OnServerEvent:Connect(function(player, effectName, isActive)
	-- Keamanan: Pengecekan Owner
	local isOwner = false
	for _, id in ipairs(RoleSystem.Config.OwnerIds) do
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
		local was360Active = ActiveEffects.Camera360
		
		ActiveEffects.Camera360 = false
		ActiveEffects.Floating = false
		ActiveEffects.Fly = false
		ActiveEffects.Wing = false
		
		UpdateAllPlayers()
		
		if was360Active then
			CameraEffectEvent:FireAllClients(false)
		end
		return
	end

	if ActiveEffects[effectName] ~= nil then
		ActiveEffects[effectName] = isActive
		
		if effectName == "Camera360" then
			CameraEffectEvent:FireAllClients(isActive)
		else
			UpdateAllPlayers()
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Bersihkan state memory
	if PlayerStates[player] then
		stopCustomAnimations(player)
		removeFly(player)
		removeWing(player)
		PlayerStates[player] = nil
	end

	-- Cek apakah player yang keluar adalah Owner
	local isOwner = false
	for _, id in ipairs(RoleSystem.Config.OwnerIds) do
		if player.UserId == id then
			isOwner = true
			break
		end
	end
	
	if isOwner then
		-- Cek apakah masih ada Owner lain yang online
		local otherOwnerOnline = false
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				for _, id in ipairs(RoleSystem.Config.OwnerIds) do
					if p.UserId == id then
						otherOwnerOnline = true
						break
					end
				end
			end
			if otherOwnerOnline then break end
		end
		
		-- Jika ini Owner terakhir yang keluar, matikan semua Global Effect
		if not otherOwnerOnline then
			local was360Active = ActiveEffects.Camera360
			
			ActiveEffects.Camera360 = false
			ActiveEffects.Floating = false
			ActiveEffects.Fly = false
			ActiveEffects.Wing = false
			
			UpdateAllPlayers()
			
			if was360Active then
				CameraEffectEvent:FireAllClients(false)
			end
		end
	end
end)
