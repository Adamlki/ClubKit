local cam = workspace.CurrentCamera
local event = game.ReplicatedStorage:WaitForChild("SpeedCam", 5)
if not event then return end
local tween = game.TweenService

local normal = 70
local boosted = 95

local currentAnimVersion = 0

event.OnClientEvent:Connect(function()
	currentAnimVersion = currentAnimVersion + 1
	local version = currentAnimVersion

	local t1 = tween:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FieldOfView = boosted})
	t1:Play()
	
	-- 🔥 FIX: Jangan gunakan Wait() yang membuat script stuck.
	-- Gunakan delay dan pastikan animasinya tidak diganggu oleh boost baru.
	task.delay(0.25, function()
		if version == currentAnimVersion then
			local t2 = tween:Create(cam, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {FieldOfView = normal})
			t2:Play()
		end
	end)
end)
