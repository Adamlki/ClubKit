local cam = workspace.CurrentCamera
local event = game.ReplicatedStorage:WaitForChild("TrampoCam")
local tween = game.TweenService

local normalFov = 70
local jumpFov = 100

local currentAnimVersion = 0

event.OnClientEvent:Connect(function()
	currentAnimVersion = currentAnimVersion + 1
	local version = currentAnimVersion

	local t1 = tween:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = jumpFov})
	t1:Play()
	
	-- 🔥 FIX: Jangan gunakan Wait() yang membuat script stuck.
	-- Gunakan delay dan pastikan animasinya tidak diganggu oleh lompatan baru.
	task.delay(0.35, function()
		if version == currentAnimVersion then
			local t2 = tween:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FieldOfView = normalFov})
			t2:Play()
		end
	end)
end)
