local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

local ALLOW_IN_LIVE_SERVER = false
local CAN_RUN_BOTS = RunService:IsStudio() or ALLOW_IN_LIVE_SERVER

local AUTO_STOP_SECONDS = 300
local MAX_TOTAL_BOTS = 100

local stressGeneration = 0

local activeBots = {}
local isTesting = false
local isSyncing = false

local function getStressTestFolder()
	local folder = Workspace:FindFirstChild("StressTestBots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "StressTestBots"
		folder.Parent = Workspace
	end
	return folder
end

local dummyTemplate = nil

local function getDummyTemplate()
	if dummyTemplate then return dummyTemplate end
	local success, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(1)
	end)
	if success and model then
		dummyTemplate = model
		dummyTemplate.Name = "StressTestBot"
		for _, child in ipairs(dummyTemplate:GetDescendants()) do
			if child:IsA("Script") or child:IsA("LocalScript") then
				child:Destroy()
			end
		end
	end
	return dummyTemplate
end

local function stopBots()
	isTesting = false
	isSyncing = false
	stressGeneration += 1
	for _, bot in ipairs(activeBots) do
		if bot and bot.Parent then
			bot:Destroy()
		end
	end
	table.clear(activeBots)
	print("[StressTest] Seluruh bot telah dimusnahkan. Memori dibersihkan.")
end

local function spawnBots(amount, originPosition)
	if not CAN_RUN_BOTS then
		warn("[StressTest] Dinonaktifkan di live server. Stress test hanya bisa dijalankan di Roblox Studio.")
		return
	end

	local template = getDummyTemplate()
	if not template then
		warn("[StressTest] Dummy Template belum selesai loading, coba lagi dalam beberapa detik.")
		return
	end
	
	local remaining = MAX_TOTAL_BOTS - #activeBots
	if remaining <= 0 then
		warn("[StressTest] Batas maksimum", MAX_TOTAL_BOTS, "bot sudah tercapai. Jalankan /stopstress dulu.")
		return
	end
	if amount > remaining then
		amount = remaining
	end

	isTesting = true
	local radius = 40
	local folder = getStressTestFolder()
	
	for i = 1, amount do
		local bot = template:Clone()
		bot.Name = "Bot_" .. tostring(i)
		
		local randomOffset = Vector3.new(
			math.random(-radius, radius),
			15,
			math.random(-radius, radius)
		)
		bot:PivotTo(CFrame.new(originPosition + randomOffset))
		bot.Parent = folder
		
		table.insert(activeBots, bot)
		
		task.spawn(function()
			local humanoid = bot:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			
			while isTesting and bot.Parent do
				task.wait(math.random(1, 4))
				
				if not isSyncing and bot.PrimaryPart then
					local moveOffset = Vector3.new(
						math.random(-30, 30),
						0,
						math.random(-30, 30)
					)
					humanoid:MoveTo(bot.PrimaryPart.Position + moveOffset)
					
					if math.random(1, 4) == 1 then
						humanoid.Jump = true
					end
				end
			end
		end)
		
		if i % 5 == 0 then
			task.wait(0.1)
		end
	end
	
	stressGeneration += 1
	local generation = stressGeneration
	task.delay(AUTO_STOP_SECONDS, function()
		if generation == stressGeneration and isTesting then
			warn("[StressTest] Auto-stop:", AUTO_STOP_SECONDS, "detik tanpa spawn baru. Memusnahkan seluruh bot.")
			stopBots()
		end
	end)

	print("[StressTest] Berhasil memanggil", amount, "bot tempur ke medan perang!")
end

local function syncBotsToPlayer(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	
	local activeTrack = nil
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Priority ~= Enum.AnimationPriority.Core and track.Priority ~= Enum.AnimationPriority.Idle then
			activeTrack = track
			break
		end
	end
	
	if not activeTrack then
		print("[StressTest] Tidak ada tarian aktif yang terdeteksi di karaktermu!")
		return
	end
	
	isSyncing = true
	local animId = activeTrack.Animation.AnimationId
	print("[StressTest] Mensinkronkan", #activeBots, "bot ke animasi:", animId)
	
	for _, bot in ipairs(activeBots) do
		local botHum = bot:FindFirstChildOfClass("Humanoid")
		local botAnimator = botHum and botHum:FindFirstChildOfClass("Animator")
		
		if botHum and not botAnimator then
			botAnimator = Instance.new("Animator")
			botAnimator.Parent = botHum
		end
		
		if botAnimator then
			for _, t in ipairs(botAnimator:GetPlayingAnimationTracks()) do
				t:Stop()
			end
			
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local newTrack = botAnimator:LoadAnimation(anim)
			newTrack.Priority = activeTrack.Priority
			newTrack:Play()
			
			task.spawn(function()
				task.wait()
				newTrack.TimePosition = activeTrack.TimePosition
				newTrack:AdjustSpeed(activeTrack.Speed)
			end)
		end
	end
end

local function stopSyncBots()
	isSyncing = false
	for _, bot in ipairs(activeBots) do
		local botHum = bot:FindFirstChildOfClass("Humanoid")
		local botAnimator = botHum and botHum:FindFirstChildOfClass("Animator")
		if botAnimator then
			for _, t in ipairs(botAnimator:GetPlayingAnimationTracks()) do
				if t.Priority ~= Enum.AnimationPriority.Core and t.Priority ~= Enum.AnimationPriority.Idle then
					t:Stop()
				end
			end
		end
	end
	print("[StressTest] Sinkronisasi tarian bot dihentikan. Bot kembali bergerak liar.")
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local role = RoleSystem:GetPlayerRole(player)
		if role ~= "Owner" then return end
		
		local msgLower = string.lower(message)
		
		if string.sub(msgLower, 1, 11) == "/stresstest" then
			local amountStr = string.sub(msgLower, 13)
			local amount = tonumber(amountStr) or 50
			amount = math.clamp(amount, 1, 100)
			
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local origin = root and root.Position or Vector3.new(0, 50, 0)
			
			spawnBots(amount, origin)
			
		elseif msgLower == "/stopstress" then
			stopBots()
			
		elseif msgLower == "/stresssync" then
			syncBotsToPlayer(player)
			
		elseif msgLower == "/stopstresssync" then
			stopSyncBots()
		end
	end)
end)
