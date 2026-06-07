local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteManager = {}

RemoteManager.UpdateTitleRemote = nil
RemoteManager.GetPlayerTitleRemote = nil
RemoteManager.CheckAccessRemote = nil

function RemoteManager:Init(config)
	local RemoteFolder = ReplicatedStorage:FindFirstChild("TitleRemotes")
	if not RemoteFolder then
		RemoteFolder = Instance.new("Folder")
		RemoteFolder.Name = "TitleRemotes"
		RemoteFolder.Parent = ReplicatedStorage
	end

	self.UpdateTitleRemote = RemoteFolder:FindFirstChild("UpdateTitle")
	if not self.UpdateTitleRemote then
		self.UpdateTitleRemote = Instance.new("RemoteEvent")
		self.UpdateTitleRemote.Name = "UpdateTitle"
		self.UpdateTitleRemote.Parent = RemoteFolder
	end

	self.GetPlayerTitleRemote = RemoteFolder:FindFirstChild("GetPlayerTitle")
	if not self.GetPlayerTitleRemote then
		self.GetPlayerTitleRemote = Instance.new("RemoteFunction")
		self.GetPlayerTitleRemote.Name = "GetPlayerTitle"
		self.GetPlayerTitleRemote.Parent = RemoteFolder
	end

	self.CheckAccessRemote = RemoteFolder:FindFirstChild("CheckAccess")
	if not self.CheckAccessRemote then
		self.CheckAccessRemote = Instance.new("RemoteFunction")
		self.CheckAccessRemote.Name = "CheckAccess"
		self.CheckAccessRemote.Parent = RemoteFolder
	end
end

return RemoteManager