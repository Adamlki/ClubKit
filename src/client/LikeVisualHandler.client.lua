local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local LikeVisualEffectRemote = RemotesFolder:WaitForChild("LikeVisualEffect")

local function quadraticBezier(t, p0, p1, p2)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

local function playLoveEffect(senderPlayer, targetPlayer)
	local senderChar = senderPlayer.Character
	local targetChar = targetPlayer.Character
	if not senderChar or not targetChar then return end
	
	local senderHead = senderChar:FindFirstChild("Head")
	local targetHead = targetChar:FindFirstChild("Head")
	if not senderHead or not targetHead then return end

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
			effectPart:Destroy()
			effectPart = effectTemplate:Clone()
			effectPart.Anchored = true
			effectPart.CanCollide = false
			effectPart.CFrame = senderHead.CFrame
			effectPart.Parent = workspace
		elseif effectTemplate:IsA("ParticleEmitter") or effectTemplate:IsA("Attachment") then
			local cloneItem = effectTemplate:Clone()
			cloneItem.Parent = effectPart
		end
		
		for _, child in pairs(effectPart:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = true
			end
		end
	else
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = effectPart
		
		local heartImage = Instance.new("ImageLabel")
		heartImage.Size = UDim2.new(1, 0, 1, 0)
		heartImage.BackgroundTransparency = 1
		heartImage.Image = AssetConfig.Images.LikeHeart
		heartImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
		heartImage.Parent = billboard
	end

	local startPos = senderHead.Position + Vector3.new(0, 2, 0)
	
	if senderPlayer == game:GetService("Players").LocalPlayer then
		local camera = workspace.CurrentCamera
		if camera then
			startPos = camera.CFrame.Position + (camera.CFrame.LookVector * 4) + Vector3.new(0, -0.5, 0)
		end
	end
	
	local endPos = targetHead.Position + Vector3.new(0, 2, 0)
	
	local midPoint = startPos:Lerp(endPos, 0.5) + Vector3.new(0, math.random(4, 8), 0)

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

	tweenAnim.Completed:Once(function()
		connection:Disconnect()
		
		for _, child in pairs(effectPart:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		
		task.delay(3, function()
			if effectPart then
				effectPart:Destroy()
			end
		end)
		tweenVal:Destroy()
	end)
end

LikeVisualEffectRemote.OnClientEvent:Connect(playLoveEffect)
