local Config = require(script.Parent:WaitForChild("Config"))
local Logger = require(script.Parent:WaitForChild("Logger"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAnimator = require(ReplicatedStorage:WaitForChild("UIAnimator"))

local UIManager = {}

UIManager.activeConfirmConnections = nil 

function UIManager:SetButtonState(button, state)
	local stateConfig = Config.ButtonStates[state]
	if not stateConfig then return end

	button.Text = stateConfig.Text
	button.BackgroundColor3 = stateConfig.BackgroundColor
	button.TextColor3 = stateConfig.TextColor
	button.Active = stateConfig.Enabled
	button.AutoButtonColor = stateConfig.Enabled
end

function UIManager:ShowConfirmDialog(confirmDialog, confirmText, text, onYes, onNo)
	if not confirmDialog then
		Logger:Warn("ConfirmDialog tidak tersedia!")
		if onNo then onNo() end
		return {}
	end

	confirmText.Text = text

	-- Munculkan dialog konfirmasi pakai animasi
	UIAnimator.Open(confirmDialog)

	return {
		yesConnection = nil,
		noConnection = nil,
		dialog = confirmDialog
	}
end

function UIManager:SetupConfirmButtons(confirmYesBtn, confirmNoBtn, onYes, onNo)
	if self.activeConfirmConnections and self.activeConfirmConnections.cleanup then
		self.activeConfirmConnections.cleanup()
	end

	local connections = {
		yesConnection = nil,
		noConnection = nil,
		dialog = nil
	}

	local function cleanup()
		if connections.yesConnection then
			connections.yesConnection:Disconnect()
			connections.yesConnection = nil
		end
		if connections.noConnection then
			connections.noConnection:Disconnect()
			connections.noConnection = nil
		end

		-- Tutup dialog pakai animasi jika direferensikan
		if connections.dialog then
			UIAnimator.Close(connections.dialog)
		end

		if self.activeConfirmConnections == connections then
			self.activeConfirmConnections = nil
		end
	end

	connections.cleanup = cleanup

	connections.yesConnection = confirmYesBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm Yes clicked")
		cleanup()
		if onYes then pcall(onYes) end
	end)

	connections.noConnection = confirmNoBtn.MouseButton1Click:Connect(function()
		Logger:Debug("Confirm No clicked")
		cleanup()
		if onNo then pcall(onNo) end
	end)

	self.activeConfirmConnections = connections

	return connections
end

return UIManager
