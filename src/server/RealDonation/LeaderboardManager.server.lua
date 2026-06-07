-- ==========================================
-- LEADERBOARD BOARD MANAGER - SERVER SCRIPT
-- LOKASI: ServerScriptService
-- ==========================================

local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ========== CONFIG ==========
local CONFIG = {
	UPDATE_INTERVAL = 60,
	MAX_DISPLAY     = 100,
	TWEEN_DURATION  = 0.4,
}

-- ========== GUI ELEMENTS ==========
local boardModel     = workspace:WaitForChild("EldetoRealBoard", 10)
local boardPart      = boardModel and boardModel:WaitForChild("EldetoReadBoard", 10)
local mainframe      = boardPart  and boardPart:WaitForChild("Mainframe", 10)
local container      = mainframe  and mainframe:WaitForChild("Container", 10)
local scrollingframe = container  and container:WaitForChild("ScrollingFrame", 10)
local template       = scrollingframe and scrollingframe:WaitForChild("TemplateFrame", 10)

if not template then
	return
end

template.Visible = false

-- ========== BINDABLE EVENT SETUP ==========
local function getOrCreateBindable()
	local existing = ServerStorage:FindFirstChild("LeaderboardBindable")
	if existing then return existing end

	local bindable = Instance.new("BindableEvent")
	bindable.Name  = "LeaderboardBindable"
	bindable.Parent = ServerStorage
	return bindable
end

local leaderboardBindable = getOrCreateBindable()

-- ========== STATE ==========
local currentFrames  = {}
local lastUpdateTime = 0
local isBuildingBoard = false

-- ========== HELPERS ==========

local function formatCoins(amount)
	local formatted = tostring(math.floor(tonumber(amount) or 0))
	while true do
		local newFormatted, replacements = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = newFormatted
		if replacements == 0 then break end
	end
	return formatted
end

local function getRankColor(rank)
	if rank == 1 then
		return Color3.fromRGB(255, 215, 0)
	elseif rank == 2 then
		return Color3.fromRGB(192, 192, 192)
	elseif rank == 3 then
		return Color3.fromRGB(205, 127, 50)
	else
		return Color3.fromRGB(255, 255, 255)
	end
end

-- ========== CLEAR BOARD ==========

local function clearBoard()
	for _, frame in pairs(currentFrames) do
		if frame and frame.Parent then
			frame:Destroy()
		end
	end
	currentFrames = {}
end

-- ========== UPDATE BOARD ==========

local function updateBoard(leaderboardData)
	if isBuildingBoard then
		return
	end

	if not leaderboardData or #leaderboardData == 0 then
		return
	end

	isBuildingBoard = true
	lastUpdateTime  = os.clock()

	clearBoard()

	local displayCount = math.min(#leaderboardData, CONFIG.MAX_DISPLAY)
	local frameHeight  = template.Size.Y.Offset

	for rank = 1, displayCount do
		local entry = leaderboardData[rank]
		if not entry then continue end

		local coins = tonumber(entry.coins) or tonumber(entry.total) or 0
		local name  = tostring(entry.name or "Unknown")

		if name ~= "" and coins > 0 then
			local frame = template:Clone()
			frame.Name    = "Rank_" .. rank
			frame.Visible = true
			frame.Parent  = scrollingframe

			local rankLabel   = frame:FindFirstChild("RankLabel")
			local playerLabel = frame:FindFirstChild("PlayerLabel")
			local amountLabel = frame:FindFirstChild("AmountLabel")

			if rankLabel and playerLabel and amountLabel then
				rankLabel.Text   = "#" .. rank
				playerLabel.Text = name
				amountLabel.Text = formatCoins(coins) .. " Coins"

				rankLabel.TextColor3 = getRankColor(rank)

				if rank <= 3 then
					rankLabel.Font     = Enum.Font.GothamBold
					playerLabel.Font   = Enum.Font.GothamBold
					amountLabel.Font   = Enum.Font.GothamBold
					rankLabel.TextSize = 20
				end

				local targetPos = UDim2.new(0, 0, 0, (rank - 1) * frameHeight)
				frame.Position  = UDim2.new(1.2, 0, 0, (rank - 1) * frameHeight)

				task.spawn(function()
					task.wait(0.02 * rank)
					TweenService:Create(
						frame,
						TweenInfo.new(CONFIG.TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Position = targetPos }
					):Play()
				end)

				table.insert(currentFrames, frame)
			else
				frame:Destroy()
			end
		end
	end

	task.delay(CONFIG.TWEEN_DURATION + 0.15, function()
		local listLayout = scrollingframe:FindFirstChildOfClass("UIListLayout")
		if listLayout then
			scrollingframe.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
		else
			scrollingframe.CanvasSize = UDim2.new(0, 0, 0, displayCount * frameHeight + 10)
		end
		isBuildingBoard = false
	end)
end

-- ========== BINDABLE EVENT LISTENER ==========

leaderboardBindable.Event:Connect(function(data)
	if not data or type(data) ~= "table" then
		return
	end
	updateBoard(data)
end)

-- ========== FALLBACK POLLING ==========

task.spawn(function()
	task.wait(15)

	if _G.DonationLeaderboard and #_G.DonationLeaderboard > 0 then
		updateBoard(_G.DonationLeaderboard)
	end

	while true do
		task.wait(CONFIG.UPDATE_INTERVAL)

		local now = os.clock()
		if (now - lastUpdateTime) > 30 then
			if _G.DonationLeaderboard and #_G.DonationLeaderboard > 0 then
				updateBoard(_G.DonationLeaderboard)
			end
		end
	end
end)

-- ========== CONSOLE HELPERS ==========

_G.UpdateLeaderboardBoard = function()
	if _G.DonationLeaderboard and #_G.DonationLeaderboard > 0 then
		updateBoard(_G.DonationLeaderboard)
	end
end

_G.ClearLeaderboardBoard = function()
	clearBoard()
end

_G.ForceLeaderboardUpdate = function(data)
	if data then
		updateBoard(data)
	end
end