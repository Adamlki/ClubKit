local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverheadManager = {}

-- ====================================
-- ?? PENGATURAN DEBUG (ANTI-SPAM LOG)
-- ====================================
local DEBUG_ENABLED = false -- ?? UBAH KE 'true' JIKA INGIN MELIHAT LOG DI CONSOLE

local function debugLog(...)
	if DEBUG_ENABLED then
		print("[DEBUG OVERHEAD]", ...)
	end
end

local function debugWarn(...)
	if DEBUG_ENABLED then
		warn("[DEBUG OVERHEAD]", ...)
	end
end

-- Module references (diisi via Init)
local CONFIG              = nil
local RoleSystem          = nil
local LevelSystem         = nil
local DonationRankSystem  = nil
local DonaturRankSystem   = nil
local TitleDataManager    = nil
local TitleEffects        = nil
local DebugSystem         = nil

local activeOverheads   = {}
local overheadTemplate  = nil

-- ====================================
-- INIT
-- ====================================
function OverheadManager:Init(config, roleSystem, levelSystem, titleDataManager, donationRankSystem, donaturRankSystem)
	CONFIG             = config
	RoleSystem         = roleSystem
	LevelSystem        = levelSystem
	DonationRankSystem = donationRankSystem
	DonaturRankSystem  = donaturRankSystem
	TitleDataManager   = titleDataManager
	TitleEffects       = require(script.Parent.TitleEffects)
	DebugSystem        = require(script.Parent.DebugSystem)

	local UI = ReplicatedStorage:WaitForChild("UI")
	overheadTemplate = UI:WaitForChild("OverheadGui")
end

-- ====================================
-- HELPERS
-- ====================================

local function getDisplayText(role, player)
	if player and player.Team then
		local teamName = player.Team.Name
		if teamName == "Tamu" then
			return ""  -- Tamu tidak punya label
		end
		return teamName  -- tampilkan nama team apa adanya
	end
	-- Fallback jika belum punya team sama sekali
	return CONFIG.CUSTOM_DISPLAY_TEXT[role] or role
end

local function getRoleColor(role, player)
	if player and player.Team then
		local team  = player.Team
		local attrR = team:GetAttribute("ExactColorR")
		local attrG = team:GetAttribute("ExactColorG")
		local attrB = team:GetAttribute("ExactColorB")
		if attrR and attrG and attrB then
			return Color3.fromRGB(attrR, attrG, attrB)
		end
		-- Fallback ke BrickColor (untuk default teams sebelum attribute ada)
		local tc = team.TeamColor
		if tc then return tc.Color end
	end
	return CONFIG.ROLE_COLORS[role] or CONFIG.ROLE_COLORS.Player
end

local function checkPremium(player)
	local ok, v = pcall(function()
		return player.MembershipType == Enum.MembershipType.Premium
	end)
	return ok and v or false
end

local function checkGroupMember(player)
	local ok, v = pcall(function()
		return player:IsInGroup(CONFIG.GROUP_ID)
	end)
	return ok and v or false
end

local function setupTextSizeConstraint(textLabel)
	local c = textLabel:FindFirstChildOfClass("UITextSizeConstraint")
	if not c then
		c        = Instance.new("UITextSizeConstraint")
		c.Parent = textLabel
	end
	c.MinTextSize = CONFIG.NAME_TEXT_SIZE_MIN or 10
	c.MaxTextSize = CONFIG.NAME_TEXT_SIZE_MAX or 16
	return c
end

local function safeFind(parent, name)
	if not parent then return nil end
	local cleanName = string.gsub(string.lower(name), "%s+", "")
	for _, child in ipairs(parent:GetChildren()) do
		local childClean = string.gsub(string.lower(child.Name), "%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	return nil
end

-- ====================================
-- LOGO DISPLAY
-- ====================================
local function updateLogos(labelFrame, player, role)
	local allLogoNames = {
		"StaffLogo", "DevLogo", "OwnerLogo",
		"PremiumBadge", "VipLogo", "VvipLogo", "VerifiedBadge", "SultanLogo"
	}

	local logos = {}
	for _, name in ipairs(allLogoNames) do
		logos[name] = labelFrame:FindFirstChild(name)
	end

	-- Sembunyikan semua logo terlebih dahulu
	for _, logo in pairs(logos) do
		if logo then logo.Visible = false end
	end

	local roleConfig = CONFIG.LOGO_DISPLAY[role]
	if not roleConfig then return end

	-- Logika membaca langsung dari Config.Logos
	if roleConfig.ShowAll and roleConfig.Logos then
		for _, logoName in ipairs(roleConfig.Logos) do
			if logos[logoName] then
				logos[logoName].Visible = true
			end
		end
	elseif not roleConfig.ShowAll and roleConfig.RoleLogo then
		if logos[roleConfig.RoleLogo] then
			logos[roleConfig.RoleLogo].Visible = true
		end
	end

	-- Premium & Verified badge check (Timpa agar tetap menyala jika punya)
	if logos.PremiumBadge and checkPremium(player) then
		logos.PremiumBadge.Visible = true
	end
	if logos.VerifiedBadge and checkGroupMember(player) then
		logos.VerifiedBadge.Visible = true
	end
end

-- ====================================
-- TITLE EFFECT APPLICATION
-- ====================================
local function applyTitleEffect(titleFrame, titleLabel, titleData, character)
	-- 🔥 FIX: Tambahkan fallback Color3.new(1, 1, 1) jika DataStore pemain corrupt
	local base = titleData.Color or Color3.new(1, 1, 1)

	-- TitleFrame Background diubah ke warna yang dipilih di admin panel
	titleFrame.BackgroundColor3 = base

	if not titleData.GradientEnabled then
		-- Teks biarkan putih default, jangan diubah
		return
	end

	local effectType   = titleData.GradientEffect or "wave"
	local effectConfig = CONFIG.EFFECTS[effectType:upper()] or CONFIG.EFFECTS.WAVE

	task.wait()

	if     effectType == "none"      then TitleEffects:CreateNoneEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "wave"      then TitleEffects:CreateWaveEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "pulse"     then TitleEffects:CreatePulseEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "rainbow"   then TitleEffects:CreateRainbowEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "shimmer"   then TitleEffects:CreateShimmerEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "palette"   then TitleEffects:CreatePaletteEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "sunset"    then TitleEffects:CreateSunsetEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "ocean"     then TitleEffects:CreateOceanEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "galaxy"    then TitleEffects:CreateGalaxyEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "emerald"   then TitleEffects:CreateEmeraldEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	elseif effectType == "pinkwhite" then TitleEffects:CreatePinkWhiteEffect(titleLabel, titleData.Color, character, effectConfig, CONFIG.TEXT_BRIGHTEN_FACTOR)
	end

	if DEBUG_ENABLED then
		DebugSystem:Log("Effect applied:", effectType)
	end
end

-- ====================================
-- FUNGSI GET SAWERIA
-- ====================================
local function getSaweriaRank(player)
	debugLog("??? Mengecek Saweria untuk:", player.Name, "/", player.DisplayName)
	local ServerStorage = game:GetService("ServerStorage")
	local func = ServerStorage:FindFirstChild("GetTopSaweriaFunc")

	if not func then
		debugWarn("? GetTopSaweriaFunc TIDAK DITEMUKAN di ServerStorage!")
		return nil
	end

	local success, topList = pcall(function() return func:Invoke() end)

	if success and type(topList) == "table" then
		for rank, donor in ipairs(topList) do
			local dName = string.lower(donor.name)
			local pName = string.lower(player.Name)
			local pDisplay = string.lower(player.DisplayName)

			if dName == pName or dName == pDisplay then
				return rank
			end
		end
	end
	return nil
end

-- ====================================
-- UPDATE EDITABLE FRAME (SUDAH DIPERBAIKI BUG-NYA)
-- ====================================
local function updateEditableFrame(editableFrame, player, titleData)
	debugLog("??? Mulai merakit Overhead untuk:", player.Name)

	-- Cari TitleFrame di EditableFrame ATAU di Parent-nya (BorderFrame) karena user memindahkannya
	local titleFrame      = safeFind(editableFrame, "TitleFrame") or safeFind(editableFrame.Parent, "TitleFrame")
	local topLikesFrame   = safeFind(editableFrame, "TopLikesFrame")
	local topRobuxFrame   = safeFind(editableFrame, "TopRobuxFrame")
	local topRupiahFrame  = safeFind(editableFrame, "TopRupiahFrame")

	if not titleFrame then 
		warn("[OVERHEAD] TitleFrame tidak ditemukan di EditableFrame!")
	end
	if not topLikesFrame then 
		warn("[OVERHEAD] TopLikesFrame tidak ditemukan di EditableFrame!")
	end
	if not topRobuxFrame then 
		warn("[OVERHEAD] TopRobuxFrame tidak ditemukan di EditableFrame!")
	end
	if not topRupiahFrame then 
		warn("[OVERHEAD] TopRupiahFrame tidak ditemukan di EditableFrame!")
	end

	-- 1. Ambil Rank Rupiah (Otomatis dari Saweria)
	local saweriaRank = getSaweriaRank(player)
	local hasSaweriaRank = saweriaRank ~= nil and saweriaRank <= CONFIG.SAWERIA_TOP_RANKS

	-- 2. Ambil Rank Robux 
	-- 🔥 ARCHITECT FIX: BACA DARI LEADERBOARD BARU (_G.LeaderboardControl)
	local robuxRank = nil
	if _G.LeaderboardControl then
		local success, topDonors = pcall(function() return _G.LeaderboardControl.GetData() end)
		if success and type(topDonors) == "table" then
			for _, donor in ipairs(topDonors) do
				if donor.UserId == player.UserId then
					robuxRank = donor.Rank
					break
				end
			end
		end
	end
	local hasRobuxRank = robuxRank ~= nil and robuxRank >= 1 and robuxRank <= CONFIG.DONATION_TOP_RANKS

	-- 3. Ambil Rank Likes
	local likesRank = nil
	if _G.LikesLeaderboardData then
		local success, topLikes = pcall(function() return _G.LikesLeaderboardData end)
		if success and type(topLikes) == "table" then
			for _, donor in ipairs(topLikes) do
				if donor.UserId == player.UserId then
					likesRank = donor.Rank
					break
				end
			end
		end
	end
	-- Maksimal 30 sesuai dengan Leaderboard Likes
	local hasLikesRank = likesRank ~= nil and likesRank >= 1 and likesRank <= 30

	-- 4. Tampilkan ke UI: Top Likes
	if topLikesFrame then
		if hasLikesRank then
			topLikesFrame.Visible = true
			local likesLabel = safeFind(topLikesFrame, "TopLikesLabel")
			if likesLabel then
				likesLabel.Text = "Likes #" .. likesRank
			end
			-- Set frame color (menggunakan default colors yang tersedia)
			local colorIndex = math.min(likesRank, 10)
			local colors = CONFIG.TOP_DONATUR_COLORS and CONFIG.TOP_DONATUR_COLORS[colorIndex] or CONFIG.TOP_DONATUR_COLORS[10]
			if colors and colors.Frame then
				topLikesFrame.BackgroundColor3 = colors.Frame
			end
		else
			topLikesFrame.Visible = false
		end
	end

	-- 5. Tampilkan ke UI: Top Robux
	if topRobuxFrame then
		if hasRobuxRank then
			topRobuxFrame.Visible = true
			local robuxLabel = safeFind(topRobuxFrame, "TopRobuxLabel")
			if robuxLabel then
				robuxLabel.Text = "Robux #" .. robuxRank
			end
			local colorIndex = math.min(robuxRank, 10)
			local colors = CONFIG.TOP_SPENDER_COLORS and CONFIG.TOP_SPENDER_COLORS[colorIndex] or CONFIG.TOP_SPENDER_COLORS[10]
			if colors and colors.Frame then
				topRobuxFrame.BackgroundColor3 = colors.Frame
			end
		else
			topRobuxFrame.Visible = false
		end
	end

	-- 6. Tampilkan ke UI: Top Rupiah
	if topRupiahFrame then
		if hasSaweriaRank then
			topRupiahFrame.Visible = true
			local rupiahLabel = safeFind(topRupiahFrame, "TopRupiahLabel")
			if rupiahLabel then
				rupiahLabel.Text = "Rupiah #" .. saweriaRank
			end
			local colorIndex = math.min(saweriaRank, 10)
			local colors = CONFIG.TOP_DONATUR_COLORS and CONFIG.TOP_DONATUR_COLORS[colorIndex] or CONFIG.TOP_DONATUR_COLORS[10]
			if colors and colors.Frame then
				topRupiahFrame.BackgroundColor3 = colors.Frame
			end
		else
			topRupiahFrame.Visible = false
		end
	end

	-- 7. Title Custom
	if titleFrame then
		if titleData and titleData.Title ~= "" then
			titleFrame.Visible = true
			local titleLabel = safeFind(titleFrame, "TitleLabel")
			if titleLabel then
				titleLabel.Text = titleData.Title
				task.spawn(function() applyTitleEffect(titleFrame, titleLabel, titleData, player.Character) end)
			end
		else
			titleFrame.Visible = false
		end
	end

	-- 8. Sembunyikan EditableFrame jika kosong (agar tidak meninggalkan celah aneh)
	if editableFrame then
		local isAnyVisible = false
		if topLikesFrame and topLikesFrame.Visible then isAnyVisible = true end
		if topRobuxFrame and topRobuxFrame.Visible then isAnyVisible = true end
		if topRupiahFrame and topRupiahFrame.Visible then isAnyVisible = true end
		if titleFrame and titleFrame.Visible then isAnyVisible = true end
		
		editableFrame.Visible = isAnyVisible
	end
end

-- ====================================
-- REMOVE OVERHEAD
-- ====================================
function OverheadManager:RemoveOverhead(character)
	if not character then return end
	TitleEffects:StopAnimation(character)
	local head = character:FindFirstChild("Head")
	if head then
		local existing = head:FindFirstChild("OverheadGui")
		if existing then existing:Destroy() end
	end
end

-- ====================================
-- CREATE OVERHEAD
-- ====================================
function OverheadManager:CreateOverhead(player, character)
	self:RemoveOverhead(character)

	local head = character:WaitForChild("Head", 5)
	if not head then
		if DEBUG_ENABLED then DebugSystem:Warn("Head not found for", player.Name) end
		return
	end

	local overhead = overheadTemplate:Clone()

	-- UI Structure
	local mainFrame     = overhead:WaitForChild("MainFrame")
	local borderFrame   = mainFrame:WaitForChild("BorderFrame")
	local editableFrame = borderFrame:WaitForChild("EditableFrame")
	local textContainer = mainFrame:WaitForChild("TextContainer")
	local nameFrame     = textContainer:WaitForChild("NameFrame")
	local playerName    = nameFrame:WaitForChild("PlayerName")
	local labelFrame    = textContainer:WaitForChild("labelFrame")
	local playerRole    = textContainer:WaitForChild("PlayerRole")
	local levelLabel    = textContainer:WaitForChild("LevelLabel")

	-- Player Name & Likes
	local totalLikes = player:GetAttribute("TotalLikes") or 0
	playerName.Text          = player.DisplayName .. " | ❤️ " .. tostring(totalLikes)
	playerName.TextScaled    = true
	playerName.AutomaticSize = Enum.AutomaticSize.X
	setupTextSizeConstraint(playerName)

	-- Update Likes in Real-time
	local likesConn
	likesConn = player:GetAttributeChangedSignal("TotalLikes"):Connect(function()
		local newLikes = player:GetAttribute("TotalLikes") or 0
		local displayString = player.DisplayName .. " | ❤️ " .. tostring(newLikes)
		
		-- Update the specific overhead instance we just created, but also dynamically check character
		if playerName and playerName.Parent then
			playerName.Text = displayString
		end
		
		-- Fallback: update any existing overhead on the character to be completely sure
		if player.Character then
			local charHead = player.Character:FindFirstChild("Head")
			if charHead then
				local currentOverhead = charHead:FindFirstChild("OverheadGui")
				if currentOverhead then
					local mainFrame = currentOverhead:FindFirstChild("MainFrame")
					if mainFrame then
						local txtCont = mainFrame:FindFirstChild("TextContainer")
						if txtCont then
							local nFrame = txtCont:FindFirstChild("NameFrame")
							if nFrame then
								local pNameLabel = nFrame:FindFirstChild("PlayerName")
								if pNameLabel then
									pNameLabel.Text = displayString
								end
							end
						end
					end
				end
			end
		end
	end)
	
	overhead.Destroying:Connect(function()
		if likesConn then
			likesConn:Disconnect()
			likesConn = nil
		end
	end)

	local role      = RoleSystem:GetPlayerRole(player)
	local roleLabel = getDisplayText(role, player)
	playerRole.Text         = roleLabel
	playerRole.TextColor3   = getRoleColor(role, player)
	playerRole.Visible      = roleLabel ~= ""

	-- Level
	if LevelSystem then
		local level      = LevelSystem:GetPlayerLevel(player) or 1
		levelLabel.Text  = string.format(CONFIG.LEVEL_FORMAT, level)
		levelLabel.Visible = true
	else
		levelLabel.Visible = false
	end

	updateLogos(labelFrame, player, role)

	if DonaturRankSystem then
		DonaturRankSystem:GetRank(player.UserId)
	end

	local titleData = TitleDataManager:LoadTitleData(player.UserId)
	updateEditableFrame(editableFrame, player, titleData)

	overhead.Parent = head

	if not activeOverheads[player.UserId] then
		activeOverheads[player.UserId] = {}
	end
	activeOverheads[player.UserId][character] = overhead

	if DEBUG_ENABLED then
		DebugSystem:Log("Overhead created for", player.Name, "| Team:", player.Team and player.Team.Name or "none", "| Role:", role)
	end
	return overhead
end

-- ====================================
-- UPDATE FUNCTIONS
-- ====================================

function OverheadManager:UpdatePremiumBadge(player)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local textContainer = safeFind(safeFind(overhead, "MainFrame"), "TextContainer")
	local labelFrame    = safeFind(textContainer, "labelFrame")
	if not labelFrame then return end

	local premiumLogo = labelFrame:FindFirstChild("PremiumBadge")
	if premiumLogo then
		local role       = RoleSystem:GetPlayerRole(player)
		local roleConfig = CONFIG.LOGO_DISPLAY[role]
		premiumLogo.Visible = (roleConfig and roleConfig.ShowAll) or checkPremium(player)
	end
end

function OverheadManager:UpdateRole(player, newRole)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local textContainer = safeFind(safeFind(overhead, "MainFrame"), "TextContainer")
	if not textContainer then return end

	local playerRoleLabel = textContainer:FindFirstChild("PlayerRole")
	if playerRoleLabel then
		local label = getDisplayText(newRole, player)
		playerRoleLabel.Text       = label
		playerRoleLabel.TextColor3 = getRoleColor(newRole, player)
		playerRoleLabel.Visible    = label ~= ""
	end

	local labelFrame = textContainer:FindFirstChild("labelFrame")
	if labelFrame then
		updateLogos(labelFrame, player, newRole)
	end

	if DEBUG_ENABLED then
		DebugSystem:Log("Role updated for", player.Name, "->", newRole, "| Team:", player.Team and player.Team.Name or "none")
	end
end

function OverheadManager:UpdateTeam(player)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local textContainer = safeFind(safeFind(overhead, "MainFrame"), "TextContainer")
	if not textContainer then return end

	local role       = RoleSystem:GetPlayerRole(player)
	local roleLabel  = getDisplayText(role, player)
	local playerRole = textContainer:FindFirstChild("PlayerRole")
	if playerRole then
		playerRole.Text       = roleLabel
		playerRole.TextColor3 = getRoleColor(role, player)
		playerRole.Visible    = roleLabel ~= ""
	end

	if DEBUG_ENABLED then
		DebugSystem:Log("Team label updated for", player.Name, "->", player.Team and player.Team.Name or "none")
	end
end

function OverheadManager:UpdateLevel(player, newLevel)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local textContainer = safeFind(safeFind(overhead, "MainFrame"), "TextContainer")
	local levelLabel    = safeFind(textContainer, "LevelLabel")
	if levelLabel then
		levelLabel.Text = string.format(CONFIG.LEVEL_FORMAT, newLevel)
		if DEBUG_ENABLED then DebugSystem:Log("Level updated for", player.Name, "->", newLevel) end
	end
end

local function getEditableFrame(overhead)
	local mainFrame   = safeFind(overhead, "MainFrame")
	local borderFrame = safeFind(mainFrame, "BorderFrame")
	return safeFind(borderFrame, "EditableFrame")
end

function OverheadManager:UpdateDonationRank(player, oldRank, newRank)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local editableFrame = getEditableFrame(overhead)
	if not editableFrame then return end

	local titleData = TitleDataManager:LoadTitleData(player.UserId)
	updateEditableFrame(editableFrame, player, titleData)

	if DEBUG_ENABLED then
		DebugSystem:Log("TopRobux rank updated for", player.Name, "Old:", oldRank, "New:", newRank)
	end
end

function OverheadManager:UpdateDonaturRank(player)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local overhead = head:FindFirstChild("OverheadGui")
	if not overhead then return end

	local editableFrame = getEditableFrame(overhead)
	if not editableFrame then return end

	local titleData = TitleDataManager:LoadTitleData(player.UserId)
	updateEditableFrame(editableFrame, player, titleData)

	if DEBUG_ENABLED then DebugSystem:Log("TopDonatur rank updated for", player.Name) end
end

-- ====================================
-- CLEANUP
-- ====================================
function OverheadManager:CleanupPlayer(player)
	if activeOverheads[player.UserId] then
		for _, overhead in pairs(activeOverheads[player.UserId]) do
			if overhead then overhead:Destroy() end
		end
		activeOverheads[player.UserId] = nil
	end
end

return OverheadManager