--!strict
-- ============================================================
-- ANTI-AFK 24/7 SYSTEM (CLIENT)
-- ============================================================
-- Prevents Roblox 20-minute idle kicks so players can stay
-- in the map indefinitely (24/7 AFK).
-- ============================================================

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- Method 1: Intercept player.Idled signal
-- Fired by Roblox engine when user has been idle
player.Idled:Connect(function(timeIdled)
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.zero)
	end)
	pcall(function()
		VirtualUser:Button2Down(Vector2.zero)
		task.wait(0.1)
		VirtualUser:Button2Up(Vector2.zero)
	end)
	print(string.format("[AntiAFK] 🛡️ 20-minute idle kick prevented! (Inactivity reset after %s seconds)", tostring(math.floor(timeIdled or 0))))
end)

-- Method 2: Proactive keep-alive heartbeat every 10 minutes
-- Guarantees the engine idle counter is refreshed well before 20 minutes
task.spawn(function()
	while true do
		task.wait(600) -- every 10 minutes
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.zero)
		end)
	end
end)

print("[AntiAFK] ✅ 24/7 Anti-AFK system activated.")
