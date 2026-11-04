local ServerStorage = game:GetService("ServerStorage")
local DataStoreEnv = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DataStoreEnv"))
local TitleDataManager = {}

local CONFIG = nil
local TitleDataStore = nil
local TitleWriteStore = nil
local playerTitleCache = {}

function TitleDataManager:Init(config)
	CONFIG = config
	TitleDataStore, TitleWriteStore = DataStoreEnv.Get(CONFIG.TITLE_DATASTORE_NAME)
end

local function deserializeColor(colorData)
	if type(colorData) == "table" and colorData.R and colorData.G and colorData.B then
		return Color3.fromRGB(colorData.R, colorData.G, colorData.B)
	end
	return Color3.fromRGB(255, 255, 255)
end

function TitleDataManager:LoadTitleData(userId)
	-- Cache negatif agar pemain tanpa title tidak memicu GetAsync berulang.
	if playerTitleCache[userId] ~= nil then
		return playerTitleCache[userId] or nil
	end

	local success, data = pcall(function()
		return TitleDataStore:GetAsync(CONFIG.TITLE_DATASTORE_PREFIX .. userId)
	end)

	if success then
		if data then
			local titleData = {
				Title = data.Title or "",
				Color = deserializeColor(data.Color),
			}
			playerTitleCache[userId] = titleData
			return titleData
		else
			playerTitleCache[userId] = false
			return nil
		end
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
	}

	local success, err = pcall(function()
		TitleWriteStore:SetAsync(CONFIG.TITLE_DATASTORE_PREFIX .. userId, serializedData)
	end)

	if success then
		playerTitleCache[userId] = titleData
	end

	return success, err
end

function TitleDataManager:GetCache(userId)
	return playerTitleCache[userId] or nil
end

function TitleDataManager:UpdateCache(userId, titleData)
	playerTitleCache[userId] = titleData
end

function TitleDataManager:ClearCache(userId)
	playerTitleCache[userId] = nil
end

return TitleDataManager
