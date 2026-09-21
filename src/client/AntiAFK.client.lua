--!strict
-- ============================================================
-- ANTI-AFK 24/7 AUTO-REJOIN & RESTORE POSITION (CLIENT)
-- ============================================================
-- Sistem murni berjalan di background (100% silent tanpa GUI).
-- Memantau aktivitas pemain (keyboard, mouse, touchscreen).
-- Pada menit ke-18 tidak ada aktivitas, otomatis me-rejoin
-- server dan mengembalikan posisi karakter sebelum batas
-- 20 menit Roblox (Error 278) tercapai.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ============================================================
-- KONFIGURASI
-- ============================================================
local IDLE_THRESHOLD_SECONDS = 18 * 60 -- 18 Menit (1080 detik)

-- State
local lastActivityTime = os.clock()
local isRejoining = false

-- RemoteEvent Setup
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local antiAFKRejoinEvent: RemoteEvent? = nil
if remotesFolder then
	antiAFKRejoinEvent = remotesFolder:WaitForChild("AntiAFKRejoin", 10) :: RemoteEvent?
end

-- Bersihkan sisa GUI lama jika ada
local playerGui = player:FindFirstChild("PlayerGui")
if playerGui then
	local oldGui = playerGui:FindFirstChild("AntiAfkGui")
	if oldGui then
		oldGui:Destroy()
	end
end

-- ============================================================
-- RESET AKTIVITAS
-- ============================================================
local function resetActivity()
	lastActivityTime = os.clock()
end

-- ============================================================
-- EKSEKUSI REJOIN OTOMATIS
-- ============================================================
local function executeRejoin()
	if isRejoining then return end
	isRejoining = true

	print("[AntiAFK] 🚀 Pemain idle 18 menit. Menjalankan Auto-Rejoin & menyimpan posisi di background...")

	if not antiAFKRejoinEvent then
		antiAFKRejoinEvent = ReplicatedStorage:FindFirstChild("Remotes")
			and ReplicatedStorage.Remotes:FindFirstChild("AntiAFKRejoin") :: RemoteEvent?
	end

	if antiAFKRejoinEvent then
		antiAFKRejoinEvent:FireServer()
	else
		warn("[AntiAFK] RemoteEvent AntiAFKRejoin tidak ditemukan di ReplicatedStorage.Remotes!")
	end
end

-- ============================================================
-- DETEKSI INPUT AKTIVITAS FISIK PEMAIN
-- ============================================================
UserInputService.InputBegan:Connect(function()
	if not isRejoining then
		resetActivity()
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if not isRejoining then
			resetActivity()
		end
	end
end)

-- Cadangan deteksi via sinyal engine player.Idled
player.Idled:Connect(function(timeIdled)
	if timeIdled and timeIdled >= IDLE_THRESHOLD_SECONDS and not isRejoining then
		executeRejoin()
	end
end)

-- ============================================================
-- HEARTBEAT PENGECEKAN IDLE (Setiap 2 detik)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(2)

		if not isRejoining then
			local idleDuration = os.clock() - lastActivityTime
			if idleDuration >= IDLE_THRESHOLD_SECONDS then
				executeRejoin()
			end
		end
	end
end)

-- ============================================================
-- TESTING TRIGGER (Opsional untuk Developer)
-- ============================================================
-- Bisa dipicu untuk pengetesan cepat via Console/Studio:
-- game.Players.LocalPlayer:SetAttribute("TestAFK", true)
player:GetAttributeChangedSignal("TestAFK"):Connect(function()
	if player:GetAttribute("TestAFK") == true then
		player:SetAttribute("TestAFK", nil)
		print("[AntiAFK] 🧪 Simulasi AFK dipicu via Attribute TestAFK.")
		executeRejoin()
	end
end)

print("[AntiAFK] ✅ 24/7 Anti-AFK Background System active (Silent mode, 18m threshold).")
