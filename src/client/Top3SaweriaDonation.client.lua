local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("FormatUtils"))
local StatueRenderer = require(script.Parent:WaitForChild("Modules"):WaitForChild("StatueRenderer"))
local AssetConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("AssetConfig"))

local SaweriaStatueManager = StatueRenderer.create({
	categoryName = "Saweria",
	posPrefix = "Saweria_Pos",
	modelPrefix = "Saweria_Donator_",
	remoteEventName = "UpdateSaweriaTopBoard",
	animations = AssetConfig.Animations.Top3,
	rankColors = {
		[1] = Color3.fromRGB(255, 215, 0),
		[2] = Color3.fromRGB(192, 192, 192),
		[3] = Color3.fromRGB(205, 127, 50),
	},
	formatValue = function(amount)
		return FormatUtils.formatRupiah(amount)
	end,
})
