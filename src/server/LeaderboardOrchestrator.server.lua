--!native
--!optimize 2

local RunService = game:GetService("RunService")
local LeaderboardRegistry = require(script.Parent:WaitForChild("Modules"):WaitForChild("LeaderboardRegistry"))

local CONFIG = {
	DEBUG_ENABLED = false,
	STAGGERED_BOOT_INTERVAL = 8,
	ROUND_ROBIN_INTERVAL = 30,
}

local function debugPrint(...)
	if CONFIG.DEBUG_ENABLED or RunService:IsStudio() then
		print("[LeaderboardOrchestrator]", ...)
	end
end

local categories = {
	{
		name = "Robux Leaderboard (All-Time & Daily)",
		execute = function()
			local ok = LeaderboardRegistry.execute("Robux")
			if not ok then
				debugPrint("⚠️ Robux Leaderboard update handler belum siap.")
			end
		end
	},
	{
		name = "Saweria Leaderboard (Top Donators)",
		execute = function()
			local ok = LeaderboardRegistry.execute("Saweria")
			if not ok then
				debugPrint("⚠️ Saweria Leaderboard update handler belum siap.")
			end
		end
	},
	{
		name = "Likes Leaderboard (Total & Daily)",
		execute = function()
			local ok = LeaderboardRegistry.execute("Likes")
			if not ok then
				debugPrint("⚠️ Likes Leaderboard update handler belum siap.")
			end
		end
	},
	{
		name = "Levels Leaderboard (Top Exp/Level)",
		execute = function()
			local ok = LeaderboardRegistry.execute("Levels")
			if not ok then
				debugPrint("⚠️ Levels Leaderboard update handler belum siap.")
			end
		end
	},
}

task.spawn(function()
	debugPrint("🚀 Inisialisasi Round-Robin Leaderboard Orchestrator...")

	task.wait(3)
	for i, cat in ipairs(categories) do
		debugPrint(string.format("📌 [Boot %d/%d] Memuat %s...", i, #categories, cat.name))
		local ok, err = pcall(cat.execute)
		if not ok then
			warn("[LeaderboardOrchestrator] Error pada boot " .. cat.name .. ":", err)
		end
		task.wait(CONFIG.STAGGERED_BOOT_INTERVAL)
	end

	debugPrint("✅ Staggered Boot selesai! Memulai siklus Round-Robin (" .. CONFIG.ROUND_ROBIN_INTERVAL .. "s per kategori)...")

	local currentIndex = 1
	while true do
		task.wait(CONFIG.ROUND_ROBIN_INTERVAL)

		local cat = categories[currentIndex]
		debugPrint(string.format("🔄 [Round-Robin] Giliran update: %s", cat.name))

		local ok, err = pcall(cat.execute)
		if not ok then
			warn("[LeaderboardOrchestrator] Error saat update " .. cat.name .. ":", err)
		end

		currentIndex = currentIndex + 1
		if currentIndex > #categories then
			currentIndex = 1
		end
	end
end)
