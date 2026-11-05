--!optimize 2
--!native

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local AUTO_ROTATE_INTERVAL = 30
local USER_INTERACTION_PAUSE = 30

local MAX_RENDER_ROWS = 25
local MAX_USER_INFO_BATCH = 100

local FormatUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("FormatUtils"))

local function formatThousands(num, separator)
	return FormatUtils.formatNumber(num, separator or ",")
end

local function getLeaderboardBoard(boardName)
	local folder = workspace:FindFirstChild("Leaderboard")
	if folder then
		local b = folder:FindFirstChild(boardName)
		if b then return b end
	end
	return workspace:FindFirstChild(boardName, true)
end

local function getBoardElements(boardName, guiName)
	local board = getLeaderboardBoard(boardName)
	if not board then return end
	local gui = (guiName and board:FindFirstChild(guiName)) or board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end
	local main = gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe")
	if not main then return end
	local scroll = main:FindFirstChild("ScrollFrame")
	local template = scroll and scroll:FindFirstChild("TemplateFrame")
	if not (scroll and template) then return end
	return main, main:FindFirstChild("Header"), scroll, template, main:FindFirstChild("PodiumFrame")
end

local userInfoCache = {}
local renderScheduled = false

local renderLikesBoard
local renderLevelBoard
local renderRobuxBoard
local renderSaweriaBoard

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

local pendingUserInfoIds = {}
local userInfoFetchAttempted = {}
local userInfoRetryAt = {}
local userInfoBatchScheduled = false

local function flushUserInfoBatch()
	userInfoBatchScheduled = false
	local ids = {}
	for userId in pairs(pendingUserInfoIds) do
		table.insert(ids, userId)
	end
	table.clear(pendingUserInfoIds)

	for startIndex = 1, #ids, MAX_USER_INFO_BATCH do
		local batch = {}
		for i = startIndex, math.min(startIndex + MAX_USER_INFO_BATCH - 1, #ids) do
			table.insert(batch, ids[i])
		end

		local ok, infoList = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, batch)
		local requestSucceeded = ok and type(infoList) == "table"
		if requestSucceeded then
			for _, info in ipairs(infoList) do
				local username = tostring(info.Username or "")
				local cleanUser = username:gsub("^@", ""):gsub("%s+", "_")
				local displayName = tostring(info.DisplayName or username)
				userInfoCache[info.Id] = {
					DisplayName = displayName,
					Username = cleanUser ~= "" and ("@" .. cleanUser) or "",
					HasDistinctUser = cleanUser ~= "" and displayName:lower() ~= cleanUser:lower(),
				}
			end
		end

		for _, userId in ipairs(batch) do
			if requestSucceeded then
				userInfoFetchAttempted[userId] = true
				userInfoRetryAt[userId] = nil
			else
				userInfoRetryAt[userId] = os.clock() + 30
			end
		end
	end

	scheduleRenderAll()
end

local function queueUserInfoFetch(userId)
	if userInfoCache[userId] or userInfoFetchAttempted[userId] then
		return
	end
	local retryAt = userInfoRetryAt[userId]
	if retryAt and os.clock() < retryAt then
		return
	end
	pendingUserInfoIds[userId] = true
	if userInfoBatchScheduled then return end
	userInfoBatchScheduled = true
	task.delay(0.05, flushUserInfoBatch)
end

local function resolveUserInfo(userId, fallbackDisplayName, fallbackUsername)
	local cleanUser = fallbackUsername and fallbackUsername:gsub("^@", ""):gsub("%s+", "_") or ""
	if cleanUser == "user" or cleanUser == "player" or cleanUser:find("^player_%d+") then
		cleanUser = ""
	end

	local dName = fallbackDisplayName or "Player"
	local hasDistinct = (cleanUser ~= "" and dName:lower() ~= cleanUser:lower())

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

	local needsFetch = (cleanUser == "" or dName == "Player" or dName:find("^Player_%d+") or dName:find("^Sultan_%d+"))

	if needsFetch then
		queueUserInfoFetch(userId)
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
	local id = (userId and userId > 1) and userId or 1
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", id)
end

local States = {
	Likes = { Mode = "AllTime", AllTime = {}, Daily = {} },
	Level = { Mode = "AllTime", AllTime = {} },
	Robux = { Mode = "AllTime", AllTime = {}, Daily = {}, LastClick = 0 },
	Saweria = { Mode = "AllTime", AllTime = {}, Daily = {}, LastClick = 0 },
}

local RANK_COLORS = {
	[1] = Color3.fromRGB(255, 215, 0),
	[2] = Color3.fromRGB(192, 192, 192),
	[3] = Color3.fromRGB(205, 127, 50),
}
local DEFAULT_RANK_COLOR = Color3.fromRGB(255, 255, 255)

local function updateTabButtons(switcher, currentMode)
	if not switcher then return end
	local allTimeBtn = switcher:FindFirstChild("AllTimeBtn")
	local dailyBtn = switcher:FindFirstChild("DailyBtn")

	if allTimeBtn then
		local selected = (currentMode == "AllTime")
		allTimeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		allTimeBtn.BackgroundTransparency = selected and 0 or 1
		allTimeBtn.TextColor3 = selected and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(160, 160, 160)
	end

	if dailyBtn then
		local selected = (currentMode == "Daily")
		dailyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dailyBtn.BackgroundTransparency = selected and 0 or 1
		dailyBtn.TextColor3 = selected and Color3.fromRGB(15, 15, 15) or Color3.fromRGB(160, 160, 160)
	end
end

local function getOrCreatePool(scroll, template, targetCount)
	local pool = {}
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") and c ~= template then
			table.insert(pool, c)
		end
	end
	local target = math.min(MAX_RENDER_ROWS, math.max(10, targetCount))
	for i = #pool + 1, target do
		local clone = template:Clone()
		clone.Name = "Entry_" .. i
		clone.Visible = false
		clone.Parent = scroll
		table.insert(pool, clone)
	end

	for i = target + 1, #pool do
		pool[i].Visible = false
	end

	return pool
end

local function updateScrollCanvas(scroll)
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
	end
end

renderLikesBoard = function()
	local _, header, scroll, template = getBoardElements("JekyLikeBoard", "JekyGui")
	if not scroll then return end

	local state = States.Likes
	local listData = (#state.AllTime > 0) and state.AllTime or state.Daily

	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then sub.Text = "All Time Top Likes" end
		local title = header:FindFirstChild("Title")
		if title then title.Text = "Top Likes" end
	end

	template.Visible = false
	local pool = getOrCreatePool(scroll, template, #listData)
	local count = math.min(#listData, #pool)

	for i = 1, count do
		local item = listData[i]
		local row = pool[i]
		row.Visible = true
		row.LayoutOrder = i

		local rankLbl = row:FindFirstChild("RankLabel")
		if rankLbl then
			rankLbl.Text = "#" .. tostring(item.Rank or i)
			rankLbl.TextColor3 = RANK_COLORS[i] or DEFAULT_RANK_COLOR
		end

		local avatarImg = row:FindFirstChild("AvatarImg")
		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end

		applyNameLabels(row:FindFirstChild("NameLabel"), row:FindFirstChild("UserLabel"), resolveUserInfo(item.UserId, item.DisplayName, item.Username))

		local valLbl = row:FindFirstChild("ValueLabel")
		if valLbl then valLbl.Text = formatThousands(item.Likes or item.Amount or 0, ".") end

		local iconLbl = row:FindFirstChild("IconLabel")
		if iconLbl and iconLbl:IsA("TextLabel") then
			iconLbl.Text = "♡"
			iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	for i = count + 1, #pool do pool[i].Visible = false end
	updateScrollCanvas(scroll)
end

renderLevelBoard = function()
	local _, header, scroll, template = getBoardElements("JekyLevelBoard", "JekyGui")
	if not scroll then
		_, header, scroll, template = getBoardElements("EldetoLevelBoard", "EldetoLevelBoard")
	end
	if not scroll then return end

	local listData = States.Level.AllTime or {}

	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then sub.Text = "All Time Top Level" end
		local title = header:FindFirstChild("Title")
		if title then title.Text = "Top Level" end
	end

	template.Visible = false
	local pool = getOrCreatePool(scroll, template, #listData)
	local count = math.min(#listData, #pool)

	for i = 1, count do
		local item = listData[i]
		local row = pool[i]
		row.Visible = true
		row.LayoutOrder = i

		local userId = item.userId or item.UserId
		local level = item.level or item.Level or 1
		local rank = item.rank or item.Rank or i

		local rankLbl = row:FindFirstChild("RankLabel")
		if rankLbl then
			rankLbl.Text = "#" .. tostring(rank)
			rankLbl.TextColor3 = RANK_COLORS[i] or DEFAULT_RANK_COLOR
		end

		local avatarImg = row:FindFirstChild("AvatarImg")
		if avatarImg then avatarImg.Image = getAvatarThumb(userId) end

		applyNameLabels(row:FindFirstChild("NameLabel"), row:FindFirstChild("UserLabel"), resolveUserInfo(userId, item.DisplayName, item.Username))

		local valLbl = row:FindFirstChild("ValueLabel")
		if valLbl then valLbl.Text = "Lv. " .. formatThousands(level, ".") end

		local iconLbl = row:FindFirstChild("IconLabel")
		if iconLbl and iconLbl:IsA("TextLabel") then
			iconLbl.Text = "★"
			iconLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
		end
	end

	for i = count + 1, #pool do pool[i].Visible = false end
	updateScrollCanvas(scroll)
end

local function renderPodium(podium, listData, formatValueFn)
	if not podium then return end
	local slotMap = {
		podium:FindFirstChild("Slot_1"),
		podium:FindFirstChild("Slot_2"),
		podium:FindFirstChild("Slot_3"),
	}
	for rank = 1, 3 do
		local slot = slotMap[rank]
		if slot then
			local data = listData[rank]
			local av = slot:FindFirstChild("Avatar")
			local nl = slot:FindFirstChild("NameLabel")
			local ul = slot:FindFirstChild("UserLabel")
			local al = slot:FindFirstChild("AmountLabel", true)

			if data then
				if av then av.Image = getAvatarThumb(data.UserId) end
				applyPodiumNameLabels(nl, ul, resolveUserInfo(data.UserId, data.DisplayName, data.Username))
				if al then al.Text = formatValueFn(data.Amount or 0) end
			else
				if av then av.Image = getAvatarThumb(1) end
				applyPodiumNameLabels(nl, ul, { DisplayName = "-", HasDistinctUser = false })
				if al then al.Text = formatValueFn(0) end
			end
		end
	end
end

renderRobuxBoard = function()
	local _, header, scroll, template, podium = getBoardElements("JekyDonationBoard", "EldetoGui")
	if not scroll then return end

	local state = States.Robux
	local isAllTime = (state.Mode == "AllTime")
	local listData = isAllTime and state.AllTime or state.Daily

	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then sub.Text = isAllTime and "All Time Top Robux Donation" or "Top Daily Robux" end
		updateTabButtons(header:FindFirstChild("TabSwitcher"), state.Mode)
	end

	if isAllTime then
		if podium then
			podium.Visible = true
			renderPodium(podium, listData, function(amt) return formatThousands(amt, ",") end)
		end
		scroll.Position = UDim2.new(0, 24, 0, 405)
		scroll.Size = UDim2.new(1, -48, 1, -420)
	else
		if podium then podium.Visible = false end
		scroll.Position = UDim2.new(0, 24, 0, 105)
		scroll.Size = UDim2.new(1, -48, 1, -120)
	end

	template.Visible = false
	local startRank = isAllTime and 4 or 1
	local maxRows = isAllTime and (MAX_RENDER_ROWS - 3) or MAX_RENDER_ROWS
	local count = math.min(maxRows, math.max(0, #listData - startRank + 1))
	local pool = getOrCreatePool(scroll, template, count)

	for i = 1, count do
		local item = listData[startRank + i - 1]
		local row = pool[i]
		row.Visible = true
		row.LayoutOrder = i

		local rankLbl = row:FindFirstChild("RankLabel")
		if rankLbl then rankLbl.Text = "#" .. tostring(item.Rank or (startRank + i - 1)) end

		local avatarImg = row:FindFirstChild("AvatarImg")
		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end

		applyNameLabels(row:FindFirstChild("NameLabel"), row:FindFirstChild("UserLabel"), resolveUserInfo(item.UserId, item.DisplayName, item.Username))

		local valLbl = row:FindFirstChild("ValueLabel")
		if valLbl then valLbl.Text = formatThousands(item.Amount or 0, ",") end

		local iconLbl = row:FindFirstChild("IconLabel")
		if iconLbl and iconLbl:IsA("ImageLabel") then
			iconLbl.Image = "rbxasset://textures/ui/common/robux_small.png"
		end
	end

	for i = count + 1, #pool do pool[i].Visible = false end
	updateScrollCanvas(scroll)
end

renderSaweriaBoard = function()
	local _, header, scroll, template, podium = getBoardElements("BoardSaweria", "LeaderboardGui")
	if not scroll then return end

	local state = States.Saweria
	local isAllTime = (state.Mode == "AllTime")
	local listData = isAllTime and state.AllTime or state.Daily

	if header then
		local sub = header:FindFirstChild("Subtitle")
		if sub then sub.Text = isAllTime and "All Time Top Saweria Donation" or "Top Daily Saweria" end
		updateTabButtons(header:FindFirstChild("TabSwitcher"), state.Mode)
	end

	if isAllTime then
		if podium then
			podium.Visible = true
			renderPodium(podium, listData, function(amt) return "Rp " .. formatThousands(amt, ".") end)
		end
		scroll.Position = UDim2.new(0, 24, 0, 405)
		scroll.Size = UDim2.new(1, -48, 1, -420)
	else
		if podium then podium.Visible = false end
		scroll.Position = UDim2.new(0, 24, 0, 105)
		scroll.Size = UDim2.new(1, -48, 1, -120)
	end

	template.Visible = false
	local startRank = isAllTime and 4 or 1
	local maxRows = isAllTime and (MAX_RENDER_ROWS - 3) or MAX_RENDER_ROWS
	local count = math.min(maxRows, math.max(0, #listData - startRank + 1))
	local pool = getOrCreatePool(scroll, template, count)

	for i = 1, count do
		local item = listData[startRank + i - 1]
		local row = pool[i]
		row.Visible = true
		row.LayoutOrder = i

		local rankLbl = row:FindFirstChild("RankLabel")
		if rankLbl then rankLbl.Text = "#" .. tostring(item.Rank or (startRank + i - 1)) end

		local avatarImg = row:FindFirstChild("AvatarImg")
		if avatarImg then avatarImg.Image = getAvatarThumb(item.UserId) end

		applyNameLabels(row:FindFirstChild("NameLabel"), row:FindFirstChild("UserLabel"), resolveUserInfo(item.UserId, item.DisplayName, item.Username))

		local valLbl = row:FindFirstChild("ValueLabel")
		if valLbl then valLbl.Text = "Rp " .. formatThousands(item.Amount or 0, ".") end
	end

	for i = count + 1, #pool do pool[i].Visible = false end
	updateScrollCanvas(scroll)
end

local function bindTabSwitcher(boardName, guiName, stateObj, renderFn)
	local board = getLeaderboardBoard(boardName)
	local gui = board and (board:FindFirstChild(guiName) or board:FindFirstChildWhichIsA("SurfaceGui"))
	local main = gui and (gui:FindFirstChild("MainFrame") or gui:FindFirstChild("Mainframe"))
	local tabs = main and main:FindFirstChild("Header") and main.Header:FindFirstChild("TabSwitcher")
	if not tabs then return end

	for _, mode in ipairs({"AllTime", "Daily"}) do
		local btn = tabs:FindFirstChild(mode .. "Btn")
		if btn and not btn:GetAttribute("Bound") then
			btn:SetAttribute("Bound", true)
			btn.MouseButton1Click:Connect(function()
				local now = os.clock()
				if now - (stateObj.LastClick or 0) < 0.3 then return end
				stateObj.LastClick = now
				stateObj.Mode = mode
				renderFn()
			end)
		end
	end
end

local function setupTabClicks()
	bindTabSwitcher("JekyDonationBoard", "EldetoGui", States.Robux, renderRobuxBoard)
	bindTabSwitcher("BoardSaweria", "LeaderboardGui", States.Saweria, renderSaweriaBoard)
end

task.spawn(function()
	while true do
		task.wait(AUTO_ROTATE_INTERVAL)
		local now = os.clock()

		if now - States.Robux.LastClick > USER_INTERACTION_PAUSE then
			States.Robux.Mode = (States.Robux.Mode == "AllTime") and "Daily" or "AllTime"
			renderRobuxBoard()
		end

		if now - States.Saweria.LastClick > USER_INTERACTION_PAUSE then
			States.Saweria.Mode = (States.Saweria.Mode == "AllTime") and "Daily" or "AllTime"
			renderSaweriaBoard()
		end
	end
end)

local function setupBoardRemote(remoteName, stateObj, renderFn, isLevel)
	local remote = ReplicatedStorage:WaitForChild(remoteName, 15)
	if not remote then return end

	remote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			if isLevel then
				stateObj.AllTime = payload
			elseif payload.AllTime or payload.Daily then
				stateObj.AllTime = payload.AllTime or {}
				stateObj.Daily = payload.Daily or {}
			else
				stateObj.AllTime = payload
				stateObj.Daily = payload
			end
		end
		renderFn()
	end)
	remote:FireServer()
end

setupBoardRemote("UpdateLikeBoard", States.Likes, renderLikesBoard)
setupBoardRemote("UpdateLevelBoard", States.Level, renderLevelBoard, true)
setupBoardRemote("UpdateTopBoard", States.Robux, renderRobuxBoard)
setupBoardRemote("UpdateSaweriaTopBoard", States.Saweria, renderSaweriaBoard)

task.spawn(function()
	for _ = 1, 5 do
		setupTabClicks()
		renderLikesBoard()
		renderLevelBoard()
		renderRobuxBoard()
		renderSaweriaBoard()
		task.wait(2)
	end
end)

print("[LEADERBOARDS] Client initialized! Top Likes & Top Level (All Time Only), Top Robux & Saweria (All Time & Daily).")
