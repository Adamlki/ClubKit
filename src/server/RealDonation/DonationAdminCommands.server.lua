local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local FormatUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("FormatUtils"))
local ServerConfig = require(ServerScriptService:WaitForChild("Config"):WaitForChild("ServerConfig"))
local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))
local DebugHooks = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DebugHooks"))
local MegaEffectsConfig = require(ServerScriptService:WaitForChild("EffectDonationSaweria"):WaitForChild("MegaEffectsConfig"))
local EffectService = require(ServerStorage:WaitForChild("Modules"):WaitForChild("EffectService"))

local CONFIG = {
	COIN_PREFIX = "/coin",
	SAWERIA_PREFIX = "/saweria",
	REQUIRED_ROLE = "Owner",
	DEBUG_MODE = false,
}

local showDonationNotif = ReplicatedStorage:WaitForChild("EffectsRemotes"):WaitForChild("ShowDonationNotif")

local lastSaweriaTime = {}
local lastCoinTime = {}
local lastStageTime = {}

local function debugPrint(...)
	if CONFIG.DEBUG_MODE then
		print("[ADMIN CMD]", ...)
	end
end

local function isOwner(player)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then 
		return false 
	end
	if RunService:IsStudio() or ServerConfig.IsOwner(player.UserId) then 
		return true 
	end

	local okRole, role = pcall(function() return RoleSystem:GetPlayerRole(player) end)
	if okRole and role == CONFIG.REQUIRED_ROLE then 
		return true 
	end

	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	elseif game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local okRank, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if okRank and rank == 255 then return true end
	end

	return false
end

local function hasStaffPermission(player)
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then 
		return false 
	end
	if RunService:IsStudio() or ServerConfig.IsOwner(player.UserId) then 
		return true 
	end
	for _, adminId in ipairs(ServerConfig.AdminIds) do
		if player.UserId == adminId then return true end
	end

	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	elseif game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local okRank, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if okRank and rank >= 250 then return true end
	end

	local okRole, role = pcall(function() return RoleSystem:GetPlayerRole(player) end)
	if okRole and (role == "Owner" or role == "Admin" or role == "Moderator") then 
		return true 
	end

	local roleVal = player:FindFirstChild("Role")
	if roleVal and (roleVal.Value == "Owner" or roleVal.Value == "Admin" or roleVal.Value == "Moderator") then
		return true
	end

	return false
end

local function sendFeedback(player, title, text)
	pcall(function()
		local customTeamsRemotes = ReplicatedStorage:FindFirstChild("CustomTeamsRemotes")
		local notifyRemote = customTeamsRemotes and customTeamsRemotes:FindFirstChild("Notify")
		if notifyRemote and player then
			notifyRemote:FireClient(player, {
				Title = title or "Saweria Test",
				Text = text or "",
				Duration = 6,
			})
		end
	end)
end

local function handleCoinCommand(player, args)
	if not isOwner(player) then
		debugPrint(player.Name, "bukan Owner, command /coin ditolak!")
		return
	end

	local now = os.clock()
	if lastCoinTime[player.UserId] and (now - lastCoinTime[player.UserId]) < 1.5 then return end
	lastCoinTime[player.UserId] = now

	if #args < 2 then
		print("Penggunaan: /coin <amount> <nama> [pesan]\nContoh: /coin 400 " .. player.Name .. " Semangat!\nTier Efek Robux:\n• 400 - 799: Nuke (Roket Nuklir)\n• 800 - 1999: Palu Raksasa & Clone Avatar (Smite)\n• 2000 - 3999: Black Hole Kosmik\n• >= 4000: Starfall (Winged Giant)")
		sendFeedback(player, "Coin Test", "Gunakan: /coin <amount> <nama> (400: Nuke, 800: Palu, 2k: BlackHole, 4k: Starfall)")
		return
	end

	local amount = tonumber(args[1])
	if not amount or amount <= 0 then
		print("ERROR: Amount harus angka positif, dapat:", args[1])
		return
	end

	local donatorName = args[2]
	local message = #args > 2 and table.concat(args, " ", 3) or ""

	debugPrint("Test coin donation:", donatorName, amount, message)

	if DebugHooks.Has("TriggerTestDonation") then
		DebugHooks.Call("TriggerTestDonation", donatorName, amount, message)
		local extraInfo = ""
		if amount >= 4000 then
			extraInfo = " ✨⭐ (Efek Starfall Winged Giant)"
		elseif amount >= 2000 then
			extraInfo = " 🕳️🌌 (Efek Black Hole Kosmik)"
		elseif amount >= 800 then
			extraInfo = " ⚡🔨 (Efek Palu Raksasa & Ava Clone)"
		elseif amount >= 400 then
			extraInfo = " 🚀💥 (Efek Nuke Nuklir)"
		end
		sendFeedback(player, "Coin Test", "Memicu Robux donate: " .. donatorName .. " R$" .. tostring(amount) .. extraInfo)
	else
		warn("[ADMIN CMD] DebugHooks TriggerTestDonation belum ada. Mengirim notif saja.")
		pcall(function()
			showDonationNotif:FireAllClients({
				donator = donatorName,
				amount = amount,
				message = message,
			})
		end)
	end
end

local function handleSaweriaCommand(player, args)
	if not isOwner(player) then
		debugPrint(player.Name, "bukan Owner, command /saweria ditolak!")
		return
	end

	local now = os.clock()
	if lastSaweriaTime[player.UserId] and (now - lastSaweriaTime[player.UserId]) < 1.5 then
		debugPrint("[ADMIN CMD] /saweria diabaikan untuk mencegah eksekusi ganda.")
		return
	end
	lastSaweriaTime[player.UserId] = now

	if #args < 1 then
		print("Format: /saweria <username> <nominal> [pesan]\nContoh: /saweria " .. player.Name .. " 50000 Semangat terus bang!\n\nTier Efek:\n• < 10k: Banner UI saja\n• 10k - 49k: Nuke\n• 50k - 199k: Giant Hammer (Smite)\n• 200k - 499k: Black Hole\n• >= 500k: Starfall")
		sendFeedback(player, "Saweria Test Help", "Gunakan: /saweria <username> <nominal> [pesan]")
		return
	end

	local donatorName = player.DisplayName or player.Name
	local amount = 50000
	local messageStartIndex = 2

	local arg1Num = tonumber((tostring(args[1]):gsub("[^%d]", "")))
	local arg2Num = args[2] and tonumber((tostring(args[2]):gsub("[^%d]", "")))

	if arg1Num and not arg2Num then
		amount = arg1Num
		donatorName = args[2] or donatorName
		messageStartIndex = args[2] and 3 or 2
	elseif arg2Num then
		donatorName = args[1]
		amount = arg2Num
		messageStartIndex = 3
	else
		donatorName = args[1]
		amount = 50000
		messageStartIndex = 2
	end

	local message = #args >= messageStartIndex and table.concat(args, " ", messageStartIndex) or "Tes fake donation Saweria!"

	if DebugHooks.Has("TestSaweria") then
		DebugHooks.Call("TestSaweria", donatorName, amount, message)
		local formattedRp = FormatUtils.formatNumber(amount, ".")
		sendFeedback(player, "🧪 Fake Donate Sukses", string.format("%s • Rp %s\nPesan: '%s'", donatorName, formattedRp, message))
		print(string.format("[ADMIN CMD] 🧪 Fake Saweria dipicu: %s | Rp %d | '%s'", donatorName, amount, message))
	else
		warn("[ADMIN CMD] DebugHooks TestSaweria belum terdaftar!")
		sendFeedback(player, "Saweria Error", "Sistem DonasiSaweria belum siap/load!")
	end
end

local function handleStageCommand(player, args)
	if not hasStaffPermission(player) then
		debugPrint(player.Name, "bukan Owner/Admin, command /stage ditolak!")
		sendFeedback(player, "Akses Ditolak", "Perintah /stage hanya untuk Owner & jajaran Admin!")
		return
	end

	local now = os.clock()
	if lastStageTime[player.UserId] and (now - lastStageTime[player.UserId]) < 1.0 then return end
	lastStageTime[player.UserId] = now

	local subCmd = args[1] and string.lower(args[1])
	if subCmd == "off" or subCmd == "stop" then
		if EffectService.Has("StopStageEffects") then
			EffectService.Call("StopStageEffects")
		else
			local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
			if stageEffectsFolder then
				for _, fx in ipairs(stageEffectsFolder:GetDescendants()) do
					if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
						fx.Enabled = false
					end
				end
			end
		end
		sendFeedback(player, "Stage Effects", "Stage effects dimatikan.")
		return
	end

	local durationOk, durationValue = EffectService.Call("GetStageFXDuration")
	local defaultDuration = (durationOk and tonumber(durationValue)) or 15
	local customSeconds = tonumber(args[1])
	local duration = customSeconds and math.clamp(customSeconds, 1, 60) or defaultDuration

	local firingOk, firingValue = EffectService.Call("IsStageFiring")
	if firingOk and firingValue then
		sendFeedback(player, "Stage Effects", "Stage effects saat ini sudah aktif menyala!")
		return
	end

	if EffectService.Has("TriggerStageEffects") then
		EffectService.Call("TriggerStageEffects", duration)
	else
		task.spawn(function()
			local stageEffectsFolder = Workspace:FindFirstChild("StageEffects")
			if not stageEffectsFolder then return end

			for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
				if stageFX:IsA("BasePart") then
					local sound = stageFX:FindFirstChild("HissSound")
					if sound then sound:Play() end
					for _, fx in ipairs(stageFX:GetChildren()) do
						if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
							fx.Enabled = true
						end
					end
				end
			end

			task.wait(duration)

			for _, stageFX in ipairs(stageEffectsFolder:GetChildren()) do
				if stageFX:IsA("BasePart") then
					for _, fx in ipairs(stageFX:GetChildren()) do
						if fx:IsA("ParticleEmitter") or fx:IsA("Smoke") then
							fx.Enabled = false
						end
					end
				end
			end
		end)
	end

	sendFeedback(player, "Stage Effects", string.format("Stage effects aktif selama %d detik!", duration))
	print(string.format("[ADMIN CMD] Stage effects dinyalakan oleh %s selama %d detik", player.Name, duration))
end

local EFFECT_TARGET_MAP = {
	global = { key = "GLOBAL_ENABLED", label = "Global Mega Effects" },
	all = { key = "GLOBAL_ENABLED", label = "Global Mega Effects" },
	robux = { key = "ROBUX_ENABLED", label = "Robux Mega Effects" },
	saweria = { key = "SAWERIA_ENABLED", label = "Saweria Mega Effects" },
	nuke = { sub = "Nuke", label = "Nuke Effect" },
	smite = { sub = "Smite", label = "Smite (Palu & Ava Clone)" },
	hammer = { sub = "Smite", label = "Smite (Palu & Ava Clone)" },
	palu = { sub = "Smite", label = "Smite (Palu & Ava Clone)" },
	blackhole = { sub = "BlackHole", label = "BlackHole Effect" },
	hole = { sub = "BlackHole", label = "BlackHole Effect" },
	starfall = { sub = "Starfall", label = "Starfall Effect" },
	star = { sub = "Starfall", label = "Starfall Effect" },
}

local function handleEffectsCommand(player, args)
	if not isOwner(player) then
		debugPrint(player.Name, "bukan Owner, command /effects ditolak!")
		return
	end

	local cfg = MegaEffectsConfig

	if not cfg then
		sendFeedback(player, "Effects Config", "ERROR: MegaEffectsConfig tidak ditemukan!")
		return
	end

	if #args == 0 or args[1]:lower() == "status" then
		local msg = string.format("STATUS EFEK:\n• Global: %s\n• Robux: %s | Saweria: %s\n• Nuke: %s | Smite: %s | BlackHole: %s | Starfall: %s",
			cfg.GLOBAL_ENABLED and "ON" or "OFF",
			cfg.ROBUX_ENABLED and "ON" or "OFF",
			cfg.SAWERIA_ENABLED and "ON" or "OFF",
			cfg.EFFECTS_ENABLED.Nuke and "ON" or "OFF",
			cfg.EFFECTS_ENABLED.Smite and "ON" or "OFF",
			cfg.EFFECTS_ENABLED.BlackHole and "ON" or "OFF",
			cfg.EFFECTS_ENABLED.Starfall and "ON" or "OFF"
		)
		print(msg)
		sendFeedback(player, "Effects Config", "Format: /effects <nama/all> <on/off>. Cek console F9!")
		return
	end

	local target = args[1]:lower()
	local info = EFFECT_TARGET_MAP[target]
	if not info then
		sendFeedback(player, "Effects Config", "Target: global, robux, saweria, nuke, smite, blackhole, starfall")
		return
	end

	local stateStr = args[2] and args[2]:lower() or ""
	local currentVal = if info.sub then cfg.EFFECTS_ENABLED[info.sub] else cfg[info.key]
	local newState = if stateStr == "" then not currentVal else (stateStr == "on" or stateStr == "true" or stateStr == "1" or stateStr == "enable")

	if info.sub then
		cfg.EFFECTS_ENABLED[info.sub] = newState
	else
		cfg[info.key] = newState
	end

	local textOut = string.format("%s: %s", info.label, newState and "ON ✅" or "OFF ❌")
	print("[ADMIN CMD]", textOut)
	sendFeedback(player, "Effects Config", textOut)
end

local COMMAND_REGISTRY = {
	{
		name = "SaweriaTestCommand",
		primary = "/saweria",
		secondary = "/testsaweria",
		aliases = { ["/saweria"] = true, ["/testsaweria"] = true },
		handler = handleSaweriaCommand,
	},
	{
		name = "CoinTestCommand",
		primary = CONFIG.COIN_PREFIX,
		aliases = { [CONFIG.COIN_PREFIX:lower()] = true },
		handler = handleCoinCommand,
	},
	{
		name = "StageTestCommand",
		primary = "/stage",
		secondary = "/stagefx",
		aliases = { ["/stage"] = true, ["/stagefx"] = true },
		handler = handleStageCommand,
	},
	{
		name = "EffectsToggleCommand",
		primary = "/effects",
		secondary = "/fx",
		aliases = { ["/effects"] = true, ["/fx"] = true },
		handler = handleEffectsCommand,
	},
}

task.spawn(function()
	local ok, tcCommands = pcall(function()
		local folder = TextChatService:FindFirstChild("TextChatCommands")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "TextChatCommands"
			folder.Parent = TextChatService
		end
		return folder
	end)

	if ok and tcCommands then
		for _, cmdDef in ipairs(COMMAND_REGISTRY) do
			local cmd = tcCommands:FindFirstChild(cmdDef.name)
			if not cmd then
				cmd = Instance.new("TextChatCommand")
				cmd.Name = cmdDef.name
				cmd.PrimaryAlias = cmdDef.primary
				if cmdDef.secondary then
					cmd.SecondaryAlias = cmdDef.secondary
				end
				cmd.Parent = tcCommands

				cmd.Triggered:Connect(function(textSource, rawText)
					local triggeringPlayer = Players:GetPlayerByUserId(textSource.UserId)
					if not triggeringPlayer then return end

					local args = {}
					for word in rawText:gmatch("%S+") do
						table.insert(args, word)
					end
					table.remove(args, 1)
					cmdDef.handler(triggeringPlayer, args)
				end)
			end
		end
		debugPrint("TextChatCommands berhasil didaftarkan di TextChatService")
	end
end)

local function onPlayerChatted(player, message)
	if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		return
	end

	local words = {}
	for word in message:gmatch("%S+") do
		table.insert(words, word)
	end
	if #words == 0 then return end

	local firstWord = words[1]:lower()
	for _, cmdDef in ipairs(COMMAND_REGISTRY) do
		if cmdDef.aliases[firstWord] then
			table.remove(words, 1)
			cmdDef.handler(player, words)
			return
		end
	end
end

local function setupPlayer(player)
	player.Chatted:Connect(function(msg)
		onPlayerChatted(player, msg)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	lastSaweriaTime[player.UserId] = nil
	lastCoinTime[player.UserId] = nil
	lastStageTime[player.UserId] = nil
end)

local function testCoin(amount, donatorName, message)
	amount = tonumber(amount)
	if not amount or amount <= 0 then
		print("Usage: DebugHooks.Call('TestCoin', amount, 'NamaDonatur', 'pesan opsional')")
		print("Contoh: DebugHooks.Call('TestCoin', 250000, 'Budi', 'UFO test!')")
		return
	end
	donatorName = donatorName or "TestDonor"
	message = message or ""

	if DebugHooks.Has("TriggerTestDonation") then
		DebugHooks.Call("TriggerTestDonation", donatorName, amount, message)
		print("[TEST] Fired Robux Donation:", donatorName, amount, message)
	else
		warn("[TEST] DebugHooks TriggerTestDonation tidak ditemukan!")
	end
end

local function testStage(duration)
	if EffectService.Has("TriggerStageEffects") then
		EffectService.Call("TriggerStageEffects", duration)
		print("[TEST] Fired Stage Effects for", duration or 15, "seconds")
	else
		warn("[TEST] EffectService TriggerStageEffects tidak ditemukan!")
	end
end

DebugHooks.Register("TestCoin", testCoin)
DebugHooks.Register("TestStage", testStage)

debugPrint("DonationAdminCommands siap: /saweria, /coin, & /stage aktif untuk Owner & Admin")
