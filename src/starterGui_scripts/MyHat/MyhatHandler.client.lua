-- ====================================
-- ACCESSORY GUI CONTROLLER
-- Place in StarterPlayer > StarterPlayerScripts
-- ====================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Wait for Remote Event
local AccessoryRemotes = ReplicatedStorage:WaitForChild("AccessoryRemotes")
local AccessoryEvent = AccessoryRemotes:WaitForChild("ToggleAccessory")

-- Wait for GUI
local PlayerGui = Player:WaitForChild("PlayerGui")

-- 🔥 FIX 1: Menyesuaikan referensi. Karena skrip ditaruh di StarterPlayerScripts,
-- kita memanggil GUI melalui PlayerGui, bukan menggunakan script.Parent.
-- Pastikan nama GUI-mu benar-benar "MyHat"
local gui = PlayerGui:WaitForChild("MyHat") 
local mainframe = gui:WaitForChild("Mainframe")
local equipBtn = mainframe:WaitForChild("EquipBtn")
local unequipBtn = mainframe:WaitForChild("UnequipBtn")

-- 🔥 FIX 2: Sistem Pelindung Anti-Spam (Debounce / Cooldown)
local isProcessing = false
local COOLDOWN_TIME = 0.5 -- Beri jeda 0.5 detik antar klik agar server tidak lag

-- ====================================
-- FUNCTIONS
-- ====================================
local function equipAccessory()
	-- Cegah proses berlanjut jika sedang masa cooldown (anti-spam klik)
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("equip")

	-- Tunggu masa cooldown selesai lalu buka gemboknya lagi
	task.wait(COOLDOWN_TIME)
	isProcessing = false
end

local function unequipAccessory()
	-- Cegah proses berlanjut jika sedang masa cooldown
	if isProcessing then return end
	isProcessing = true

	AccessoryEvent:FireServer("unequip")

	-- Tunggu masa cooldown selesai lalu buka gemboknya lagi
	task.wait(COOLDOWN_TIME)
	isProcessing = false
end

-- ====================================
-- BUTTON CONNECTIONS
-- ====================================
equipBtn.MouseButton1Click:Connect(function()
	equipAccessory()
end)

unequipBtn.MouseButton1Click:Connect(function()
	unequipAccessory()
end)

-- ====================================
-- INITIALIZE
-- ====================================
mainframe.Visible = false
