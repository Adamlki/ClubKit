-- ========================================================
-- SAWERIA API MODULE (ENTERPRISE GRADE GATEKEEPER)
-- Menjaga agar ratusan server tidak membombardir Google
-- ========================================================
local HttpService = game:GetService("HttpService")

local SaweriaAPI = {}

-- CONFIG API
local WEB_APP_URL = "https://script.google.com/macros/s/AKfycbwCfybjVBntG6MsBmwuDwHpwiiIcob8dtf2wx6OmFI7FiJZDcOPH6ESqcSxowTjB3I/exec"

-- SISTEM CACHE ANTI-MELEDAK
local cachedData = nil
local lastFetchTime = 0
local isFetching = false

-- 🔥 ARCHITECT FIX: Jeda Aman 15 Detik. 
-- Walau ada 100 skrip yang minta data di detik yang sama, 
-- Modul ini HANYA akan menelpon Google 1 kali setiap 15 detik!
local FETCH_COOLDOWN = 15 

function SaweriaAPI:GetDonationData()
	local currentTime = os.clock()

	-- 1. CEK CACHE: Jika masih dalam masa cooldown 15 detik, 
	-- berikan data lama (0% Lag, 0 API Call)
	if cachedData and (currentTime - lastFetchTime) < FETCH_COOLDOWN then
		return cachedData
	end
	
	if isFetching then
		return cachedData
	end

	isFetching = true
	lastFetchTime = os.clock() -- Update waktu SEBELUM nge-yield agar tertutup rapat!

	local success, response = false, nil
	
	-- 🔥 ARCHITECT FIX: Smart Auto-Retry dengan Exponential Backoff
	for attempt = 1, 3 do
		success, response = pcall(function()
			return HttpService:GetAsync(WEB_APP_URL .. "?action=getLatest&t=" .. os.time())
		end)

		if success and response then
			local ok, result = pcall(function()
				return HttpService:JSONDecode(response)
			end)

			if ok and type(result) == "table" then
				-- Simpan data terbaru ke ingatan Modul
				cachedData = result.data or result
				isFetching = false
				print(string.format("[SaweriaAPI] ✅ Berhasil mengambil data dari Google Sheets! Total donasi: %d", type(cachedData) == "table" and #cachedData or 0))
				return cachedData
			else
				warn("[SaweriaAPI] ❌ Gagal JSONDecode respon dari Google Sheets:", tostring(response):sub(1, 200))
			end
		else
			local errMsg = tostring(response)
			if errMsg:find("Http requests are not enabled") then
				warn("[SaweriaAPI] ❌ HTTP REQUESTS BELUM DIAKTIFKAN DI ROBLOX STUDIO!")
				warn("[SaweriaAPI] 👉 Cara aktifkan: Buka menu Home > Game Settings > Security > centang 'Allow HTTP Requests' lalu Save!")
				break
			else
				warn(string.format("[SaweriaAPI] ⚠️ Percobaan ke-%d gagal HTTP: %s", attempt, errMsg))
			end
		end

		if attempt < 3 then
			task.wait(2 ^ attempt) -- Exponential Backoff: 2s, 4s
		else
			warn("[SaweriaAPI] ❌ Gagal mengambil data terbaru dari Google API setelah 3 kali percobaan.")
		end
	end

	-- Jika Google sedang down/error, lepaskan kunci dan kembalikan data terakhir
	isFetching = false
	return cachedData
end

return SaweriaAPI  