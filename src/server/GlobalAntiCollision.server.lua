local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NAME = "AllPlayers"
PhysicsService:RegisterCollisionGroup(GROUP_NAME)
PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)

local function optimizePart(part)
    -- 🔥 FIX LAYERED CLOTHING: 
    -- Pastikan part ini adalah BasePart badannya, BUKAN bagian dari Aksesoris/Baju.
    if part:IsA("BasePart") and not part:FindFirstAncestorWhichIsA("Accessory") then
        part.CollisionGroup = GROUP_NAME
    end

    -- Khusus untuk Accessory, kita cuma matikan shadow supaya game tetap ringan
    if part:IsA("Accessory") then
        for _, child in ipairs(part:GetDescendants()) do
            if child:IsA("BasePart") then
                child.CastShadow = false
                -- DILARANG KERAS mengganti child.CollisionGroup di sini!
                -- Menyentuh CollisionGroup pada aksesoris adalah penyebab utama baju kaku.
            end
        end
    end
end

-- 🔥 ARCHITECT FIX: Simpan connection per-player agar bisa di-disconnect
local playerConnections = {}

local function cleanupPlayerConnections(player)
	local conns = playerConnections[player]
	if conns then
		for _, conn in ipairs(conns) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		playerConnections[player] = nil
	end
end

local function onCharacterAdded(character, player)
	-- Bersihkan connection karakter lama dulu
	cleanupPlayerConnections(player)
	playerConnections[player] = {}

	-- [OPTIMASI SUPER]: Eksekusi langsung tanpa task.defer agar tidak ada jeda 1 frame (mencegah ledakan fisika saat spawn barengan)
	for _, part in ipairs(character:GetDescendants()) do
		-- HANYA eksekusi jika itu Part atau Aksesoris (Lebih ringan)
		if part:IsA("BasePart") or part:IsA("Accessory") then
			optimizePart(part)
		end
	end

	-- 🔥 ARCHITECT FIX: Kita TIDAK MEMATIKAN state Humanoid (Ragdoll/Flying/dll) 
	-- karena mematikan state bawaan Roblox sering membuat karakter nge-glitch 
	-- saat physics engine mencoba menyelesaikan benturan dengan map yang baru loading (StreamingEnabled).

	-- 🔥 ARCHITECT FIX: FILTER CERDAS ANTI-SPAM + SIMPAN CONNECTION
	local descendantConn = character.DescendantAdded:Connect(function(part)
		-- Langsung eksekusi, JANGAN gunakan task.defer karena aksesoris yang punya jeda 1 frame collision bisa memicu tolakan fisika!
		if part:IsA("BasePart") or part:IsA("Accessory") then
			optimizePart(part)
		end
	end)
	table.insert(playerConnections[player], descendantConn)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
	if player.Character then onCharacterAdded(player.Character, player) end
end)

-- 🔥 ARCHITECT FIX: Bersihkan connections saat player keluar
Players.PlayerRemoving:Connect(function(player)
	cleanupPlayerConnections(player)
end)