--!strict
-- ============================================================
-- FormatUtils (ClubKit Shared Utility)
-- Single source of truth for formatting numbers, currency, & time
-- ============================================================

local FormatUtils = {}

--- Format angka menjadi format ribuan dengan pemisah titik atau koma
-- Contoh: formatNumber(1000000) -> "1.000.000"
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

--- Membersihkan string dari karakter non-numerik lalu convert ke number
function FormatUtils.cleanNumber(value: any): number
	if type(value) == "number" then
		return value
	end
	local str = tostring(value or "0")
	local cleanStr = string.gsub(str, "%D", "")
	return tonumber(cleanStr) or 0
end

--- Format angka ke standar mata uang Rupiah
-- Contoh: formatRupiah(50000) -> "Rp 50.000"
function FormatUtils.formatRupiah(amount: number | string): string
	return "Rp " .. FormatUtils.formatNumber(amount, ".")
end

--- Format uang dengan prefix atau suffix kustom
-- Contoh: formatMoney(500, "", " Robux") -> "500 Robux"
function FormatUtils.formatMoney(amount: number | string, prefix: string?, suffix: string?): string
	local p = prefix or ""
	local s = suffix or ""
	return p .. FormatUtils.formatNumber(amount, ".") .. s
end

--- Format detik menjadi format durasi jam/menit/detik
-- Contoh: formatDuration(3665) -> "01h 01m 05s"
function FormatUtils.formatDuration(seconds: number): string
	local sec = math.max(0, math.floor(seconds or 0))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	return string.format("%02dh %02dm %02ds", h, m, s)
end

return FormatUtils
