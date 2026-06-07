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

-- 🔥 ARCHITECT FIX: Jeda Aman 15 Detik. 
-- Walau ada 100 skrip yang minta data di detik yang sama, 
-- Modul ini HANYA akan menelpon Google 1 kali setiap 15 detik!
local FETCH_COOLDOWN = 15 

function SaweriaAPI:GetDonationData()
	local currentTime = tick()

	-- 1. CEK CACHE: Jika masih dalam masa cooldown 15 detik, 
	-- berikan data lama (0% Lag, 0 API Call)
	if cachedData and (currentTime - lastFetchTime) < FETCH_COOLDOWN then
		return cachedData
	end

	-- 2. FETCH BARU: Jika sudah lewat masa tunggu, baru telepon Google Sheets
	local success, response = pcall(function()
		return HttpService:GetAsync(WEB_APP_URL .. "?action=getLatest&t=" .. currentTime)
	end)

	if success and response then
		local ok, result = pcall(function()
			return HttpService:JSONDecode(response)
		end)

		if ok and type(result) == "table" then
			-- Simpan data terbaru ke ingatan Modul
			cachedData = result.data or result
			lastFetchTime = currentTime
			return cachedData
		end
	end

	-- Jika Google sedang down/error, jangan panik, kembalikan data terakhir yang kita punya
	return cachedData
end

return SaweriaAPI  