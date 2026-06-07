local cam = workspace.CurrentCamera
local event = game.ReplicatedStorage:WaitForChild("SpeedCam")
local tween = game.TweenService

local normal = 70
local boosted = 95

event.OnClientEvent:Connect(function()
	local t1 = tween:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = boosted})
	local t2 = tween:Create(cam, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FieldOfView = normal})
	t1:Play()
	t1.Completed:Wait()
	t2:Play()
end)
