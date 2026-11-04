local FormatUtils = {}

function FormatUtils.formatNumber(num: number | string, delimiter: string?): string
	local delim = delimiter or "."
	local val = math.floor(tonumber(num) or 0)
	local str = tostring(val)
	local formatted = str
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1" .. delim .. "%2")
		if k == 0 then break end
	end
	return formatted
end

function FormatUtils.cleanNumber(value: any): number
	if type(value) == "number" then
		return value
	end
	local str = tostring(value or "0")
	local cleanStr = string.gsub(str, "%D", "")
	return tonumber(cleanStr) or 0
end

function FormatUtils.formatRupiah(amount: number | string): string
	return "Rp " .. FormatUtils.formatNumber(amount, ".")
end

function FormatUtils.formatMoney(amount: number | string, prefix: string?, suffix: string?): string
	local p = prefix or ""
	local s = suffix or ""
	return p .. FormatUtils.formatNumber(amount, ".") .. s
end

function FormatUtils.formatDuration(seconds: number): string
	local sec = math.max(0, math.floor(seconds or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%02dh %02dm %02ds", h, m, s)
end

return FormatUtils
