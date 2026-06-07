--Optimized by hera

local RunService = game:GetService("RunService")

local Remotes = {}

local DataKey = ''

if RunService:IsStudio() then
	DataKey = ""
else
	DataKey = game.JobId
end

local HashLib = require(game:GetService("ReplicatedStorage").Packages.HashLib)

function Remotes.Event(RemoteName)
	
	local EncryptedName = HashLib.bin_to_base64(HashLib.hex_to_bin(HashLib.sha1(RemoteName .. DataKey)))
	--RunService:IsServer() and
	if not script:FindFirstChild(EncryptedName) then
		
		local RemoteEvent = Instance.new("RemoteEvent")
		RemoteEvent.Name = EncryptedName
		RemoteEvent.Parent = script
		
		return RemoteEvent
	end
	
	local RemoteInstance = script:WaitForChild(EncryptedName, 4)
	
	if RemoteInstance == nil then
		error("Couldn't get RemoteEvent " .. RemoteName, 2)
	end
	
	return RemoteInstance
end

function Remotes.Function(RemoteName)
	
	local EncryptedName = HashLib.bin_to_base64(HashLib.hex_to_bin(HashLib.sha1(RemoteName .. DataKey)))
	--RunService:IsServer() and
	if not script:FindFirstChild(EncryptedName) then
		
		local RemoteFunction = Instance.new("RemoteFunction")
		RemoteFunction.Name = EncryptedName
		RemoteFunction.Parent = script
		
		return RemoteFunction
		
	end
	
	local RemoteInstance = script:WaitForChild(EncryptedName, 4)
	
	if RemoteInstance == nil then
		error("Couldn't get RemoteFunction " .. RemoteName, 2)
	end
	
	return RemoteInstance
	
end

function Remotes.OnClientEvent(RemoteName)
	
	return Remotes.Event(RemoteName).OnClientEvent
	
end

return Remotes