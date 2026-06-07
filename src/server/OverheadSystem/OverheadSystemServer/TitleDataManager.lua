local DataStoreService = game:GetService("DataStoreService")
local TitleDataManager = {}

local CONFIG = nil
local TitleDataStore = nil
local playerTitleCache = {}

function TitleDataManager:Init(config)
	CONFIG = config
	TitleDataStore = DataStoreService:GetDataStore(CONFIG.TITLE_DATASTORE_NAME)
end

local function deserializeColor(colorData)
	if type(colorData) == "table" and colorData.R and colorData.G and colorData.B then
		return Color3.fromRGB(colorData.R, colorData.G, colorData.B)
	end
	return Color3.fromRGB(255, 255, 255)
end

function TitleDataManager:LoadTitleData(userId)
	if playerTitleCache[userId] then
		return playerTitleCache[userId]
	end

	local success, data = pcall(function()
		return TitleDataStore:GetAsync(CONFIG.TITLE_DATASTORE_PREFIX .. userId)
	end)

	if success and data then
		local titleData = {
			Title = data.Title or "",
			Color = deserializeColor(data.Color),
			GradientEnabled = data.GradientEnabled or false,
			GradientEffect = data.GradientEffect or "wave"
		}
		playerTitleCache[userId] = titleData
		return titleData
	end

	return nil
end

function TitleDataManager:UpdateCache(userId, titleData)
	playerTitleCache[userId] = titleData
end

function TitleDataManager:ClearCache(userId)
	playerTitleCache[userId] = nil
end

return TitleDataManager