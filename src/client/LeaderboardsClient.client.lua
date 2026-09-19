-- ==============================================================================
-- LEADERBOARDS CLIENT (AAA NIGHTCLUB EDITION)
-- Handles Top Likes, Top Robux Donation, and Top Saweria Donation leaderboards
-- Supports: All Time & Daily modes, Top 3 Podium, dynamic tab switching, auto-rotate
-- ==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AUTO_ROTATE_INTERVAL = 15 -- Auto-cycle between All Time and Daily every 15s
local USER_INTERACTION_PAUSE = 30 -- Pause auto-rotate for 30s when a user clicks a tab

-- Helper to find models in Workspace.Leaderboard
local function getLeaderboardBoard(boardName)
	local folder = workspace:FindFirstChild("Leaderboard")
	if folder then
		local b = folder:FindFirstChild(boardName)
		if b then return b end
	end
	return workspace:FindFirstChild(boardName, true)
end

-- ==============================================================================
-- NUMBER FORMATTING
-- ==============================================================================
local function formatThousands(num, separator)
	separator = separator or ","
	local val = math.floor(tonumber(num) or 0)
	local str = tostring(val)
	local k
	while true do
		str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1" .. separator .. "%2")
		if k == 0 then break end
	end
	return str
end

local UserService = game:GetService("UserService")

-- Forward declarations for board renderers
local renderLikesBoard
local renderLevelBoard
local renderRobuxBoard
local renderSaweriaBoard

local renderScheduled = false
local function scheduleRenderAll()
	if renderScheduled then return end
	renderScheduled = true
	task.delay(0.2, function()
		renderScheduled = false
		if renderLikesBoard then pcall(renderLikesBoard) end
		if renderLevelBoard then pcall(renderLevelBoard) end
		if renderRobuxBoard then pcall(renderRobuxBoard) end
		if renderSaweriaBoard then pcall(renderSaweriaBoard) end
	end)
end

-- ==============================================================================
-- USERNAME & DISPLAYNAME RESOLVER & FORMATTER
-- ==============================================================================
local userInfoCache = {}

local function resolveUserInfo(userId, fallbackDisplayName, fallbackUsername)
	local cleanUser = fallbackUsername and fallbackUsername:gsub("^@", ""):gsub("%s+", "_") or ""
	if cleanUser == "user" or cleanUser == "player" or cleanUser:find("^player_%d+") then
		cleanUser = ""
	end

	local dName = fallbackDisplayName or "Player"
	local hasDistinct = false
	if cleanUser ~= "" and dName:lower() ~= cleanUser:lower() then
		hasDistinct = true
	end

	local result = {
		DisplayName = dName,
		Username = cleanUser ~= "" and ("@" .. cleanUser) or "",
		HasDistinctUser = hasDistinct,
	}

	if not userId or userId <= 1 then
		return result
	end

	if userInfoCache[userId] then
		return userInfoCache[userId]
	end

	local needsFetch = false
	if cleanUser == "" or dName == "Player" or dName:find("^Player_%d+") or dName:find("^Sultan_%d+") then
		needsFetch = true
	end

	if needsFetch then
		task.spawn(function()
			local fetchedDisplay = nil
			local fetchedUser = nil

			local s, infoList = pcall(function()
				return UserService:GetUserInfosByUserIdsAsync({userId})
			end)
			if s and infoList and #infoList > 0 then
				local info = infoList[1]
				fetchedDisplay = info.DisplayName
				fetchedUser = info.Username
			else
				local s2, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if s2 and name and name ~= "" then
					fetchedDisplay = name
					fetchedUser = name
				end
			end

			if fetchedDisplay and fetchedUser then
				local fClean = fetchedUser:gsub("^@", ""):gsub("%s+", "_")
				local fDistinct = (fetchedDisplay:lower() ~= fClean:lower())
				userInfoCache[userId] = {
					DisplayName = fetchedDisplay,
					Username = "@" .. fClean,
					HasDistinctUser = fDistinct,
				}
				scheduleRenderAll()
			end
		end)
	else
		userInfoCache[userId] = result
	end

	return userInfoCache[userId] or result
end

local function applyNameLabels(nameLbl, userLbl, uInfo)
	if not nameLbl then return end

	nameLbl.Text = uInfo.DisplayName or "Player"

	if userLbl then
		if uInfo.HasDistinctUser and uInfo.Username and uInfo.Username ~= "" and uInfo.Username ~= "@" and uInfo.Username ~= "@user" then
			nameLbl.Position = UDim2.new(0, 142, 0, 12)
			nameLbl.Size = UDim2.new(0, 260, 0, 28)
			userLbl.Visible = true
			userLbl.Text = uInfo.Username
			userLbl.Position = UDim2.new(0, 142, 0, 42)
			userLbl.Size = UDim2.new(0, 260, 0, 20)
		else
			-- Nickname sama persis dengan username, atau tidak ada username terpisah:
			-- Jangan tulis username 2 kali! Center nameLbl secara vertikal dan sembunyikan userLbl
			nameLbl.Position = UDim2.new(0, 142, 0.5, -14)
			nameLbl.Size = UDim2.new(0, 260, 0, 28)
			userLbl.Visible = false
			userLbl.Text = ""
		end
	end
end

local function applyPodiumNameLabels(nl, ul, uInfo)
	if not nl then return end

	nl.Text = uInfo.DisplayName or "-"

	if ul then
		if uInfo.HasDistinctUser and uInfo.Username and uInfo.Username ~= "" and uInfo.Username ~= "@" and uInfo.Username ~= "@user" then
			nl.Position = UDim2.new(0, 0, 0, 92)
			ul.Visible = true
			ul.Text = uInfo.Username
			ul.Position = UDim2.new(0, 0, 0, 118)
		else
			nl.Position = UDim2.new(0, 0, 0, 102)
			ul.Visible = false
			ul.Text = ""
		end
	end
end

local function getAvatarThumb(userId)
	if not userId or userId <= 1 then
		return "rbxthumb://type=AvatarHeadShot&id=1&w=150&h=150"
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

-- ==============================================================================
-- BOARD STATES
-- ==============================================================================
local States = {
	Likes = {
		Mode = "AllTime", -- Strictly All Time
		AllTime = {},
		Daily = {},
	},
	Level = {
		Mode = "AllTime", -- Strictly All Time
		AllTime = {},
	},
	Robux = {
		Mode = "AllTime",
		AllTime = {},
		Daily = {},
		LastClick = 0,
	},
	Saweria = {
		Mode = "AllTime",
		AllTime = {},
		Daily = {},
		LastClick = 0,
	},
}

-- Helper to style TabSwitcher buttons (used by Robux and Saweria boards)
local function updateTabButtons(switcher, currentMode)
	if not switcher then return end
	local allTimeBtn = switcher:FindFirstChild("AllTimeBtn")
	local dailyBtn = switcher:FindFirstChild("DailyBtn")

	if allTimeBtn then
		if currentMode == "AllTime" then
			allTimeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			allTimeBtn.BackgroundTransparency = 0
			allTimeBtn.TextColor3 = Color3.fromRGB(15, 15, 15)
		else
			allTimeBtn.BackgroundTransparency = 1
			allTimeBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
		end
	end

	if dailyBtn then
		if currentMode == "Daily" then
			dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			dailyBtn.BackgroundTransparency = 0
			dailyBtn.TextColor3 = Color3.fromRGB(15, 15, 15)
		else
			dailyBtn.BackgroundTransparency = 1
			dailyBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
		end
	end
end

-- ==============================================================================
-- RENDER LIKES BOARD (All Time Only)
-- ==============================================================================
renderLikesBoard = function()
	local board = getLeaderboardBoard("JekyLikeBoard")
	if not board then return end
	local gui = board:FindFirstChild("JekyGui") or board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end
	local main = gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe")
	if not main then return end

	local header = main:FindFirstChild("Header")
	local scroll = main:FindFirstChild("ScrollFrame")
	local template = scroll and scroll:FindFirstChild("TemplateFrame")
	if not scroll or not template then return end

	local state = States.Likes
	local listData = (#state.AllTime > 0) and state.AllTime or state.Daily

	-- Subtitle is permanently All Time Top Likes (no TabSwitcher)
	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then
			sub.Text = "All Time Top Likes"
		end
		local title = header:FindFirstChild("Title")
		if title then
			title.Text = "Top Likes"
		end
	end

	template.Visible = false

	-- Pool / Reuse existing row items
	local pool = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c ~= template then
			table.insert(pool, c)
		end
	end

	-- Pre-create up to 30 items
	for i = #pool + 1, math.max(30, #listData) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.Visible = false
		clone.Parent = scroll
		table.insert(pool, clone)
	end

	for i, item in ipairs(listData) do
		local row = pool[i]
		if not row then
			row = template:Clone()
			row.Name = "Entry_" .. i
			row.Parent = scroll
			table.insert(pool, row)
		end

		row.Visible = true
		row.LayoutOrder = i

		local uInfo = resolveUserInfo(item.UserId, item.DisplayName, item.Username)
		local rankLbl = row:FindFirstChild("RankLabel")
		local avatarImg = row:FindFirstChild("AvatarImg")
		local nameLbl = row:FindFirstChild("NameLabel")
		local userLbl = row:FindFirstChild("UserLabel")
		local valLbl = row:FindFirstChild("ValueLabel")
		local iconLbl = row:FindFirstChild("IconLabel")

		if rankLbl then
			rankLbl.Text = "#" .. tostring(item.Rank or i)
			if i == 1 then
				rankLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
			elseif i == 2 then
				rankLbl.TextColor3 = Color3.fromRGB(192, 192, 192)
			elseif i == 3 then
				rankLbl.TextColor3 = Color3.fromRGB(205, 127, 50)
			else
				rankLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end

		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end
		applyNameLabels(nameLbl, userLbl, uInfo)
		if valLbl then valLbl.Text = formatThousands(item.Likes or item.Amount or 0, ".") end
		if iconLbl and iconLbl:IsA("TextLabel") then
			iconLbl.Text = "♡"
			iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	for i = #listData + 1, #pool do
		pool[i].Visible = false
	end

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end
end

-- ==============================================================================
-- RENDER LEVEL BOARD (All Time Only, Exactly Matches Like Board Style)
-- ==============================================================================
renderLevelBoard = function()
	local board = getLeaderboardBoard("JekyLevelBoard") or getLeaderboardBoard("EldetoLevelBoard")
	if not board then return end
	local gui = board:FindFirstChild("EldetoLevelBoard") or board:FindFirstChild("JekyGui") or board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end
	local main = gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe")
	if not main then return end

	local header = main:FindFirstChild("Header")
	local scroll = main:FindFirstChild("ScrollFrame")
	local template = scroll and scroll:FindFirstChild("TemplateFrame")
	if not scroll or not template then return end

	local state = States.Level
	local listData = state.AllTime or {}

	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then
			sub.Text = "All Time Top Level"
		end
		local title = header:FindFirstChild("Title")
		if title then
			title.Text = "Top Level"
		end
	end

	template.Visible = false

	-- Pool / Reuse existing row items
	local pool = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c ~= template then
			table.insert(pool, c)
		end
	end

	-- Pre-create up to 30 items
	for i = #pool + 1, math.max(30, #listData) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.Visible = false
		clone.Parent = scroll
		table.insert(pool, clone)
	end

	for i, item in ipairs(listData) do
		local row = pool[i]
		if not row then
			row = template:Clone()
			row.Name = "Entry_" .. i
			row.Parent = scroll
			table.insert(pool, row)
		end

		row.Visible = true
		row.LayoutOrder = i

		local userId = item.userId or item.UserId
		local level = item.level or item.Level or 1
		local rank = item.rank or item.Rank or i

		local uInfo = resolveUserInfo(userId, item.DisplayName, item.Username)
		local rankLbl = row:FindFirstChild("RankLabel")
		local avatarImg = row:FindFirstChild("AvatarImg")
		local nameLbl = row:FindFirstChild("NameLabel")
		local userLbl = row:FindFirstChild("UserLabel")
		local valLbl = row:FindFirstChild("ValueLabel")
		local iconLbl = row:FindFirstChild("IconLabel")

		if rankLbl then
			rankLbl.Text = "#" .. tostring(rank)
			if i == 1 then
				rankLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
			elseif i == 2 then
				rankLbl.TextColor3 = Color3.fromRGB(192, 192, 192)
			elseif i == 3 then
				rankLbl.TextColor3 = Color3.fromRGB(205, 127, 50)
			else
				rankLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end

		if avatarImg then avatarImg.Image = getAvatarThumb(userId) end
		applyNameLabels(nameLbl, userLbl, uInfo)
		if valLbl then valLbl.Text = "Lv. " .. formatThousands(level, ".") end
		if iconLbl and iconLbl:IsA("TextLabel") then
			iconLbl.Text = "★"
			iconLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
		end
	end

	for i = #listData + 1, #pool do
		pool[i].Visible = false
	end

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end
end


-- ==============================================================================
-- RENDER ROBUX DONATION BOARD (Photo 2 Match)
-- ==============================================================================
renderRobuxBoard = function()
	local board = getLeaderboardBoard("JekyDonationBoard")
	if not board then return end
	local gui = board:FindFirstChild("EldetoGui") or board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end
	local main = gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe")
	if not main then return end

	local header = main:FindFirstChild("Header")
	local podium = main:FindFirstChild("PodiumFrame")
	local scroll = main:FindFirstChild("ScrollFrame")
	local template = scroll and scroll:FindFirstChild("TemplateFrame")
	if not scroll or not template then return end

	local state = States.Robux
	local isAllTime = (state.Mode == "AllTime")
	local listData = isAllTime and state.AllTime or state.Daily

	-- Update Subtitle & Tabs
	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then
			sub.Text = isAllTime and "All Time Top Robux Donation" or "Top Daily Robux"
		end
		local switcher = header:FindFirstChild("TabSwitcher")
		updateTabButtons(switcher, state.Mode)
	end

	if isAllTime then
		-- ALL TIME: Show Podium for #1..#3, ScrollFrame for #4+
		if podium then
			podium.Visible = true
			local slotMap = {
				[1] = podium:FindFirstChild("Slot_1"),
				[2] = podium:FindFirstChild("Slot_2"),
				[3] = podium:FindFirstChild("Slot_3"),
			}
			for rank = 1, 3 do
				local slot = slotMap[rank]
				local data = listData[rank]
				if slot then
					local av = slot:FindFirstChild("Avatar")
					local nl = slot:FindFirstChild("NameLabel")
					local ul = slot:FindFirstChild("UserLabel")
					local al = slot:FindFirstChild("AmountLabel", true)

					if data then
						local uInfo = resolveUserInfo(data.UserId, data.DisplayName, data.Username)
						if av then av.Image = getAvatarThumb(data.UserId) end
						applyPodiumNameLabels(nl, ul, uInfo)
						if al then al.Text = formatThousands(data.Amount or 0, ",") end
					else
						if av then av.Image = getAvatarThumb(1) end
						applyPodiumNameLabels(nl, ul, { DisplayName = "-", HasDistinctUser = false })
						if al then al.Text = "0" end
					end
				end
			end
		end

		scroll.Position = UDim2.new(0, 24, 0, 405)
		scroll.Size = UDim2.new(1, -48, 1, -420)
	else
		-- DAILY: Hide Podium, ScrollFrame starts at #1 right under Header
		if podium then
			podium.Visible = false
		end
		scroll.Position = UDim2.new(0, 24, 0, 105)
		scroll.Size = UDim2.new(1, -48, 1, -120)
	end

	template.Visible = false

	local pool = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c ~= template then
			table.insert(pool, c)
		end
	end

	local startRank = isAllTime and 4 or 1
	local renderItems = {}
	for i = startRank, #listData do
		table.insert(renderItems, listData[i])
	end

	for i = #pool + 1, math.max(30, #renderItems) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.Visible = false
		clone.Parent = scroll
		table.insert(pool, clone)
	end

	for i, item in ipairs(renderItems) do
		local row = pool[i]
		if not row then
			row = template:Clone()
			row.Name = "Entry_" .. i
			row.Parent = scroll
			table.insert(pool, row)
		end

		row.Visible = true
		row.LayoutOrder = i

		local uInfo = resolveUserInfo(item.UserId, item.DisplayName, item.Username)
		local rankLbl = row:FindFirstChild("RankLabel")
		local avatarImg = row:FindFirstChild("AvatarImg")
		local nameLbl = row:FindFirstChild("NameLabel")
		local userLbl = row:FindFirstChild("UserLabel")
		local valLbl = row:FindFirstChild("ValueLabel")
		local iconLbl = row:FindFirstChild("IconLabel")

		if rankLbl then rankLbl.Text = "#" .. tostring(item.Rank or (startRank + i - 1)) end
		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end
		applyNameLabels(nameLbl, userLbl, uInfo)
		if valLbl then valLbl.Text = formatThousands(item.Amount or 0, ",") end
		if iconLbl and iconLbl:IsA("ImageLabel") then
			iconLbl.Image = "rbxasset://textures/ui/common/robux_small.png"
		end
	end

	for i = #renderItems + 1, #pool do
		pool[i].Visible = false
	end

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end
end

-- ==============================================================================
-- RENDER SAWERIA DONATION BOARD (Photo 3 Match)
-- ==============================================================================
renderSaweriaBoard = function()
	local board = getLeaderboardBoard("BoardSaweria")
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardGui") or board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end
	local main = gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe")
	if not main then return end

	local header = main:FindFirstChild("Header")
	local podium = main:FindFirstChild("PodiumFrame")
	local scroll = main:FindFirstChild("ScrollFrame")
	local template = scroll and scroll:FindFirstChild("TemplateFrame")
	if not scroll or not template then return end

	local state = States.Saweria
	local isAllTime = (state.Mode == "AllTime")
	local listData = isAllTime and state.AllTime or state.Daily

	-- Update Subtitle & Tabs
	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then
			sub.Text = isAllTime and "All Time Top Saweria Donation" or "Top Daily Saweria"
		end
		local switcher = header:FindFirstChild("TabSwitcher")
		updateTabButtons(switcher, state.Mode)
	end

	if isAllTime then
		if podium then
			podium.Visible = true
			local slotMap = {
				[1] = podium:FindFirstChild("Slot_1"),
				[2] = podium:FindFirstChild("Slot_2"),
				[3] = podium:FindFirstChild("Slot_3"),
			}
			for rank = 1, 3 do
				local slot = slotMap[rank]
				local data = listData[rank]
				if slot then
					local av = slot:FindFirstChild("Avatar")
					local nl = slot:FindFirstChild("NameLabel")
					local ul = slot:FindFirstChild("UserLabel")
					local al = slot:FindFirstChild("AmountLabel", true)

					if data then
						local uInfo = resolveUserInfo(data.UserId, data.DisplayName, data.Username)
						if av then av.Image = getAvatarThumb(data.UserId) end
						applyPodiumNameLabels(nl, ul, uInfo)
						if al then al.Text = "Rp " .. formatThousands(data.Amount or 0, ".") end
					else
						if av then av.Image = getAvatarThumb(1) end
						applyPodiumNameLabels(nl, ul, { DisplayName = "-", HasDistinctUser = false })
						if al then al.Text = "Rp 0" end
					end
				end
			end
		end

		scroll.Position = UDim2.new(0, 24, 0, 405)
		scroll.Size = UDim2.new(1, -48, 1, -420)
	else
		if podium then
			podium.Visible = false
		end
		scroll.Position = UDim2.new(0, 24, 0, 105)
		scroll.Size = UDim2.new(1, -48, 1, -120)
	end

	template.Visible = false

	local pool = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c ~= template then
			table.insert(pool, c)
		end
	end

	local startRank = isAllTime and 4 or 1
	local renderItems = {}
	for i = startRank, #listData do
		table.insert(renderItems, listData[i])
	end

	for i = #pool + 1, math.max(30, #renderItems) do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.Visible = false
		clone.Parent = scroll
		table.insert(pool, clone)
	end

	for i, item in ipairs(renderItems) do
		local row = pool[i]
		if not row then
			row = template:Clone()
			row.Name = "Entry_" .. i
			row.Parent = scroll
			table.insert(pool, row)
		end

		row.Visible = true
		row.LayoutOrder = i

		local uInfo = resolveUserInfo(item.UserId, item.DisplayName, item.Username)
		local rankLbl = row:FindFirstChild("RankLabel")
		local avatarImg = row:FindFirstChild("AvatarImg")
		local nameLbl = row:FindFirstChild("NameLabel")
		local userLbl = row:FindFirstChild("UserLabel")
		local valLbl = row:FindFirstChild("ValueLabel")

		if rankLbl then rankLbl.Text = "#" .. tostring(item.Rank or (startRank + i - 1)) end
		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end
		applyNameLabels(nameLbl, userLbl, uInfo)
		if valLbl then valLbl.Text = "Rp " .. formatThousands(item.Amount or 0, ".") end
	end

	for i = #renderItems + 1, #pool do
		pool[i].Visible = false
	end

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end
end

-- ==============================================================================
-- TAB SWITCHER CLICK BINDINGS
-- ==============================================================================
local function setupTabClicks()
	-- Robux Board
	local robuxBoard = getLeaderboardBoard("JekyDonationBoard")
	local robuxGui = robuxBoard and (robuxBoard:FindFirstChild("EldetoGui") or robuxBoard:FindFirstChildWhichIsA("SurfaceGui"))
	local robuxMain = robuxGui and (robuxGui:FindFirstChild("MainFrame") or robuxGui:FindFirstChild("Mainframe"))
	local robuxTabs = robuxMain and robuxMain:FindFirstChild("Header") and robuxMain.Header:FindFirstChild("TabSwitcher")
	if robuxTabs then
		local aBtn = robuxTabs:FindFirstChild("AllTimeBtn")
		local dBtn = robuxTabs:FindFirstChild("DailyBtn")
		if aBtn and not aBtn:GetAttribute("Bound") then
			aBtn:SetAttribute("Bound", true)
			aBtn.MouseButton1Click:Connect(function()
				States.Robux.Mode = "AllTime"
				States.Robux.LastClick = os.clock()
				renderRobuxBoard()
			end)
		end
		if dBtn and not dBtn:GetAttribute("Bound") then
			dBtn:SetAttribute("Bound", true)
			dBtn.MouseButton1Click:Connect(function()
				States.Robux.Mode = "Daily"
				States.Robux.LastClick = os.clock()
				renderRobuxBoard()
			end)
		end
	end

	-- Saweria Board
	local saweriaBoard = getLeaderboardBoard("BoardSaweria")
	local saweriaGui = saweriaBoard and (saweriaBoard:FindFirstChild("LeaderboardGui") or saweriaBoard:FindFirstChildWhichIsA("SurfaceGui"))
	local saweriaMain = saweriaGui and (saweriaGui:FindFirstChild("MainFrame") or saweriaGui:FindFirstChild("Mainframe"))
	local saweriaTabs = saweriaMain and saweriaMain:FindFirstChild("Header") and saweriaMain.Header:FindFirstChild("TabSwitcher")
	if saweriaTabs then
		local aBtn = saweriaTabs:FindFirstChild("AllTimeBtn")
		local dBtn = saweriaTabs:FindFirstChild("DailyBtn")
		if aBtn and not aBtn:GetAttribute("Bound") then
			aBtn:SetAttribute("Bound", true)
			aBtn.MouseButton1Click:Connect(function()
				States.Saweria.Mode = "AllTime"
				States.Saweria.LastClick = os.clock()
				renderSaweriaBoard()
			end)
		end
		if dBtn and not dBtn:GetAttribute("Bound") then
			dBtn:SetAttribute("Bound", true)
			dBtn.MouseButton1Click:Connect(function()
				States.Saweria.Mode = "Daily"
				States.Saweria.LastClick = os.clock()
				renderSaweriaBoard()
			end)
		end
	end
end

-- ==============================================================================
-- AUTO-ROTATE TIMER (Only Robux & Saweria auto-cycle; Likes & Level are All Time Only)
-- ==============================================================================
task.spawn(function()
	while true do
		task.wait(AUTO_ROTATE_INTERVAL)
		local now = os.clock()

		-- Robux
		if now - States.Robux.LastClick > USER_INTERACTION_PAUSE then
			States.Robux.Mode = (States.Robux.Mode == "AllTime") and "Daily" or "AllTime"
			renderRobuxBoard()
		end

		-- Saweria
		if now - States.Saweria.LastClick > USER_INTERACTION_PAUSE then
			States.Saweria.Mode = (States.Saweria.Mode == "AllTime") and "Daily" or "AllTime"
			renderSaweriaBoard()
		end
	end
end)

-- ==============================================================================
-- REMOTE LISTENERS
-- ==============================================================================
local updateLikeBoardRemote = ReplicatedStorage:WaitForChild("UpdateLikeBoard", 15)
if updateLikeBoardRemote then
	updateLikeBoardRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			if payload.AllTime or payload.Daily then
				States.Likes.AllTime = payload.AllTime or {}
				States.Likes.Daily = payload.Daily or {}
			else
				States.Likes.AllTime = payload
				States.Likes.Daily = payload
			end
		end
		renderLikesBoard()
	end)
	updateLikeBoardRemote:FireServer()
end

local updateLevelBoardRemote = ReplicatedStorage:WaitForChild("UpdateLevelBoard", 15)
if updateLevelBoardRemote then
	updateLevelBoardRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			States.Level.AllTime = payload
		end
		renderLevelBoard()
	end)
	updateLevelBoardRemote:FireServer()
end

local updateTopBoardRemote = ReplicatedStorage:WaitForChild("UpdateTopBoard", 15)
if updateTopBoardRemote then
	updateTopBoardRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			if payload.AllTime or payload.Daily then
				States.Robux.AllTime = payload.AllTime or {}
				States.Robux.Daily = payload.Daily or {}
			else
				States.Robux.AllTime = payload
				States.Robux.Daily = payload
			end
		end
		renderRobuxBoard()
	end)
	updateTopBoardRemote:FireServer()
end

local updateSaweriaEvent = ReplicatedStorage:WaitForChild("UpdateSaweriaTopBoard", 15)
if updateSaweriaEvent then
	updateSaweriaEvent.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			if payload.AllTime or payload.Daily then
				States.Saweria.AllTime = payload.AllTime or {}
				States.Saweria.Daily = payload.Daily or {}
			else
				States.Saweria.AllTime = payload
				States.Saweria.Daily = payload
			end
		end
		renderSaweriaBoard()
	end)
	updateSaweriaEvent:FireServer()
end

-- Periodic setup re-check to bind buttons and ensure boards render cleanly
task.spawn(function()
	for i = 1, 5 do
		setupTabClicks()
		renderLikesBoard()
		renderLevelBoard()
		renderRobuxBoard()
		renderSaweriaBoard()
		task.wait(2)
	end
end)

print("[LEADERBOARDS] Client initialized! Top Likes & Top Level (All Time Only), Top Robux & Saweria (All Time & Daily).")

