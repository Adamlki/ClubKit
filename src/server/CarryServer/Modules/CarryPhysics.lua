--!strict
-- ============================================================
-- CarryPhysics (Server Module)
-- Handles welds, physical states, collisions, and humanoid restoration
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarryConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CarryConfig"))

type PhysicsProps = {
	CanCollide: boolean,
	Massless: boolean,
	RootPriority: number?,
}

type HumanoidStateProps = {
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
	UseJumpPower: boolean,
	AutoRotate: boolean,
}

local CarryPhysics = {}

local savedPhysics: { [number]: { [BasePart]: PhysicsProps } } = {}
local savedHumanoidStates: { [number]: HumanoidStateProps } = {}
local antiWeightConnections: { [number]: RBXScriptConnection } = {}

function CarryPhysics.getCharHRP(player: Player?): (Model?, BasePart?, Humanoid?)
	if not player or not player.Character then return nil, nil, nil end
	local char = player.Character
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return nil, nil, nil end
	return char, hrp, hum
end

function CarryPhysics.getRigType(character: Model): string
	local hum = character:FindFirstChildOfClass("Humanoid")
	return if hum and hum.RigType == Enum.HumanoidRigType.R15 then "R15" else "R6"
end

function CarryPhysics.getAttachmentPart(character: Model): BasePart?
	if CarryPhysics.getRigType(character) == "R15" then
		return (character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	else
		return (character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
	end
end

function CarryPhysics.clearCarryWeld(character: Model?)
	if not character then return end
	for _, desc in ipairs(character:GetDescendants()) do
		if (desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Motor6D"))
			and (desc.Name == "CarryWeld" or desc.Name:find("Carry")) then
			desc:Destroy()
		end
	end
end

function CarryPhysics.createCarryWeld(carrierChar: Model, targetChar: Model, offset: CFrame): Weld?
	local carrierPart = CarryPhysics.getAttachmentPart(carrierChar)
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not carrierPart or not targetHRP then
		warn("[CarryPhysics] Failed to get attachment parts")
		return nil
	end

	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = carrierPart
	weld.Part1 = targetHRP
	weld.C0 = offset
	weld.C1 = CFrame.new(0, 0, 0)
	weld.Parent = targetHRP

	CarryConfig.debugPrint("WELD", "Created:", carrierPart.Name, "->", targetHRP.Name, "Rig:", CarryPhysics.getRigType(carrierChar))
	return weld
end

function CarryPhysics.makeCarriedWeightless(character: Model, userId: number, carrierPlayer: Player?)
	local properties: { [BasePart]: PhysicsProps } = {}
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			properties[part] = {
				CanCollide = part.CanCollide,
				Massless = part.Massless,
				RootPriority = part.RootPriority,
			}
			part.CanCollide = false
			part.Massless = true
			part.RootPriority = -1

			if carrierPlayer and part:CanSetNetworkOwnership() then
				pcall(function()
					part:SetNetworkOwner(carrierPlayer)
				end)
			end
		end
	end
	savedPhysics[userId] = properties
end

function CarryPhysics.restorePhysics(userId: number)
	local properties = savedPhysics[userId]
	if not properties then return end
	for part, props in pairs(properties) do
		if part and part.Parent then
			part.CanCollide = props.CanCollide
			part.Massless = props.Massless
			if props.RootPriority then
				part.RootPriority = props.RootPriority
			end
			if part:CanSetNetworkOwnership() then
				pcall(function()
					part:SetNetworkOwnershipAuto()
				end)
			end
		end
	end
	savedPhysics[userId] = nil
end

function CarryPhysics.saveHumanoidState(userId: number, hum: Humanoid)
	savedHumanoidStates[userId] = {
		WalkSpeed = hum.WalkSpeed,
		JumpPower = hum.JumpPower,
		JumpHeight = hum.JumpHeight,
		UseJumpPower = hum.UseJumpPower,
		AutoRotate = hum.AutoRotate,
	}
end

function CarryPhysics.applyCarriedState(hum: Humanoid)
	hum.WalkSpeed = 0
	hum.AutoRotate = false
	hum.PlatformStand = true

	if hum.UseJumpPower then
		hum.JumpPower = 0
	else
		hum.JumpHeight = 0
	end

	local statesToDisable = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Freefall,
	}
	for _, state in ipairs(statesToDisable) do
		hum:SetStateEnabled(state, false)
	end

	hum:ChangeState(Enum.HumanoidStateType.Physics)
end

function CarryPhysics.restoreHumanoidState(userId: number, hum: Humanoid)
	local state = savedHumanoidStates[userId]

	if state then
		hum.WalkSpeed = state.WalkSpeed
		hum.AutoRotate = state.AutoRotate
		if state.UseJumpPower then
			hum.JumpPower = state.JumpPower
		else
			hum.JumpHeight = state.JumpHeight
		end
		savedHumanoidStates[userId] = nil
	else
		hum.WalkSpeed = 16
		hum.AutoRotate = true
		if hum.UseJumpPower then
			hum.JumpPower = 50
		else
			hum.JumpHeight = 7.2
		end
	end

	hum.PlatformStand = false

	local statesToEnable = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.GettingUp,
		Enum.HumanoidStateType.Jumping,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Freefall,
	}
	for _, s in ipairs(statesToEnable) do
		hum:SetStateEnabled(s, true)
	end

	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
end

function CarryPhysics.attachAntiWeightListener(userId: number, character: Model)
	if antiWeightConnections[userId] then
		antiWeightConnections[userId]:Disconnect()
	end
	antiWeightConnections[userId] = character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			descendant.CanCollide = false
		end
	end)
end

function CarryPhysics.detachAntiWeightListener(userId: number)
	if antiWeightConnections[userId] then
		antiWeightConnections[userId]:Disconnect()
		antiWeightConnections[userId] = nil
	end
end

function CarryPhysics.cleanupPlayer(userId: number)
	CarryPhysics.detachAntiWeightListener(userId)
	CarryPhysics.restorePhysics(userId)
	savedHumanoidStates[userId] = nil
end

return CarryPhysics
