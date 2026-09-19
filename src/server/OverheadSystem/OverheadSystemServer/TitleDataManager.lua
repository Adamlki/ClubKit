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

local function serializeColor(color3)
	if typeof(color3) == "Color3" then
		return {
			R = math.floor(color3.R * 255),
			G = math.floor(color3.G * 255),
			B = math.floor(color3.B * 255)
		}
	end
	return { R = 255, G = 255, B = 255 }
end

function TitleDataManager:SaveTitleData(userId, titleData)
	local serializedData = {
		Title = titleData.Title or "",
		Color = serializeColor(titleData.Color),
		GradientEnabled = titleData.GradientEnabled or false,
		GradientEffect = titleData.GradientEffect or "wave"
	}

	local success, err = pcall(function()
		TitleDataStore:SetAsync(CONFIG.TITLE_DATASTORE_PREFIX .. userId, serializedData)
	end)

	if success then
		playerTitleCache[userId] = titleData
	end

	return success, err
end

function TitleDataManager:GetCache(userId)
	return playerTitleCache[userId]
end

function TitleDataManager:UpdateCache(userId, titleData)
	playerTitleCache[userId] = titleData
end

function TitleDataManager:ClearCache(userId)
	playerTitleCache[userId] = nil
end

return TitleDataManager