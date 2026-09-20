-- ============================================================
-- ServerListClient (ClubKit Server Browser Controller)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local remotesFolder = ReplicatedStorage:WaitForChild("ServerListRemotes", 10)
local getServerListRF = remotesFolder and remotesFolder:WaitForChild("GetServerList", 5)
local teleportToServerRF = remotesFolder and remotesFolder:WaitForChild("TeleportToServer", 5)

-- GUI References (Manual StarterGui instance cloned to PlayerGui)
local screenGui = playerGui:WaitForChild("ServerListGui")
local mainframe = screenGui:WaitForChild("MainFrame")
local header = mainframe:WaitForChild("Header")
local rightControls = header:WaitForChild("RightControls")

local searchContainer = rightControls:WaitForChild("SearchContainer")
local searchBox = searchContainer:WaitForChild("SearchBox")
local refreshBtn = rightControls:WaitForChild("RefreshBtn")
local closeBtn = rightControls:WaitForChild("CloseBtn")

local scrollContainer = mainframe:WaitForChild("ScrollContainer")
local cardTemplate = scrollContainer:WaitForChild("CardTemplate")

-- State
local cachedServers = {}
local spawnedCards = {}
local isFetching = false
local INITIAL_POSITION = UDim2.new(0.5, 0, 0.5, 0)
mainframe.Position = INITIAL_POSITION

-- ============================================================
-- POSITION RESET & CLOSE LOGIC
-- ============================================================
mainframe:GetPropertyChangedSignal("Visible"):Connect(function()
	if mainframe.Visible then
		mainframe.Position = INITIAL_POSITION
		searchBox.Text = ""
		task.spawn(function()
			-- Refresh servers list when opened
			task.wait(0.05)
			fetchAndRenderServers()
		end)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	mainframe.Visible = false
end)

-- ============================================================
-- HEADER DRAG LOGIC
-- ============================================================
local isDragging = false
local dragStartMouse = nil
local dragStartFramePos = nil

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if input.Target == closeBtn or input.Target:IsDescendantOf(closeBtn) or
		   input.Target == refreshBtn or input.Target:IsDescendantOf(refreshBtn) or
		   input.Target == searchBox or input.Target:IsDescendantOf(searchContainer) then
			return
		end
		isDragging = true
		dragStartMouse = input.Position
		dragStartFramePos = mainframe.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartMouse
		local newX = dragStartFramePos.X.Offset + delta.X
		local newY = dragStartFramePos.Y.Offset + delta.Y
		mainframe.Position = UDim2.new(dragStartFramePos.X.Scale, newX, dragStartFramePos.Y.Scale, newY)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		isDragging = false
	end
end)

-- ============================================================
-- CLEAR SPAWNED CARDS
-- ============================================================
local function clearCards()
	for _, card in ipairs(spawnedCards) do
		if card and card.Parent then
			card:Destroy()
		end
	end
	spawnedCards = {}
end

-- ============================================================
-- RENDER SERVER CARDS
-- ============================================================
local function renderServerCards(filterText)
	clearCards()
	local query = filterText and string.lower(string.gsub(filterText, "^%s*(.-)%s*$", "%1")) or ""

	local order = 1
	for _, sData in ipairs(cachedServers) do
		local match = true
		if query ~= "" then
			local nameLower = string.lower(sData.name or "")
			local locLower = string.lower(sData.location or "")
			local verLower = string.lower(sData.version or "")
			local idLower = string.lower(sData.jobId or "")
			match = string.find(nameLower, query, 1, true) ~= nil or
			        string.find(locLower, query, 1, true) ~= nil or
			        string.find(verLower, query, 1, true) ~= nil or
			        string.find(idLower, query, 1, true) ~= nil
		end

		if match then
			local card = cardTemplate:Clone()
			card.Name = "ServerCard_" .. (sData.name or order)
			card.Visible = true
			card.LayoutOrder = sData.isCurrent and 0 or order
			order = order + 1

			local info = card:FindFirstChild("InfoContainer")
			local title = info and info:FindFirstChild("ServerTitle")
			local subtitle = info and info:FindFirstChild("Subtitle")
			local metaList = info and info:FindFirstChild("MetaList")
			local playerCount = card:FindFirstChild("PlayerCount")
			local bottomRow = card:FindFirstChild("BottomRow")
			local actionBtn = card:FindFirstChild("ActionButton")

			-- Server Title & Subtitle
			if title then
				title.Text = sData.name or "SERVER"
				if sData.isCurrent then
					title.TextColor3 = Color3.fromRGB(0, 162, 255)
				else
					title.TextColor3 = Color3.fromRGB(240, 245, 255)
				end
			end

			if subtitle then
				subtitle.Visible = (sData.isCurrent == true)
			end

			-- Player Count
			if playerCount then
				playerCount.Text = "👤 " .. tostring(sData.playing or 0) .. "/" .. tostring(sData.maxPlayers or 80)
			end

			-- Meta lines
			if metaList then
				local loc = metaList:FindFirstChild("MetaLocation")
				if loc then loc.Text = "Location : " .. (sData.location or "Indonesia") end

				local up = metaList:FindFirstChild("MetaUptime")
				if up then up.Text = "Up Time : " .. (sData.uptime or "00h 00m 00s") end

				local avg = metaList:FindFirstChild("MetaAverage")
				if avg then avg.Text = "Average : " .. (sData.average or "00h 00m 00s") end

				local ver = metaList:FindFirstChild("MetaVersion")
				if ver then ver.Text = "Version : " .. (sData.version or "1") end

				local crt = metaList:FindFirstChild("MetaCreated")
				if crt then crt.Text = "Created : " .. (sData.created or os.date("%d %b %Y")) end
			end

			-- Avatars in Bottom Row
			if bottomRow then
				local avatarsContainer = bottomRow:FindFirstChild("Avatars")
				if avatarsContainer then
					avatarsContainer:ClearAllChildren()

					local avLayout = Instance.new("UIListLayout")
					avLayout.FillDirection = Enum.FillDirection.Horizontal
					avLayout.SortOrder = Enum.SortOrder.LayoutOrder
					avLayout.Padding = UDim.new(0, -6) -- Overlapping effect
					avLayout.Parent = avatarsContainer

					local userIds = sData.playerUserIds or {}
					local maxShow = math.min(4, #userIds)
					for i = 1, maxShow do
						local uId = userIds[i]
						local headshot = Instance.new("ImageLabel")
						headshot.Name = "Avatar_" .. i
						headshot.Size = UDim2.new(0, 22, 0, 22)
						headshot.LayoutOrder = i
						headshot.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
						headshot.BorderSizePixel = 0
						headshot.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(uId) .. "&w=48&h=48"
						headshot.Parent = avatarsContainer

						local hCorner = Instance.new("UICorner")
						hCorner.CornerRadius = UDim.new(1, 0)
						hCorner.Parent = headshot

						local hStroke = Instance.new("UIStroke")
						hStroke.Color = Color3.fromRGB(20, 22, 27)
						hStroke.Thickness = 1.2
						hStroke.Parent = headshot
					end

					-- If more players than shown avatars, add +N pill
					local extra = (sData.playing or 0) - maxShow
					if extra > 0 then
						local extraPill = Instance.new("TextLabel")
						extraPill.Name = "ExtraPill"
						extraPill.Size = UDim2.new(0, 24, 0, 18)
						extraPill.Position = UDim2.new(0, 0, 0.5, 0)
						extraPill.AnchorPoint = Vector2.new(0, 0.5)
						extraPill.LayoutOrder = 10
						extraPill.BackgroundTransparency = 1
						extraPill.Font = Enum.Font.MontserratBold
						extraPill.TextSize = 10
						extraPill.TextColor3 = Color3.fromRGB(200, 205, 215)
						extraPill.Text = "+" .. tostring(extra)
						extraPill.Parent = avatarsContainer
					end
				end
			end

			-- Action Button Styling & Interaction
			if actionBtn then
				if sData.status == "PLAYING" or sData.isCurrent then
					actionBtn.BackgroundColor3 = Color3.fromRGB(38, 145, 75)
					actionBtn.Text = "PLAYING"
					actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				elseif sData.status == "FULL" then
					actionBtn.BackgroundColor3 = Color3.fromRGB(165, 40, 40)
					actionBtn.Text = "FULL"
					actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				else
					actionBtn.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
					actionBtn.Text = "JOIN"
					actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

					actionBtn.MouseEnter:Connect(function()
						actionBtn.BackgroundColor3 = Color3.fromRGB(48, 54, 65)
					end)
					actionBtn.MouseLeave:Connect(function()
						actionBtn.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
					end)

					actionBtn.MouseButton1Click:Connect(function()
						if isFetching then return end
						actionBtn.Text = "JOINING..."
						actionBtn.BackgroundColor3 = Color3.fromRGB(0, 132, 255)

						task.spawn(function()
							if teleportToServerRF then
								local ok, msg = teleportToServerRF:InvokeServer(sData.jobId)
								if not ok then
									actionBtn.Text = "JOIN"
									actionBtn.BackgroundColor3 = Color3.fromRGB(36, 40, 48)
									warn("[ServerList] Teleport failed:", msg)
								end
							end
						end)
					end)
				end
			end

			card.Parent = scrollContainer
			table.insert(spawnedCards, card)
		end
	end
end

-- ============================================================
-- FETCH SERVERS FROM BACKEND
-- ============================================================
function fetchAndRenderServers()
	if isFetching then return end
	isFetching = true

	-- Animate refresh button
	local rotationTween = TweenService:Create(refreshBtn, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Rotation = refreshBtn.Rotation + 360
	})
	rotationTween:Play()

	task.spawn(function()
		if getServerListRF then
			local ok, list = pcall(function()
				return getServerListRF:InvokeServer()
			end)
			if ok and type(list) == "table" then
				cachedServers = list
			end
		end

		renderServerCards(searchBox.Text)
		isFetching = false
	end)
end

-- Refresh Button Click
refreshBtn.MouseButton1Click:Connect(function()
	fetchAndRenderServers()
end)

-- Search Box Filtering (Realtime)
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	renderServerCards(searchBox.Text)
end)

-- Initial Load
task.defer(function()
	fetchAndRenderServers()
end)

return true
