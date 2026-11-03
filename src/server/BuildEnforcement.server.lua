--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, buildInfo = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BuildInfo"))
end)

local invalidReason
if not ok then
	invalidReason = "BuildInfo gagal dimuat: " .. tostring(buildInfo)
elseif buildInfo.DEV_BY ~= "jekychen" or buildInfo.DEV_LABEL ~= "dev by jekychen" then
	invalidReason = "DEV_BY/DEV_LABEL bukan dev by jekychen"
end

if invalidReason then
	warn("[BUILD] Build diblokir. " .. invalidReason)
	Players.CharacterAutoLoads = false

	local function rejectPlayer(player)
		pcall(function()
			player:Kick("Build integrity error: dev by jekychen")
		end)
	end

	Players.PlayerAdded:Connect(rejectPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		rejectPlayer(player)
	end
	return
end

print(
	"[BUILD] "
		.. tostring(buildInfo.DEV_LABEL)
		.. " | Core v"
		.. tostring(buildInfo.CORE_VERSION)
		.. " | Config schema "
		.. tostring(buildInfo.CONFIG_SCHEMA)
)
