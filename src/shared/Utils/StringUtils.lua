--!strict
-- ============================================================
-- StringUtils (ClubKit Shared Utility)
-- Standard text utilities: sanitization, trimming, and truncation
-- ============================================================

local StringUtils = {}

--- Escapes special HTML/RichText characters to prevent injection / formatting breakages
function StringUtils.sanitizeHtml(text: any): string
	if not text then return "" end
	local str = tostring(text)
	str = str:gsub("&", "&amp;")
	str = str:gsub("<", "&lt;")
	str = str:gsub(">", "&gt;")
	str = str:gsub('"', "&quot;")
	str = str:gsub("'", "&apos;")
	return str
end

--- Memangkas whitespace di awal dan akhir string
function StringUtils.trim(text: any): string
	if not text then return "" end
	return (tostring(text):gsub("^%s*(.-)%s*$", "%1"))
end

--- Memotong teks jika melebihi panjang maksimum
function StringUtils.truncate(text: any, maxLength: number, suffix: string?): string
	if not text then return "" end
	local str = tostring(text)
	local limit = math.max(1, maxLength)
	if #str <= limit then
		return str
	end
	local s = suffix or "..."
	return string.sub(str, 1, limit - #s) .. s
end

--- Membersihkan karakter non-digit
function StringUtils.cleanNumber(value: any): number
	if type(value) == "number" then
		return value
	end
	local str = tostring(value or "0")
	local cleanStr = string.gsub(str, "%D", "")
	return tonumber(cleanStr) or 0
end

return StringUtils
