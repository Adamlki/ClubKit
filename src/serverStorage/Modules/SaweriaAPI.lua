-- SAWERIA API MODULE
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local SaweriaAPI = {}

local PrivateConfig = require(script.Parent:WaitForChild("PrivateConfig"))
local WEB_APP_URL = PrivateConfig.SaweriaWebhookURL
local IS_STUDIO = RunService:IsStudio()

-- Validasi konfigurasi: URL kosong / masih placeholder = jangan pernah polling
local URL_CONFIGURED = type(WEB_APP_URL) == "string"
	and WEB_APP_URL ~= ""
	and string.find(WEB_APP_URL, "PASTE_YOUR_", 1, true) == nil
	and string.find(WEB_APP_URL, "^https://") ~= nil

local warnedNotConfigured = false

local cachedData = nil
local lastFetchTime = 0
local isFetching = false
-- Apps Script already caches GET for 45s. Poll less often; this cuts
-- redirects/HTTP work dramatically during a session.
local FETCH_COOLDOWN = IS_STUDIO and 30 or 60

-- Anti-429: backoff eksponensial saat rate limit + jitter boot per server
local BACKOFF_STEPS = { 30, 60, 120, 300 }
local FAILURE_BACKOFF = 30
local backoffUntil = 0
local backoffIndex = 0
local bootJitterDone = false

local function isRateLimitError(errMsg)
	local lower = string.lower(errMsg)
	return string.find(lower, "429", 1, true) ~= nil
		or string.find(lower, "too many", 1, true) ~= nil
		or string.find(lower, "rate limit", 1, true) ~= nil
end

function SaweriaAPI:GetDonationData()
	if not URL_CONFIGURED then
		if not warnedNotConfigured then
			warnedNotConfigured = true
			warn("[SaweriaAPI] ⚠️ SaweriaWebhookURL belum diisi dengan URL valid di PrivateConfig.lua — polling Saweria dimatikan.")
			warn("[SaweriaAPI] 👉 Copy PrivateConfig.example.lua menjadi PrivateConfig.lua, isi SaweriaWebhookURL, lalu restart server.")
		end
		return cachedData
	end

	local currentTime = os.clock()

	-- Sedang dalam masa backoff (kena 429): pakai data cache, jangan kirim request baru
	if currentTime < backoffUntil then
		return cachedData
	end

	if cachedData and (currentTime - lastFetchTime) < FETCH_COOLDOWN then
		return cachedData
	end

	if isFetching then
		return cachedData
	end

	isFetching = true
	lastFetchTime = os.clock()

	-- Jitter boot: fetch pertama tiap server ditunda acak agar server tidak menembak Google serentak
	if not bootJitterDone then
		bootJitterDone = true
		task.wait(math.random() * 5)
	end

	local success, response = false, nil
	local rateLimited = false
	local configBroken = false

	for attempt = 1, 3 do
		success, response = pcall(function()
			return HttpService:GetAsync(WEB_APP_URL .. "?action=getLatest&t=" .. os.time())
		end)

		if success and response then
			local ok, result = pcall(function()
				return HttpService:JSONDecode(response)
			end)

			if ok and type(result) == "table" then
				cachedData = result.data or result
				backoffIndex = 0
				backoffUntil = 0
				isFetching = false
				if IS_STUDIO then
					print(string.format("[SaweriaAPI] ✅ Berhasil mengambil data dari Google Sheets! Total donasi: %d", type(cachedData) == "table" and #cachedData or 0))
				end
				return cachedData
			else
				warn("[SaweriaAPI] ❌ Gagal JSONDecode respon dari Google Sheets:", tostring(response):sub(1, 200))
			end
		else
			local errMsg = tostring(response)
			if errMsg:find("Http requests are not enabled") then
				warn("[SaweriaAPI] ❌ HTTP REQUESTS BELUM DIAKTIFKAN DI ROBLOX STUDIO!")
				warn("[SaweriaAPI] 👉 Cara aktifkan: Buka menu Home > Game Settings > Security > centang 'Allow HTTP Requests' lalu Save!")
				configBroken = true
				break
			elseif isRateLimitError(errMsg) then
				-- 429: retry hanya memperparah rate limit, langsung masuk backoff
				rateLimited = true
				break
			else
				warn(string.format("[SaweriaAPI] ⚠️ Percobaan ke-%d gagal HTTP: %s", attempt, errMsg))
			end
		end

		if attempt < 3 then
			task.wait(2 ^ attempt + math.random())
		end
	end

	isFetching = false

	if rateLimited then
		backoffIndex = math.min(backoffIndex + 1, #BACKOFF_STEPS)
		backoffUntil = os.clock() + BACKOFF_STEPS[backoffIndex]
		warn(string.format(
			"[SaweriaAPI] ⚠️ Terkena rate limit (HTTP 429) dari web app Saweria — polling dijeda %d detik (sementara pakai data cache).",
			BACKOFF_STEPS[backoffIndex]
		))
	elseif not configBroken then
		-- Also back off after a normal timeout/5xx, otherwise every caller
		-- immediately retries three times again and floods the queue.
		backoffUntil = os.clock() + FAILURE_BACKOFF
		warn("[SaweriaAPI] ❌ Gagal mengambil data terbaru dari Google API setelah 3 kali percobaan.")
	end

	return cachedData
end

return SaweriaAPI
