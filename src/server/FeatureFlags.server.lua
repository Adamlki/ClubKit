-- FEATURE FLAGS
-- Menyalin toggle dari ServerConfig ke ReplicatedStorage agar client dapat menampilkan/menyembunyikan UI dengan aman.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerConfig = require(ServerScriptService:WaitForChild("Config"):WaitForChild("ServerConfig"))

local featureFolder = ReplicatedStorage:FindFirstChild("FeatureFlags")
if not featureFolder then
	featureFolder = Instance.new("Folder")
	featureFolder.Name = "FeatureFlags"
	featureFolder.Parent = ReplicatedStorage
end

local function setFlag(name, value)
	local flag = featureFolder:FindFirstChild(name)
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = name
		flag.Parent = featureFolder
	end
	flag.Value = value == true
end

setFlag("VIPShopEnabled", ServerConfig.Features.VIPShopEnabled)
setFlag("VIPGiftEnabled", ServerConfig.Features.VIPGiftEnabled)
setFlag("CommunityVIPEnabled", ServerConfig.Features.CommunityVIPEnabled)
