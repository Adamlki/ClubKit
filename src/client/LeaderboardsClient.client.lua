local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Sembunyikan Template Secara Proaktif Agar Tidak Muncul (sultan_id) Saat Loading
task.spawn(function()
	local function hideTemplate(boardName, guiName)
		local board = workspace:FindFirstChild(boardName)
		if board then
			local gui = board:FindFirstChild(guiName)
			if gui then
				local mainFrame = gui:FindFirstChild("MainFrame")
				if mainFrame then
					local container = mainFrame:FindFirstChild("Container")
					if container then
						local content = container:FindFirstChild("ScrollingContent") or container:FindFirstChild("MainContent")
						if content then
							local template = content:FindFirstChild("TemplateFrame")
							if template then template.Visible = false end
						end
						local loading = container:FindFirstChild("LoadingFrame")
						if loading then loading.Visible = true end
					end
				end
			end
		end
	end
	hideTemplate("EldetoDonationBoard", "EldetoGui")
	hideTemplate("LikeBoard", "LikeGui")
end)

-- Pastikan kita punya remote
local updateTopBoardRemote = ReplicatedStorage:WaitForChild("UpdateTopBoard", 10)
local updateLikeBoardRemote = ReplicatedStorage:WaitForChild("UpdateLikeBoard", 10)

if updateTopBoardRemote then updateTopBoardRemote:FireServer() end
if updateLikeBoardRemote then updateLikeBoardRemote:FireServer() end

-- Helper Format Angka
local function formatNumber(num)
	if num >= 1_000_000 then
		return string.format("%.1fM", num / 1_000_000)
	elseif num >= 1_000 then
		return string.format("%.1fK", num / 1_000)
	else
		return tostring(num)
	end
end

-- ============================================
-- DONATION LEADERBOARD (ELDETO BOARD)
-- ============================================
if updateTopBoardRemote then
	updateTopBoardRemote.OnClientEvent:Connect(function(donors)
		local board = workspace:FindFirstChild("EldetoDonationBoard")
		if not board then return end
		local gui = board:FindFirstChild("EldetoGui")
		if not gui then return end
		
		local mainFrame = gui:FindFirstChild("MainFrame")
		if not mainFrame then return end
		local container = mainFrame:FindFirstChild("Container")
		if not container then return end
		
		local scrollingFrame = container:FindFirstChild("ScrollingContent")
		local templateFrame = scrollingFrame and scrollingFrame:FindFirstChild("TemplateFrame")
		local loadingFrame = container:FindFirstChild("LoadingFrame")
		
		if not scrollingFrame or not templateFrame then return end
		
		if loadingFrame then loadingFrame.Visible = false end
		scrollingFrame.Visible = true
		templateFrame.Visible = false
		
		-- Ambil semua entry yang sudah ada sebelumnya (Pool)
		local pool = {}
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("Frame") and child ~= templateFrame then
				table.insert(pool, child)
			end
		end
		
		-- Buat (Clone) baris UI kosong di awal hingga mencapai 50 (Object Pooling)
		for i = #pool + 1, 50 do
			local entry = templateFrame:Clone()
			entry.Name = "Entry_" .. i
			entry.Visible = false
			entry.Parent = scrollingFrame
			table.insert(pool, entry)
		end
		
		-- Render list baru dengan menggunakan UI dari pool
		for i, donor in ipairs(donors) do
			local entry = pool[i]
			
			-- Jika jumlah data melebihi 50, kita clone tambahan secara dinamis
			if not entry then
				entry = templateFrame:Clone()
				entry.Name = "Entry_" .. i
				entry.Parent = scrollingFrame
				table.insert(pool, entry)
			end
			
			entry.Visible = true
			entry.LayoutOrder = i
			
			local rankLabel = entry:FindFirstChild("RankLabel")
			if rankLabel then rankLabel.Text = "#" .. donor.Rank end
			
			local nameLabel = entry:FindFirstChild("NameLabel")
			if nameLabel then nameLabel.Text = donor.DisplayName end
			
			local amountLabel = entry:FindFirstChild("AmountLabel")
			if amountLabel then amountLabel.Text = formatNumber(donor.Amount) .. " Rbx" end
		end
		
		-- Sembunyikan baris UI yang tidak terpakai
		for i = #donors + 1, #pool do
			pool[i].Visible = false
		end
		
		-- Update Canvas Size
		local layout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
		if layout then
			scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
		end
	end)
end

-- ============================================
-- LIKE LEADERBOARD (JEKY BOARD)
-- ============================================
if updateLikeBoardRemote then
	updateLikeBoardRemote.OnClientEvent:Connect(function(donors)
		local boardModel = workspace:FindFirstChild("JekyLikeBoard")
		if not boardModel then return end
		
		local jekyGui = boardModel:FindFirstChild("JekyGui", true)
		if not jekyGui then return end
		
		local mainFrame = jekyGui:FindFirstChild("MainFrame")
		if not mainFrame then return end
		
		local container = mainFrame:FindFirstChild("Container")
		if not container then return end
		
		local scrollingContent = container:FindFirstChild("ScrollingContent")
		local templateFrame = scrollingContent and scrollingContent:FindFirstChild("TemplateFrame")
		local loadingText = boardModel:FindFirstChild("LoadingText", true)
		
		if not scrollingContent or not templateFrame then return end
		
		templateFrame.Visible = false
		if loadingText and loadingText.Parent then
			loadingText.Parent.Visible = false
		end
		
		-- Ambil semua entry yang sudah ada sebelumnya (Pool)
		local pool = {}
		for _, child in ipairs(scrollingContent:GetChildren()) do
			if child:IsA("Frame") and child ~= templateFrame then
				table.insert(pool, child)
			end
		end
		
		-- Buat (Clone) baris UI kosong di awal hingga mencapai 50 (Object Pooling)
		for i = #pool + 1, 50 do
			local newFrame = templateFrame:Clone()
			newFrame.Name = "Rank_" .. i
			newFrame.Visible = false
			newFrame.Parent = scrollingContent
			table.insert(pool, newFrame)
		end
		
		-- Render list baru dengan menggunakan UI dari pool
		for i, donor in ipairs(donors) do
			local newFrame = pool[i]
			
			-- Jika jumlah data melebihi 50, kita clone tambahan secara dinamis
			if not newFrame then
				newFrame = templateFrame:Clone()
				newFrame.Name = "Rank_" .. i
				newFrame.Parent = scrollingContent
				table.insert(pool, newFrame)
			end
			
			newFrame.Visible = true
			newFrame.LayoutOrder = i
			
			local rankLabel = newFrame:FindFirstChild("RankLabel")
			local nameLabel = newFrame:FindFirstChild("NameLabel")
			local likeLabel = newFrame:FindFirstChild("LikeLabel")
			
			if rankLabel then rankLabel.Text = "#" .. donor.Rank end
			if nameLabel then nameLabel.Text = donor.DisplayName end
			if likeLabel then likeLabel.Text = tostring(donor.Likes) end
		end
		
		-- Sembunyikan baris UI yang tidak terpakai
		for i = #donors + 1, #pool do
			pool[i].Visible = false
		end
		
		-- Update Canvas Size
		local layout = scrollingContent:FindFirstChildOfClass("UIListLayout")
		if layout then
			scrollingContent.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
		end
	end)
end
