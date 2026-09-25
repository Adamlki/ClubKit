--!native
--!optimize 2
local CarryConfig = {}

-- ============================================
-- DEBUG SETTINGS
-- ============================================

CarryConfig.DEBUG_ENABLED = false
CarryConfig.DEBUG_PREFIX = "[CARRY]"

function CarryConfig.debugPrint(category, ...)
	if not CarryConfig.DEBUG_ENABLED then return end
	print(CarryConfig.DEBUG_PREFIX, "[" .. category .. "]", ...)
end

-- ============================================
-- SYSTEM SETTINGS
-- ============================================

CarryConfig.REMOTE_FOLDER = "CarryRemotes"
CarryConfig.REQUEST_TIMEOUT = 10
CarryConfig.MAX_DISTANCE = 20

-- ============================================
-- AVATAR SCALING & METRICS HELPER
-- ============================================

function CarryConfig.getAvatarMetrics(char)
	if not char then
		return {
			heightScale = 1,
			widthScale = 1,
			depthScale = 1,
			torsoSize = Vector3.new(1.84, 1.90, 1.07),
			hrpSize = Vector3.new(2, 2, 1),
			isR15 = true,
		}
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local isR15 = (hum and hum.RigType == Enum.HumanoidRigType.R15) or (char:FindFirstChild("UpperTorso") ~= nil)

	local hScale = 1
	local wScale = 1
	local dScale = 1

	if hum then
		local bhs = hum:FindFirstChild("BodyHeightScale")
		local bws = hum:FindFirstChild("BodyWidthScale")
		local bds = hum:FindFirstChild("BodyDepthScale")
		if bhs and bhs:IsA("NumberValue") and bhs.Value > 0 then hScale = bhs.Value end
		if bws and bws:IsA("NumberValue") and bws.Value > 0 then wScale = bws.Value end
		if bds and bds:IsA("NumberValue") and bds.Value > 0 then dScale = bds.Value end
	end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local defaultTorsoSize = Vector3.new(1.84 * wScale, 1.90 * hScale, 1.07 * dScale)
	local torsoSize = torso and torso.Size or defaultTorsoSize

	-- Effective scale accounting for custom packages/bundles (chibi, mini, 2.0, blocky, etc.)
	local effH = math.clamp(math.max(hScale, torsoSize.Y / 1.90), 0.25, 3.5)
	local effW = math.clamp(math.max(wScale, torsoSize.X / 1.84), 0.25, 3.5)
	local effD = math.clamp(math.max(dScale, torsoSize.Z / 1.07), 0.25, 3.5)

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local defaultHrpSize = Vector3.new(2 * effW, 2 * effH, 1 * effD)
	local hrpSize = hrp and hrp.Size or defaultHrpSize

	return {
		heightScale = effH,
		widthScale = effW,
		depthScale = effD,
		torsoSize = torsoSize,
		hrpSize = hrpSize,
		isR15 = isR15,
	}
end

-- ============================================
-- CARRY STYLES
-- ============================================

CarryConfig.STYLES = {
	piggyback = {
		name = "piggyback",
		displayName = "Piggy Back",
		offsetFunction = function(carrierChar, carriedChar)
			local c = CarryConfig.getAvatarMetrics(carrierChar)
			local t = CarryConfig.getAvatarMetrics(carriedChar)
			local z = (c.torsoSize.Z * 0.5) + (t.hrpSize.Z * 0.45)
			local y = -0.35 * c.heightScale
			return CFrame.new(0, y, z)
		end,
		animIds = {
			carrier = 124001673795448,
			carried = 97128502545518
		}
	},

	bridal = {
		name = "bridal",
		displayName = "Bridal Carry",
		offsetFunction = function(carrierChar, carriedChar)
			local c = CarryConfig.getAvatarMetrics(carrierChar)
			local t = CarryConfig.getAvatarMetrics(carriedChar)
			local z = -((c.torsoSize.Z * 0.5) + (t.hrpSize.Z * 0.45))
			local x = 0.90 * c.widthScale
			local y = 0.35 * c.heightScale
			return CFrame.new(x, y, z) * CFrame.fromEulerAnglesXYZ(
				math.rad(15), math.rad(-5), math.rad(-20)
			)
		end,
		animIds = {
			carrier = 131191305026132,
			carried = 73746870245103
		}
	},

	couplehug = {
		name = "couplehug",
		displayName = "Couple Hug",
		offsetFunction = function(carrierChar, carriedChar)
			local c = CarryConfig.getAvatarMetrics(carrierChar)
			local t = CarryConfig.getAvatarMetrics(carriedChar)
			local z = -((c.torsoSize.Z * 0.5) + (t.hrpSize.Z * 0.45))
			local y = 0.55 * c.heightScale
			return CFrame.new(0, y, z) * CFrame.fromEulerAnglesXYZ(
				math.rad(-25), math.rad(165), 0
			)
		end,
		animIds = {
			carrier = 131249063658217,
			carried = 131051161693727
		}
	},

	pasakal = {
		name = "pasakal",
		displayName = "Pasakal",
		offsetFunction = function(carrierChar, carriedChar)
			local c = CarryConfig.getAvatarMetrics(carrierChar)
			local t = CarryConfig.getAvatarMetrics(carriedChar)
			local z = -((c.torsoSize.Z * 0.5) + (t.hrpSize.Z * 0.65))
			local y = 0.45 * c.heightScale
			return CFrame.new(0, y, z) * CFrame.fromEulerAnglesXYZ(
				math.rad(-25), math.rad(175), 0
			)
		end,
		animIds = {
			carrier = 77722414071091,
			carried = 123232169262292
		}
	},

	piggyupperback = {
		name = "piggyupperback",
		displayName = "Piggy Upper Back",
		offsetFunction = function(carrierChar, carriedChar)
			local c = CarryConfig.getAvatarMetrics(carrierChar)
			local t = CarryConfig.getAvatarMetrics(carriedChar)
			-- Pelvis rests snuggly on carrier shoulders, thighs drape over chest
			local y = (c.torsoSize.Y * 0.45) + (0.95 * t.heightScale)
			local z = 0.15 * c.depthScale
			return CFrame.new(0, y, z)
		end,
		animIds = {
			carrier = 101123124964571,
			carried = 91339498866204
		}
	}
}

-- ============================================
-- STYLE UTILITIES
-- ============================================

function CarryConfig.getStyle(styleName)
	return CarryConfig.STYLES[styleName]
end

function CarryConfig.isValidStyle(styleName)
	return CarryConfig.STYLES[styleName] ~= nil
end

function CarryConfig.getStyleOffset(styleName, carrierChar, carriedChar)
	local style = CarryConfig.STYLES[styleName]
	if not style then
		warn("Invalid style:", styleName)
		return CFrame.new(0, 0, 0)
	end
	return style.offsetFunction(carrierChar, carriedChar)
end

function CarryConfig.getAnimationId(styleName, role)
	local style = CarryConfig.STYLES[styleName]
	if not style then return 0 end
	return style.animIds[role] or 0
end

return CarryConfig