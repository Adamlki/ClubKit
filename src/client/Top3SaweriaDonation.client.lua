--!strict
-- ============================================================
-- Top3SaweriaDonation (Client)
-- Renders the Top 3 Saweria Donators podium statues
-- Refactored to delegate to StatueRenderer (SOLID & DRY)
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatUtils = require(ReplicatedStorage:WaitForChild("Utils"):WaitForChild("FormatUtils"))
local StatueRenderer = require(script.Parent:WaitForChild("Modules"):WaitForChild("StatueRenderer"))

local SaweriaStatueManager = StatueRenderer.create({
	categoryName = "Saweria",
	posPrefix = "Saweria_Pos",
	modelPrefix = "Saweria_Donator_",
	remoteEventName = "UpdateSaweriaTopBoard",
	animations = {
		Top1 = "rbxassetid://109979406375718",
		Top2 = "rbxassetid://109979406375718",
		Top3 = "rbxassetid://109979406375718",
	},
	rankColors = {
		[1] = Color3.fromRGB(255, 215, 0), -- Emas
		[2] = Color3.fromRGB(192, 192, 192), -- Perak
		[3] = Color3.fromRGB(205, 127, 50), -- Coklat
	},
	formatValue = function(amount)
		return FormatUtils.formatRupiah(amount)
	end,
})

return SaweriaStatueManager