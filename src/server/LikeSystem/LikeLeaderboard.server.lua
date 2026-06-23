local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local Players = game:GetService("Players")

local ORDERED_DATASTORE_NAME = "PlayerLikes_Ordered_v1"
local MAX_PLAYERS = 30
local REFRESH_INTERVAL = 60

local OrderedLikesStore = DataStoreService:GetOrderedDataStore(ORDERED_DATASTORE_NAME)

-- Cache untuk DisplayName
local displayNameCache = {}

local function updateLeaderboardBoard()
	-- Cari GUI di workspace
	-- Sesuai gambar: workspace.JekyLikeBoard.JekyGui.MainFrame.Container
	local boardModel = workspace:FindFirstChild("JekyLikeBoard")
	if not boardModel then return false end
	
	-- Cari secara mendalam (recursive) untuk mengantisipasi letak JekyGui
	local jekyGui = boardModel:FindFirstChild("JekyGui", true)
	if not jekyGui then return false end
	
	local mainFrame = jekyGui:FindFirstChild("MainFrame")
	if not mainFrame then return false end
	
	local container = mainFrame:FindFirstChild("Container")
	if not container then return false end
	
	local scrollingContent = container:FindFirstChild("ScrollingContent")
	local templateFrame = scrollingContent and scrollingContent:FindFirstChild("TemplateFrame")
	
	if not scrollingContent or not templateFrame then return false end

	-- Tarik data dari OrderedDataStore
	local success, pages = pcall(function()
		return OrderedLikesStore:GetSortedAsync(false, MAX_PLAYERS)
	end)

	if not success or not pages then
		warn("[LikeLeaderboard] Gagal menarik data likes")
		return false
	end

	local pageSuccess, pageData = pcall(function() return pages:GetCurrentPage() end)
	if not pageSuccess or not pageData then return false end

	-- Sembunyikan template frame asli agar tidak ikut tampil sebagai baris kosong
	templateFrame.Visible = false

	-- Bersihkan list sebelumnya, kecuali template dan UIListLayout
	for _, child in ipairs(scrollingContent:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "TemplateFrame" then
			child:Destroy()
		end
	end

	-- Kumpulkan ID yang belum ada di cache untuk di-batch (mencegah limit API)
	local missingIds = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value
		if likes > 0 and not displayNameCache[userId] then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				displayNameCache[userId] = player.DisplayName
			else
				table.insert(missingIds, userId)
			end
		end
	end

	-- Request batch ke UserService jika ada ID yang missing
	if #missingIds > 0 then
		local success, info = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missingIds)
		end)
		if success and info then
			for _, userInfo in ipairs(info) do
				displayNameCache[userInfo.Id] = userInfo.DisplayName
			end
		end
	end

	local rank = 1
	local currentLikesData = {}
	for _, entry in ipairs(pageData) do
		local userId = tonumber(entry.key)
		local likes = entry.value

		-- Aturan: Jika like = 0, jangan ditampilin
		if likes > 0 then
			table.insert(currentLikesData, { UserId = userId, Rank = rank, Likes = likes })
			
			local dName = displayNameCache[userId] or ("Player_" .. tostring(userId))
			
			local newFrame = templateFrame:Clone()
			newFrame.Name = "Rank_" .. rank
			newFrame.Visible = true
			
			local rankLabel = newFrame:FindFirstChild("RankLabel")
			local nameLabel = newFrame:FindFirstChild("NameLabel")
			local likeLabel = newFrame:FindFirstChild("LikeLabel")
			
			if rankLabel then rankLabel.Text = "#" .. rank end
			if nameLabel then nameLabel.Text = dName end
			if likeLabel then likeLabel.Text = tostring(likes) end
			
			newFrame.Parent = scrollingContent
			rank = rank + 1
		end
	end

	_G.LikesLeaderboardData = currentLikesData

	return true
end

local function startLeaderboardLoop()
	-- Beri jeda 15 detik di awal agar tidak berbarengan/bentrok dengan Auto-Save LikeManager
	task.wait(15)
	
	-- Loop terus menerus
	while true do
		local success = updateLeaderboardBoard()
		
		-- Animasi Countdown di tulisan LoadingFrame (jika ada)
		local boardModel = workspace:FindFirstChild("JekyLikeBoard")
		if boardModel then
			local loadingText = boardModel:FindFirstChild("LoadingText", true)
			if loadingText then
				for i = REFRESH_INTERVAL, 1, -1 do
					loadingText.Text = "Refreshing in " .. i .. " Second" .. (i > 1 and "s" or "")
					task.wait(1)
				end
			else
				-- Jika ga ada LoadingText, tunggu saja
				task.wait(REFRESH_INTERVAL)
			end
		else
			task.wait(REFRESH_INTERVAL)
		end
	end
end

-- Jalankan di background thread
task.spawn(startLeaderboardLoop)
