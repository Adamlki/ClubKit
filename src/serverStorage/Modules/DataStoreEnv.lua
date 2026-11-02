local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStoreEnv = {}
DataStoreEnv.IsStudio = RunService:IsStudio()

local WRITE_SUFFIX = "_StudioWrite_v1"

function DataStoreEnv.WriteName(name)
	if DataStoreEnv.IsStudio then
		return tostring(name) .. WRITE_SUFFIX
	end
	return name
end

function DataStoreEnv.Get(name, scope)
	local readStore = DataStoreService:GetDataStore(name, scope)
	if not DataStoreEnv.IsStudio then
		return readStore, readStore
	end
	return readStore, DataStoreService:GetDataStore(DataStoreEnv.WriteName(name), scope)
end

function DataStoreEnv.GetOrdered(name, scope)
	local readStore = DataStoreService:GetOrderedDataStore(name, scope)
	if not DataStoreEnv.IsStudio then
		return readStore, readStore
	end
	return readStore, DataStoreService:GetOrderedDataStore(DataStoreEnv.WriteName(name), scope)
end

return DataStoreEnv
