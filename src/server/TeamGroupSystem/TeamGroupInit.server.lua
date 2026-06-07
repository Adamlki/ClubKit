local Players       = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local RoleSystem  = require(ServerStorage.Modules.RoleSystem)
local TeamGroups  = require(ServerStorage.Modules.TeamGroups)
local CustomTeams = require(ServerStorage.Modules.CustomTeams)

-- ====================================
-- URUTAN INIT — PENTING, JANGAN DIUBAH
-- ====================================

-- Step 1: Load data custom teams dari DS (blocking, max ~10 detik)
-- Ini perlu selesai sebelum AppendCustomTeams agar semua custom team
-- sudah ada di customTeamObjects dengan PaletteIndex yang benar.
CustomTeams.LoadFromDataStore()

-- Step 2: Buat default team objects (Owner, Head Staff, Staff, VVIP, VIP, Tamu)
-- Palette index default teams: 40-45 (tidak akan pernah konflik dengan custom: 50+)
TeamGroups.CreateDefaultTeams()

-- Step 3: Append custom team objects setelah default, sync lookup table
-- Di sini teamsByName dibangun ulang dari semua team yang ada.
CustomTeams.AppendCustomTeams()

-- Step 4: TeamGroups pasang RoleChanged listener dengan guard override
-- Guard: jika player punya custom override, jangan re-assign saat role berubah.
TeamGroups.Init(CustomTeams.HasOverride)

-- Step 5: CustomTeams pasang chat commands + lifecycle events
CustomTeams.Init()

-- Step 6: Assign semua player yang sudah online saat server start
-- AssignNewPlayer: sync load DS override → assign segera → re-assign setelah gamepass async
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		CustomTeams.AssignNewPlayer(player)
	end)
end

-- Step 7: PlayerAdded untuk player yang join setelah start
Players.PlayerAdded:Connect(function(player)
	CustomTeams.AssignNewPlayer(player)
end)
