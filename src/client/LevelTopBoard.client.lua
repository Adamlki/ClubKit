local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ====================================
-- CONFIGURATION
-- ====================================
local CONFIG = {
	RankColors = {
		[1] = Color3.fromRGB(255, 215, 0),
		[2] = Color3.fromRGB(192, 192, 192),
		[3] = Color3.fromRGB(205, 127, 50),
	},
}

-- ====================================
-- REFERENSI
-- ====================================
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Board = workspace:WaitForChild("EldetoLevelBoard", 30)
if not Board then warn("[LevelBoard] EldetoLevelBoard tidak ditemukan!") return end

local Gui            = Board:WaitForChild("EldetoLevelBoard",5)
local mainFrame      = Gui:WaitForChild("Mainframe",5)
local container      = mainFrame:WaitForChild("Container",5)
local scrollingFrame = container:WaitForChild("ScrollingFrame",5)
local templateFrame  = scrollingFrame:WaitForChild("TemplateFrame",5)
templateFrame.Visible = false

-- ====================================
-- STATE & CACHE MANAGER
-- ====================================
local clonedRows    = {}
local nameCache     = {} -- 🔥 ARCHITECT FIX: Cache Nama untuk cegah API Throttling

-- ====================================
-- UTILITY (DENGAN CACHING)
-- ====================================
local function getPlayerName(userId)
	if nameCache[userId] then return nameCache[userId] end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok and name then
		nameCache[userId] = name
		return name
	end
	
	-- 🔥 CLIENT FIX: Simpan fallback ke cache untuk mencegah API Spam jika Roblox error
	nameCache[userId] = "Player_" .. tostring(userId)
	return nameCache[userId]
end

-- ====================================
-- RENDER SCROLLING LEADERBOARD (OBJECT POOLING)
-- ====================================
local function renderRows(topData)
	-- 🔥 ARCHITECT FIX: UI Recycling (Object Pooling)
	-- Jangan pernah Destroy & Clone UI secara massal. Daur ulang baris yang ada!

	for i, entry in ipairs(topData) do
		local row = clonedRows[i]

		-- Buat baris baru HANYA jika kurang
		if not row then
			row = templateFrame:Clone()
			row.Parent = scrollingFrame
			clonedRows[i] = row
		end

		row.Visible     = true
		row.Name        = "Row_" .. tostring(entry.rank)
		row.LayoutOrder = entry.rank

		local rankLabel   = row:FindFirstChild("RankLabel")
		local playerLabel = row:FindFirstChild("PlayerLabel")
		local levelLabel  = row:FindFirstChild("LevelLabel")

		if rankLabel then
			rankLabel.Text = "#" .. tostring(entry.rank)
			rankLabel.TextColor3 = CONFIG.RankColors[entry.rank] or Color3.fromRGB(255, 255, 255)
		end
		if levelLabel  then levelLabel.Text  = "Lv. " .. tostring(entry.level) end
		if playerLabel then
			-- Eksekusi instan berkat caching
			task.spawn(function()
				local name = getPlayerName(entry.userId)
				if playerLabel.Parent then playerLabel.Text = name end
			end)
		end
	end

	-- Sembunyikan sisa baris yang tidak terpakai (jika data turun dari 50 ke 10 misalnya)
	for i = #topData + 1, #clonedRows do
		clonedRows[i].Visible = false
	end
end

-- ====================================
-- MAIN
-- ====================================
local function onDataReceived(topData)
	if not topData or #topData == 0 then return end
	renderRows(topData)
end

local remote = ReplicatedStorage:WaitForChild("UpdateLevelBoard", 30)
if not remote then
	warn("[LevelBoard] RemoteEvent 'UpdateLevelBoard' tidak ditemukan!")
	return
end

remote.OnClientEvent:Connect(onDataReceived)

print("[LevelBoard Client] Enterprise Architecture Ready!")