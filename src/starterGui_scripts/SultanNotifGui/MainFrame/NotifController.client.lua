local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local frame = script.Parent
local avatarImg = frame:WaitForChild("Avatar")
local nameLbl = frame:WaitForChild("NameLabel")
local descLbl = frame:WaitForChild("DescLabel")
local stroke = frame:FindFirstChildOfClass("UIStroke")

local targets = {
	Frame = frame.BackgroundTransparency,
	Avatar = avatarImg.ImageTransparency,
	Name = nameLbl.TextTransparency,
	Desc = descLbl.TextTransparency,
	Stroke = stroke and stroke.Transparency or 0
}

frame.BackgroundTransparency = 1
avatarImg.ImageTransparency = 1
nameLbl.TextTransparency = 1
descLbl.TextTransparency = 1
if stroke then stroke.Transparency = 1 end
frame.Visible = false

local NotifEvent = ReplicatedStorage:WaitForChild("SultanJoinNotifEvent")
local isPlaying = false
local queue = {}
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function fade(isIn)
	local tweens = {}
	table.insert(tweens, TweenService:Create(frame, tweenInfo, {BackgroundTransparency = isIn and targets.Frame or 1}))
	table.insert(tweens, TweenService:Create(avatarImg, tweenInfo, {ImageTransparency = isIn and targets.Avatar or 1}))
	table.insert(tweens, TweenService:Create(nameLbl, tweenInfo, {TextTransparency = isIn and targets.Name or 1}))
	table.insert(tweens, TweenService:Create(descLbl, tweenInfo, {TextTransparency = isIn and targets.Desc or 1}))
	if stroke then
		table.insert(tweens, TweenService:Create(stroke, tweenInfo, {Transparency = isIn and targets.Stroke or 1}))
	end
	for _, t in ipairs(tweens) do t:Play() end
	return tweens[1] 
end

local function processQueue()
	if isPlaying then return end
	isPlaying = true

	while #queue > 0 do
		local data = table.remove(queue, 1)

		nameLbl.Text = data.PlayerName
		descLbl.Text = data.Message

		task.spawn(function()
			avatarImg.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
			local success, result = pcall(function()
				return Players:GetUserThumbnailAsync(data.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if success and result then avatarImg.Image = result end
		end)

		frame.Visible = true
		fade(true).Completed:Wait()
		task.wait(4)
		fade(false).Completed:Wait()
		frame.Visible = false
		task.wait(0.5)
	end
	isPlaying = false
end

NotifEvent.OnClientEvent:Connect(function(data)
	table.insert(queue, data)
	processQueue()
end)
