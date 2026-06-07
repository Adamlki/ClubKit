local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NAME = "AllPlayers"
PhysicsService:RegisterCollisionGroup(GROUP_NAME)
PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)

local function optimizePart(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP_NAME
	end
	if part:IsA("Accessory") then
		local handle = part:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CastShadow = false
		end
	end
end

-- ?? TAMBAHAN ARCHITECT: Bunuh proses fisika Humanoid yang tidak berguna
local function optimizeHumanoid(humanoid)
	local disabledStates = {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Ragdoll,
		-- GettingUp DIHAPUS agar fitur "Pose" di EmoteHandler tidak rusak!
		Enum.HumanoidStateType.Flying,
		Enum.HumanoidStateType.Seated, -- Matikan jika game Anda tidak ada kursi
	}

	for _, state in ipairs(disabledStates) do
		humanoid:SetStateEnabled(state, false)
	end
end

local function onCharacterAdded(character)
	-- [OPTIMASI SUPER]: Gunakan task.defer agar server tidak freeze saat 100 orang respawn!
	task.defer(function()
		for _, part in ipairs(character:GetDescendants()) do
			-- HANYA eksekusi jika itu Part atau Aksesoris (Lebih ringan)
			if part:IsA("BasePart") or part:IsA("Accessory") then
				optimizePart(part)
			end
		end

		-- 🔥 Eksekusi pemangkasan state Humanoid
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			optimizeHumanoid(humanoid)
		end
	end)

	-- 🔥 ARCHITECT FIX: FILTER CERDAS ANTI-SPAM
	character.DescendantAdded:Connect(function(part)
		-- Jangan panggil fungsi jika yang masuk adalah Tulang/Decal/Weld!
		if part:IsA("BasePart") or part:IsA("Accessory") then
			task.defer(optimizePart, part)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then onCharacterAdded(player.Character) end
end)