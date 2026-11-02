local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PrivateConfig = require(script.Parent:WaitForChild("PrivateConfig"))

local DataStoreEnv = {}
DataStoreEnv.IsStudio = RunService:IsStudio()

local WRITE_SUFFIX = "_StudioWrite_v1"

local function prefixedName(name)
	local prefix = PrivateConfig.DataStorePrefix or ""
	return tostring(prefix) .. tostring(name)
end

function DataStoreEnv.WriteName(name)
	local base = prefixedName(name)
	if DataStoreEnv.IsStudio then
		return base .. WRITE_SUFFIX
	end
	return base
end

function DataStoreEnv.Get(name, scope)
	local readStore = DataStoreService:GetDataStore(prefixedName(name), scope)
	if not DataStoreEnv.IsStudio then
		return readStore, readStore
	end
	return readStore, DataStoreService:GetDataStore(DataStoreEnv.WriteName(name), scope)
end

function DataStoreEnv.GetOrdered(name, scope)
	local readStore = DataStoreService:GetOrderedDataStore(prefixedName(name), scope)
	if not DataStoreEnv.IsStudio then
		return readStore, readStore
	end
	return readStore, DataStoreService:GetOrderedDataStore(DataStoreEnv.WriteName(name), scope)
end

return DataStoreEnv
