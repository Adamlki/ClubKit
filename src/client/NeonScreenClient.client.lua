--!native
--!optimize 2

local CollectionService = game:GetService("CollectionService")
local SoundService      = game:GetService("SoundService")

local COLOR_CHANGE_INTERVAL = 1.5 
local BLACK = Color3.new(0, 0, 0)

local STAGE_COLORS = {
	Color3.fromRGB(255, 0, 50),
	Color3.fromRGB(0, 255, 100),
	Color3.fromRGB(50, 100, 255),
	Color3.fromRGB(255, 0, 255), 
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(0, 255, 255),
	Color3.fromRGB(255, 255, 255),
}

local daftarNeon = {}

local function registerPart(part)
	if (part:IsA("BasePart") or part:IsA("MeshPart")) then
		part.Material = Enum.Material.Neon
		daftarNeon[part] = true
	end
end

local function unregisterPart(part)
	daftarNeon[part] = nil
end

for _, obj in ipairs(CollectionService:GetTagged("LampuDJ")) do
	registerPart(obj)
end
CollectionService:GetInstanceAddedSignal("LampuDJ"):Connect(registerPart)
CollectionService:GetInstanceRemovedSignal("LampuDJ"):Connect(unregisterPart)

task.spawn(function()
	local neonFolder = workspace:WaitForChild("NEONSCREEN")
	if neonFolder then
		for _, child in ipairs(neonFolder:GetChildren()) do
			registerPart(child)
		end
		neonFolder.ChildAdded:Connect(registerPart)
		neonFolder.ChildRemoved:Connect(unregisterPart)
	end
end)

local function setColors(newColor)
	for part in pairs(daftarNeon) do
		if part.Parent then
			part.Color = newColor
		else
			daftarNeon[part] = nil
		end
	end
end

local function pickSynchronizedColor()
	local timeSeed = math.floor(workspace:GetServerTimeNow() / COLOR_CHANGE_INTERVAL)
	local rng = Random.new(timeSeed)
	return STAGE_COLORS[rng:NextInteger(1, #STAGE_COLORS)]
end

local sound = SoundService:WaitForChild("ServerMusicSound")
local isMusicPlaying = false

local function updateLightingState()
	local soundPlaying = (sound ~= nil and sound.IsPlaying)
	if soundPlaying then
		isMusicPlaying = true
		setColors(pickSynchronizedColor())
	else
		if isMusicPlaying then
			isMusicPlaying = false
			setColors(BLACK)
		end
	end
end

if sound then
	sound.Played:Connect(function()
		isMusicPlaying = true
		setColors(pickSynchronizedColor())
	end)

	sound.Stopped:Connect(function()
		isMusicPlaying = false
		setColors(BLACK)
	end)

	sound.Ended:Connect(function()
		isMusicPlaying = false
		setColors(BLACK)
	end)
end

task.spawn(function()
	if sound and sound.IsPlaying then
		isMusicPlaying = true
		setColors(pickSynchronizedColor())
	else
		setColors(BLACK)
	end

	while true do
		task.wait(COLOR_CHANGE_INTERVAL)
		updateLightingState()
	end
end)
