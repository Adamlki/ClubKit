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

-- Step 2: Buat default team objects (Owner, Head Staff, Staff, Sultan, VIP, Tamu)
-- Palette index default teams: 40-46 (tidak akan pernah konflik dengan custom: 50+)
TeamGroups.CreateDefaultTeams()

-- Step 3: Append custom team objects setelah default, sync lookup table
-- Di sini teamsByName dibangun ulang dari semua team yang ada.
CustomTeams.AppendCustomTeams()

-- Step 4: TeamGroups pasang RoleChanged listener dengan guard override
-- Guard: jika player punya custom override, jangan re-assign saat role berubah.
TeamGroups.Init(CustomTeams.HasOverride)

-- Step 5: CustomTeams pasang chat commands + lifecycle events
CustomTeams.Init()

-- Step 6/7: Satu pintu masuk untuk assignment awal.
-- Guard ini mencegah player yang join saat init terkena AssignNewPlayer dua kali
-- dari loop player existing + PlayerAdded.
local assignedPlayers = {}

local function assignPlayerOnce(player)
	if not player or not player.Parent then return end
	if assignedPlayers[player] then return end
	assignedPlayers[player] = true
	CustomTeams.AssignNewPlayer(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(assignPlayerOnce, player)
end

Players.PlayerAdded:Connect(assignPlayerOnce)
Players.PlayerRemoving:Connect(function(player)
	assignedPlayers[player] = nil
end)
