local BoardRenderer = {}
BoardRenderer.__index = BoardRenderer

function BoardRenderer.new(boardModel)
	local self = setmetatable({}, BoardRenderer)

	self.gui = boardModel:WaitForChild("EldetoGui", 5)
	if not self.gui then
		warn("[Renderer] EldetoGui tidak ditemukan di board model!")
		return nil
	end

	self.mainFrame     = self.gui:WaitForChild("MainFrame",      5)
	self.container     = self.mainFrame:WaitForChild("Container", 5)
	self.loadingFrame  = self.container:WaitForChild("LoadingFrame",    5)
	self.loadingText   = self.loadingFrame:WaitForChild("LoadingText",  5)
	self.scrollingFrame = self.container:WaitForChild("ScrollingContent", 5)
	self.templateFrame = self.scrollingFrame:WaitForChild("TemplateFrame", 5)

	-- Sembunyikan template agar tidak ikut ditampilkan
	self.templateFrame.Visible = false

	return self
end

-- ============================================
-- INTERNAL
-- ============================================

function BoardRenderer:Clear()
	for _, child in ipairs(self.scrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= self.templateFrame then
			child:Destroy()
		end
	end
end

function BoardRenderer:UpdateCanvasSize()
	local layout = self.scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		self.scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
	end
end

-- ============================================
-- LOADING / COUNTDOWN / HIDE
-- ============================================

function BoardRenderer:ShowLoading(text)
	self.loadingFrame.Visible   = true
	self.scrollingFrame.Visible = false
	self.loadingText.Text       = text or "Loading..."
end

--[[
    ShowCountdown: tampilkan sisa waktu refresh
    tanpa menyembunyikan leaderboard di belakangnya.
]]
function BoardRenderer:ShowCountdown(seconds)
	self.loadingFrame.Visible   = true
	self.scrollingFrame.Visible = true
	self.loadingText.Text       = "Refreshing in " .. seconds .. " Seconds"
end

function BoardRenderer:HideLoading()
	self.loadingFrame.Visible   = false
	self.scrollingFrame.Visible = true
end

-- ============================================
-- RENDER
-- ============================================

function BoardRenderer:Render(donors)
	self:Clear()

	if not donors or #donors == 0 then
		self:ShowEmpty()
		return
	end

	for _, donor in ipairs(donors) do
		local entry = self.templateFrame:Clone()
		entry.Name    = "Entry_" .. donor.Rank
		entry.Visible = true

		local rankLabel = entry:FindFirstChild("RankLabel")
		if rankLabel then
			rankLabel.Text = "#" .. donor.Rank
		end

		local nameLabel = entry:FindFirstChild("NameLabel")
		if nameLabel then
			nameLabel.Text = donor.DisplayName
		end

		local amountLabel = entry:FindFirstChild("AmountLabel")
		if amountLabel then
			amountLabel.Text = self:FormatNumber(donor.Amount) .. " Rbx"
		end

		entry.Parent = self.scrollingFrame
	end

	self:UpdateCanvasSize()
	self:HideLoading()
end

function BoardRenderer:ShowEmpty()
	self:Clear()

	-- Hapus label lama jika ada
	local existing = self.scrollingFrame:FindFirstChild("EmptyState")
	if existing then existing:Destroy() end

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name                = "EmptyState"
	emptyLabel.Size                = UDim2.new(1, 0, 1, 0)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text                = "No donations yet"
	emptyLabel.TextSize            = 24
	emptyLabel.TextColor3          = Color3.new(1, 1, 1)
	emptyLabel.TextTransparency    = 0.5
	emptyLabel.Font                = Enum.Font.GothamBold
	emptyLabel.Parent              = self.scrollingFrame

	self:HideLoading()
end

-- ============================================
-- UTILITY
-- ============================================

function BoardRenderer:FormatNumber(num)
	if num >= 1_000_000 then
		return string.format("%.1fM", num / 1_000_000)
	elseif num >= 1_000 then
		return string.format("%.1fK", num / 1_000)
	else
		return tostring(num)
	end
end

return BoardRenderer