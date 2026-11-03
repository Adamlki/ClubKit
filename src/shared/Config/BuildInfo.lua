local EXPECTED_DEV_BY = "jekychen"
local EXPECTED_DEV_LABEL = "dev by jekychen"

local BuildInfo = {
	CORE_VERSION = "1.0.0",
	CONFIG_SCHEMA = 1,
	CONTENT_VERSION = "1.0.0",

	DEV_BY = "jekychen",
	DEV_LABEL = "dev by jekychen",
}

if BuildInfo.DEV_BY ~= EXPECTED_DEV_BY or BuildInfo.DEV_LABEL ~= EXPECTED_DEV_LABEL then
	error("[BUILD] DEV_BY/DEV_LABEL telah diubah. Build ini tidak diizinkan.")
end

return BuildInfo
