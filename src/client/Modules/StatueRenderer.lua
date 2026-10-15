--!strict
-- ============================================================
-- StatueRenderer (ClubKit Client Module)
-- Unified podium avatar statue renderer for Top 3 Donators
-- (Supports Robux, Saweria, and any future leaderboards)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

export type StatueConfig = {
	categoryName: string,
	posPrefix: string,
	modelPrefix: string,
	remoteEventName: string,
	animations: { [string]: string },
	rankColors: { [number]: Color3 },
	formatValue: (amount: number | string) -> string,
}

local StatueRenderer = {}
StatueRenderer.__index = StatueRenderer

local function destroyStatue(statue: Instance?)
	if not statue then return end
	pcall(function()
		local animator = statue:FindFirstChildWhichIsA("Animator", true)
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop()
				track:Destroy()
			end
		end
		statue:Destroy()
	end)
end

function StatueRenderer.create(config: StatueConfig)
	local self = setmetatable({}, StatueRenderer)

	self.config = config
	self.activeStatues = {} :: { [number]: Model }
	self.activeUserIds = {} :: { [number]: number }
	self.currentRenderVersion = 0

	self:_initGuiTemplate()
	self:_connectRemote()

	return self
end

function StatueRenderer:_initGuiTemplate()
	self.template = ReplicatedStorage:WaitForChild("TamplateTopDonation", 10)
end

function StatueRenderer:_updateInfoGui(bgui: BillboardGui, rank: number, name: string, amount: any)
	local frame = bgui:FindFirstChild("MainFrame")
	if frame then
		local namaLabel = frame:FindFirstChild("PlayerName") :: TextLabel?
		local valueLabel = frame:FindFirstChild("Value") :: TextLabel?

		if namaLabel then
			namaLabel.Text = "#" .. rank .. " " .. name
			namaLabel.TextColor3 = self.config.rankColors[rank] or Color3.fromRGB(255, 255, 255)
		end

		if valueLabel then
			valueLabel.Text = self.config.formatValue(amount)
		end
	end
end

function StatueRenderer:_createInfoGui(parent: Instance?, rank: number, name: string, amount: any): BillboardGui?
	if not parent then return nil end
	local template = self.template or ReplicatedStorage:FindFirstChild("TamplateTopDonation")
	if not template or not template:IsA("BillboardGui") then
		warn(string.format("[%s Statue] BillboardGui TamplateTopDonation tidak ditemukan!", self.config.categoryName))
		return nil
	end

	local bgui = template:Clone()
	bgui.Enabled = true
	self:_updateInfoGui(bgui, rank, name, amount)
	bgui.Parent = parent
	return bgui
end

function StatueRenderer:_findPosPart(rank: number): BasePart?
	local targetName = self.config.posPrefix .. rank

	-- 1. Cari di DonatorPositions
	local folder = Workspace:FindFirstChild("DonatorPositions") or Workspace:FindFirstChild("DonatorPositions", true)
	if folder then
		local p = folder:FindFirstChild(targetName) or folder:FindFirstChild(targetName, true)
		if p and p:IsA("BasePart") then return p end
		local alts = {
			self.config.categoryName .. "_Pos" .. rank,
			self.config.categoryName .. "Pos" .. rank,
			"Pos_" .. self.config.categoryName .. rank,
			"Top" .. rank .. "_" .. self.config.categoryName,
		}
		for _, alt in ipairs(alts) do
			local altPart = folder:FindFirstChild(alt, true)
			if altPart and altPart:IsA("BasePart") then return altPart end
		end
	end

	-- 2. Cari di workspace secara rekursif
	local p = Workspace:FindFirstChild(targetName, true)
	if p and p:IsA("BasePart") then return p end

	return nil
end

function StatueRenderer:Update(rawTop3Data: any)
	local top3Data = if (type(rawTop3Data) == "table" and rawTop3Data.AllTime) then rawTop3Data.AllTime else rawTop3Data
	if not top3Data then return end

	self.currentRenderVersion += 1
	local myRenderVersion = self.currentRenderVersion

	local expectedCount = 0
	for rank = 1, 3 do
		if top3Data[rank] then expectedCount += 1 end
	end

	if expectedCount == 0 then
		for _, statue in pairs(self.activeStatues) do
			destroyStatue(statue)
		end
		table.clear(self.activeStatues)
		table.clear(self.activeUserIds)
		return
	end

	-- 1. Evaluasi cache untuk render ulang halus
	for rank = 1, 3 do
		local data = top3Data[rank]
		if data then
			local userId = data.userId or data.UserId or data.id or 1
			local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
			local amount = data.amount or data.Amount or data.jumlah or 0

			if userId == 1 and name ~= "Unknown" then
				pcall(function()
					userId = Players:GetUserIdFromNameAsync(name)
				end)
			end
			data.resolvedUserId = userId

			if self.activeUserIds[rank] == userId and self.activeStatues[rank] then
				-- Cache Hit: Perbarui UI saja
				local head = self.activeStatues[rank]:FindFirstChild("Head")
				if head then
					local oldGui = head:FindFirstChildOfClass("BillboardGui")
					if oldGui then
						self:_updateInfoGui(oldGui, rank, name, amount)
					else
						pcall(function() self:_createInfoGui(head, rank, name, amount) end)
					end
				end
			else
				-- Cache Miss: Bersihkan patung lama
				if self.activeStatues[rank] then
					destroyStatue(self.activeStatues[rank])
					self.activeStatues[rank] = nil
				end
				self.activeUserIds[rank] = nil
			end
		else
			if self.activeStatues[rank] then
				destroyStatue(self.activeStatues[rank])
				self.activeStatues[rank] = nil
			end
			self.activeUserIds[rank] = nil
		end
	end

	-- 2. Rakit avatar baru secara bertahap (Staggered loading)
	task.spawn(function()
		local universalStartTime = Workspace:GetServerTimeNow()
		for rank = 1, 3 do
			if self.currentRenderVersion ~= myRenderVersion then return end
			local data = top3Data[rank]

			if data and not self.activeStatues[rank] then
				local userId = data.resolvedUserId
				local name = data.name or data.DisplayName or data.Name or data.nama or data.donator or "Unknown"
				local amount = data.amount or data.Amount or data.jumlah or 0

				local posPart = self:_findPosPart(rank)
				if not posPart then
					local waitLimit = os.clock() + 5
					while not posPart and os.clock() < waitLimit do
						task.wait(0.5)
						posPart = self:_findPosPart(rank)
					end
				end

				if posPart then
					local success, model = pcall(function()
						return Players:CreateHumanoidModelFromUserId(userId)
					end)
					if not success or not model then
						pcall(function()
							model = Players:CreateHumanoidModelFromUserId(1)
						end)
					end

					if self.currentRenderVersion ~= myRenderVersion then
						if model then model:Destroy() end
						return
					end

					if model then
						local humanoid = model:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
						end

						for _, p in ipairs(model:GetDescendants()) do
							if p:IsA("BasePart") then p.CanCollide = false end
						end

						local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
						if hrp then hrp.Anchored = true end
						if hrp and not model.PrimaryPart then model.PrimaryPart = hrp end

						local hrpY = if hrp then hrp.Size.Y else 2
						local hipH = if humanoid then humanoid.HipHeight else 0
						local yOffset = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then (hipH + (hrpY / 2)) else 3

						pcall(function()
							if model.PrimaryPart then
								model:PivotTo(posPart.CFrame * CFrame.new(0, yOffset, 0))
							else
								model:MoveTo((posPart.CFrame * CFrame.new(0, yOffset, 0)).Position)
							end
						end)

						pcall(function()
							self:_createInfoGui(model:WaitForChild("Head", 5), rank, name, amount)
						end)

						local existingName = self.config.modelPrefix .. rank
						local existing = Workspace:FindFirstChild(existingName)
						if existing and existing ~= model then
							destroyStatue(existing)
						end

						model.Name = existingName
						model.Parent = Workspace
						self.activeStatues[rank] = model
						self.activeUserIds[rank] = userId

						local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
						if animator then
							local animId = self.config.animations["Top" .. rank]
							if animId and animId ~= "" then
								local anim = Instance.new("Animation")
								anim.AnimationId = animId
								local track = animator:LoadAnimation(anim)
								track.Looped = true
								track:Play(0.5)

								task.spawn(function()
									local waitTimeout = tick() + 2
									while track.Length == 0 and tick() < waitTimeout do task.wait() end
									if track.Length > 0 then
										local elapsed = Workspace:GetServerTimeNow() - universalStartTime
										track.TimePosition = elapsed % track.Length
									end
								end)
							end
						end
					end
				end

				task.wait(1.5)
			end
		end
	end)
end

function StatueRenderer:_connectRemote()
	local remote = ReplicatedStorage:WaitForChild(self.config.remoteEventName, 15)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(data)
			self:Update(data)
		end)

		-- Polling awal saat client load
		task.spawn(function()
			task.wait(1)
			remote:FireServer()
			for _ = 1, 4 do
				task.wait(5)
				local hasStatue = false
				for _ in pairs(self.activeStatues) do
					hasStatue = true
					break
				end
				if not hasStatue then
					remote:FireServer()
				else
					break
				end
			end
		end)
	end
end

return StatueRenderer
