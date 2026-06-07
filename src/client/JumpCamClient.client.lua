local cam = workspace.CurrentCamera
local event = game.ReplicatedStorage:WaitForChild("TrampoCam")
local tween = game.TweenService

local normalFov = 70
local jumpFov = 100

event.OnClientEvent:Connect(function()
	local t1 = tween:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = jumpFov})
	local t2 = tween:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FieldOfView = normalFov})
	t1:Play()
	t1.Completed:Wait()
	t2:Play()
end)
