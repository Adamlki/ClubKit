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
-- CARRY STYLES
-- ============================================

CarryConfig.STYLES = {
	piggyback = {
		name = "piggyback",
		displayName = "Piggy Back",
		offsetFunction = function()
			return CFrame.new(0, -0.5, 1.0)
		end,
		animIds = {
			carrier = 124001673795448,
			carried = 97128502545518
		}
	},

	bridal = {
		name = "bridal",
		displayName = "Bridal Carry",
		offsetFunction = function()
			return CFrame.new(1, 0.5, -1.0) * CFrame.fromEulerAnglesXYZ(
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
		offsetFunction = function()
			return CFrame.new(0, 0.6, -1.2) * CFrame.fromEulerAnglesXYZ(
				-25, math.rad(165), 0
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
		offsetFunction = function()
			return CFrame.new(0, 0.5, -1.7) * CFrame.fromEulerAnglesXYZ(
				-25, math.rad(175), 0
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
		offsetFunction = function()
			return CFrame.new(0, 3, 1.1)
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

function CarryConfig.getStyleOffset(styleName)
	local style = CarryConfig.STYLES[styleName]
	if not style then
		warn("Invalid style:", styleName)
		return CFrame.new(0, 0, 0)
	end
	return style.offsetFunction()
end

function CarryConfig.getAnimationId(styleName, role)
	local style = CarryConfig.STYLES[styleName]
	if not style then return 0 end
	return style.animIds[role] or 0
end

return CarryConfig