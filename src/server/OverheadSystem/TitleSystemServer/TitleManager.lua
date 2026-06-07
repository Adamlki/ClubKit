local DataStoreService = game:GetService("DataStoreService")
local TitleDataManager = {}

local CONFIG = nil
local TitleDataStore = nil
local playerTitleCache = {}

function TitleDataManager:Init(config)
	CONFIG = config
	TitleDataStore = DataStoreService:GetDataStore(CONFIG.DATASTORE_NAME)
end

local function sanitizeString(str)
	if type(str) ~= "string" then return "" end
	str = str:match("^%s*(.-)%s*$")
	if #str > CONFIG.MAX_TITLE_LENGTH then
		str = str:sub(1, CONFIG.MAX_TITLE_LENGTH)
	end
	return str
end

local function validateColor(color)
	if typeof(color) == "Color3" then
		return color
	end
	return Color3.fromRGB(255, 255, 255)
end

local function serializeColor(color3)
	return {
		R = math.floor(color3.R * 255),
		G = math.floor(color3.G * 255),
		B = math.floor(color3.B * 255)
	}
end

local function deserializeColor(colorData)
	if type(colorData) == "table" and colorData.R and colorData.G and colorData.B then
		return Color3.fromRGB(colorData.R, colorData.G, colorData.B)
	end
	return Color3.fromRGB(255, 255, 255)
end

function TitleDataManager:ValidateTitleData(titleData)
	return {
		Title = sanitizeString(titleData.Title),
		Color = validateColor(titleData.Color),
		GradientEnabled = type(titleData.Gradient) == "boolean" and titleData.Gradient or false,
		GradientEffect = titleData.GradientEffect or "wave"
	}
end

function TitleDataManager:SaveTitleData(userId, titleData)
	local serializedData = {
		Title = titleData.Title,
		Color = serializeColor(titleData.Color),
		GradientEnabled = titleData.GradientEnabled,
		GradientEffect = titleData.GradientEffect or "wave"
	}

	local success, err = pcall(function()
		TitleDataStore:SetAsync(CONFIG.DATASTORE_PREFIX .. userId, serializedData)
	end)

	if success then
		playerTitleCache[userId] = titleData
	end

	return success
end

function TitleDataManager:LoadTitleData(userId)
	if playerTitleCache[userId] then
		return playerTitleCache[userId]
	end

	local success, data = pcall(function()
		return TitleDataStore:GetAsync(CONFIG.DATASTORE_PREFIX .. userId)
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

function TitleDataManager:ClearCache(userId)
	playerTitleCache[userId] = nil
end

return TitleDataManager