-- CameraLease: one owner for scripted camera effects.
-- Higher priority may take over; the original camera is restored only when
-- the current owner releases the lease.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CameraLease = {}

local current = nil -- { owner, priority, token }
local saved = nil
local nextToken = 0

local function snapshot()
	local camera = Workspace.CurrentCamera
	if not camera then return nil end

	local player = Players.LocalPlayer
	return {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		FieldOfView = camera.FieldOfView,
		CameraMode = player and player.CameraMode or nil,
	}
end

local function restore()
	local camera = Workspace.CurrentCamera
	if not camera or not saved then
		saved = nil
		return
	end

	camera.CameraType = saved.CameraType
	camera.CameraSubject = saved.CameraSubject
	camera.FieldOfView = saved.FieldOfView

	local player = Players.LocalPlayer
	if player and saved.CameraMode then
		player.CameraMode = saved.CameraMode
	end

	saved = nil
end

function CameraLease:Acquire(owner, priority)
	priority = tonumber(priority) or 0

	if current and current.priority > priority then
		return nil
	end

	if not current then
		saved = snapshot()
	end

	nextToken += 1
	current = {
		owner = owner,
		priority = priority,
		token = nextToken,
	}
	return nextToken
end

function CameraLease:IsOwner(owner, token)
	return current ~= nil and current.owner == owner and current.token == token
end

function CameraLease:Release(owner, token)
	if not self:IsOwner(owner, token) then
		return false
	end

	current = nil
	restore()
	return true
end

function CameraLease:GetOwner()
	return current and current.owner or nil
end

return CameraLease
