local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local LikeVisualEffectRemote = RemotesFolder:WaitForChild("LikeVisualEffect")

-- Fungsi Bezier Curve untuk membuat efek melengkung saat terbang
local function quadraticBezier(t, p0, p1, p2)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

local function playLoveEffect(senderPlayer, targetPlayer)
	-- Pastikan karakter masih ada di map
	local senderChar = senderPlayer.Character
	local targetChar = targetPlayer.Character
	if not senderChar or not targetChar then return end
	
	local senderHead = senderChar:FindFirstChild("Head")
	local targetHead = targetChar:FindFirstChild("Head")
	if not senderHead or not targetHead then return end

	-- Ambil template dari ReplicatedStorage
	local effectTemplate = ReplicatedStorage:FindFirstChild("LoveVisualEffect")
	
	local effectPart = Instance.new("Part")
	effectPart.Name = "LoveVisualEffect_Moving"
	effectPart.Size = Vector3.new(1, 1, 1)
	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.Transparency = 1
	effectPart.CFrame = senderHead.CFrame
	effectPart.Parent = workspace
	
	if effectTemplate then
		if effectTemplate:IsA("BasePart") then
			-- Jika user menyimpan Part utuh
			effectPart:Destroy() -- Ganti dengan clone
			effectPart = effectTemplate:Clone()
			effectPart.Anchored = true
			effectPart.CanCollide = false
			effectPart.CFrame = senderHead.CFrame
			effectPart.Parent = workspace
		elseif effectTemplate:IsA("ParticleEmitter") or effectTemplate:IsA("Attachment") then
			-- Jika user hanya menyimpan ParticleEmitter atau Attachment
			local cloneItem = effectTemplate:Clone()
			cloneItem.Parent = effectPart
		end
		
		-- Pastikan semua ParticleEmitter aktif saat mulai terbang
		for _, child in pairs(effectPart:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = true
			end
		end
	else
		-- Fallback default jika tidak ada di ReplicatedStorage
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = effectPart
		
		local heartImage = Instance.new("ImageLabel")
		heartImage.Size = UDim2.new(1, 0, 1, 0)
		heartImage.BackgroundTransparency = 1
		heartImage.Image = "rbxassetid://6034638780"
		heartImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
		heartImage.Parent = billboard
	end

	-- Konfigurasi Animasi Terbang
	local startPos = senderHead.Position + Vector3.new(0, 2, 0)
	
	-- Posisi agar terlihat oleh pengirim (diri sendiri)
	if senderPlayer == game:GetService("Players").LocalPlayer then
		local camera = workspace.CurrentCamera
		if camera then
			startPos = camera.CFrame.Position + (camera.CFrame.LookVector * 4) + Vector3.new(0, -0.5, 0)
		end
	end
	
	local endPos = targetHead.Position + Vector3.new(0, 2, 0)
	
	-- Titik melengkung di tengah
	local midPoint = startPos:Lerp(endPos, 0.5) + Vector3.new(0, math.random(4, 8), 0)

	-- Value palsu untuk menjalankan tween
	local tweenVal = Instance.new("NumberValue")
	tweenVal.Value = 0

	local tweenAnim = TweenService:Create(tweenVal, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Value = 1
	})

	local connection
	connection = tweenVal:GetPropertyChangedSignal("Value"):Connect(function()
		local currentPos = quadraticBezier(tweenVal.Value, startPos, midPoint, endPos)
		effectPart.Position = currentPos
	end)

	tweenAnim:Play()

	-- Setelah selesai terbang
	tweenAnim.Completed:Once(function()
		connection:Disconnect()
		
		-- Matikan semua ParticleEmitter agar tidak mengeluarkan hati baru, tapi biarkan hati yang sudah ada menghilang perlahan
		for _, child in pairs(effectPart:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		
		-- Beri jeda 3 detik agar semua sisa partikel love di udara selesai menghilang secara natural sebelum part dihapus
		task.delay(3, function()
			if effectPart then
				effectPart:Destroy()
			end
		end)
		tweenVal:Destroy()
	end)
end

-- Dengarkan panggilan dari server
LikeVisualEffectRemote.OnClientEvent:Connect(playLoveEffect)
