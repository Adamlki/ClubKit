local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RoleSystem = require(ServerStorage:WaitForChild("Modules"):WaitForChild("RoleSystem"))

-- Container for bots
local stressTestFolder = Workspace:FindFirstChild("StressTestBots")
if not stressTestFolder then
	stressTestFolder = Instance.new("Folder")
	stressTestFolder.Name = "StressTestBots"
	stressTestFolder.Parent = Workspace
end

local activeBots = {}
local isTesting = false
local isSyncing = false

-- Generate Template Dummy (Yields di background)
local dummyTemplate = nil
task.spawn(function()
	local success, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(1) -- Default Roblox User (Roblox)
	end)
	if success and model then
		dummyTemplate = model
		dummyTemplate.Name = "StressTestBot"
		
		-- Bersihkan script internal dari model agar tidak membocorkan memori
		for _, child in ipairs(dummyTemplate:GetDescendants()) do
			if child:IsA("Script") or child:IsA("LocalScript") then
				child:Destroy()
			end
		end
	end
end)

local function spawnBots(amount, originPosition)
	if not dummyTemplate then
		warn("[StressTest] Dummy Template belum selesai loading, coba lagi dalam beberapa detik.")
		return
	end
	
	isTesting = true
	local radius = 40
	
	for i = 1, amount do
		local bot = dummyTemplate:Clone()
		bot.Name = "Bot_" .. tostring(i)
		
		-- Posisi spawn acak di sekitar origin
		local randomOffset = Vector3.new(
			math.random(-radius, radius),
			15,
			math.random(-radius, radius)
		)
		bot:PivotTo(CFrame.new(originPosition + randomOffset))
		bot.Parent = stressTestFolder
		
		table.insert(activeBots, bot)
		
		-- AI Loop untuk setiap Bot
		task.spawn(function()
			local humanoid = bot:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end
			
			while isTesting and bot.Parent do
				task.wait(math.random(1, 4))
				
				if not isSyncing and bot.PrimaryPart then
					-- Bergerak liar ke arah acak
					local moveOffset = Vector3.new(
						math.random(-30, 30),
						0,
						math.random(-30, 30)
					)
					humanoid:MoveTo(bot.PrimaryPart.Position + moveOffset)
					
					-- Sesekali lompat untuk stress test physics
					if math.random(1, 4) == 1 then
						humanoid.Jump = true
					end
				end
			end
		end)
		
		-- Beri jeda kecil setiap 5 bot agar server tidak Freeze mendadak
		if i % 5 == 0 then
			task.wait(0.1)
		end
	end
	
	print("[StressTest] Berhasil memanggil", amount, "bot tempur ke medan perang!")
end

local function stopBots()
	isTesting = false
	isSyncing = false
	for _, bot in ipairs(activeBots) do
		if bot and bot.Parent then
			bot:Destroy()
		end
	end
	table.clear(activeBots)
	print("[StressTest] Seluruh bot telah dimusnahkan. Memori dibersihkan.")
end

local function syncBotsToPlayer(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	
	-- Cari animasi yang sedang dimainkan player (hindari animasi jalan/diam bawaan)
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
		
		-- Buat Animator jika bot belum punya
		if botHum and not botAnimator then
			botAnimator = Instance.new("Animator")
			botAnimator.Parent = botHum
		end
		
		if botAnimator then
			-- Hentikan animasi bot yang lama
			for _, t in ipairs(botAnimator:GetPlayingAnimationTracks()) do
				t:Stop()
			end
			
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local newTrack = botAnimator:LoadAnimation(anim)
			newTrack.Priority = activeTrack.Priority
			newTrack:Play()
			
			-- Samakan posisi waktu tarian agar 100% selaras
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

-- Chat Command Listener
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		-- Hanya Owner yang berhak memanggil Pasukan Bot
		local role = RoleSystem:GetPlayerRole(player)
		if role ~= "Owner" then return end
		
		local msgLower = string.lower(message)
		
		if string.sub(msgLower, 1, 11) == "/stresstest" then
			local amountStr = string.sub(msgLower, 13)
			local amount = tonumber(amountStr) or 50
			amount = math.clamp(amount, 1, 100) -- Hard-limit 100 bot agar PC/Server tidak mati
			
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
