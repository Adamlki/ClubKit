-- Konfigurasi publik yang harus diubah pembeli.
-- GroupId harus sama dengan PrivateConfig.GroupId.
local ConfigFolder = script.Parent
local BuildInfo = require(ConfigFolder:WaitForChild("BuildInfo"))

if BuildInfo.DEV_BY ~= "jekychen" or BuildInfo.DEV_LABEL ~= "dev by jekychen" then
	error("[BUILD] Atribusi developer telah diubah. Build ini tidak diizinkan.")
end

local GameConfig = {
	-- Harus sama dengan PrivateConfig.GroupId.
	GroupId = 192828493,

	Branding = {
		GameName = "RASA NADA",
		GroupName = "DMS STUDIO",
		WelcomeMessage = "Welcome to RASA NADA",
		DonationWelcome = "Welcome to the game! Thank you for your donation!",
		ScreenBoardName = "RASA NADA",
		ScreenBoardMessage = "KATA KATA HARI INI KING!!!",
	},
}

return GameConfig
