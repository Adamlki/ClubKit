local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local DonationConfig     = require(script.Parent.DonationConfig)

local ProcessReceiptHandler = {}

-- ============================================
-- STATE
-- ============================================
local initialized        = false
local registeredCallbacks = {}  -- [name] = function
local processedReceipts  = {}   -- [purchaseId] = {timestamp, processed}
local activeProcessing   = {}

-- ============================================
-- HELPER
-- ============================================
local function debugLog(category, ...)
	if not DonationConfig.DEBUG.ENABLED then return end
	local show = (category == "RECEIPT" and DonationConfig.DEBUG.SHOW_RECEIPT)
		or (category == "ERROR"   and DonationConfig.DEBUG.SHOW_ERRORS)
	if not show then return end
	if category == "ERROR" then
		warn("[RECEIPT ERROR]", ...)
	else
		print("[RECEIPT]", ...)
	end
end

local function isReceiptProcessed(purchaseId)
	return processedReceipts[purchaseId] ~= nil
end

local function markReceiptProcessed(purchaseId)
	processedReceipts[purchaseId] = {
		timestamp = os.time(),
		processed = true
	}
end

-- Hapus receipt lama (lebih dari 1 jam)
local function cleanupOldReceipts()
	local now = os.time()
	local cleaned = 0
	for purchaseId, data in pairs(processedReceipts) do
		if now - data.timestamp > 3600 then
			processedReceipts[purchaseId] = nil
			cleaned += 1
		end
	end
	if cleaned > 0 then
		debugLog("RECEIPT", "Cleaned", cleaned, "old receipts")
	end
end

-- ============================================
-- CALLBACK MANAGEMENT
-- ============================================

--[[
    Daftarkan callback yang dipanggil saat pembelian diproses.
    @param name     string    Nama unik callback
    @param callback function  function(player, productId, amount, receiptInfo) -> bool
]]
function ProcessReceiptHandler:RegisterCallback(name, callback)
	if type(name) ~= "string" or type(callback) ~= "function" then
		warn("[RECEIPT] RegisterCallback: name harus string dan callback harus function")
		return false
	end
	registeredCallbacks[name] = callback
	debugLog("RECEIPT", "Registered callback:", name)
	return true
end

function ProcessReceiptHandler:UnregisterCallback(name)
	registeredCallbacks[name] = nil
	debugLog("RECEIPT", "Unregistered callback:", name)
end

function ProcessReceiptHandler:GetCallbackNames()
	local names = {}
	for name in pairs(registeredCallbacks) do
		table.insert(names, name)
	end
	return names
end

function ProcessReceiptHandler:IsInitialized()
	return initialized
end

-- ============================================
-- MAIN RECEIPT PROCESSOR
-- ============================================

function ProcessReceiptHandler:ProcessReceipt(receiptInfo)
	local userId    = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	debugLog("RECEIPT", "=== New Receipt ===")
	debugLog("RECEIPT", "UserId:", userId, "| ProductId:", productId, "| PurchaseId:", purchaseId)

	-- Idempotent: jika sudah diproses, langsung grant
	if isReceiptProcessed(purchaseId) then
		debugLog("RECEIPT", "Duplicate receipt, returning PurchaseGranted")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Cegah Roblox menjalankan fungsi 2x jika DataStore sedang ngelag
	if activeProcessing[purchaseId] then
		debugLog("RECEIPT", "Receipt sedang diproses thread lain, ditunda.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	activeProcessing[purchaseId] = true

	-- Cari player — jika tidak ada, Roblox akan mencoba lagi nanti
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		debugLog("ERROR", "Player tidak ditemukan, userId:", userId)
		activeProcessing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Cari harga produk dari config
	local amount = DonationConfig.PRODUCT_PRICES[productId]
	if not amount then
		-- Jangan return NotProcessedYet! Buang receipt agar antrean Roblox tidak nyangkut permanen.
		warn("[RECEIPT] Unknown productId:", productId, "- clearing invalid receipt to prevent deadlock!")
		activeProcessing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	debugLog("RECEIPT", "Player:", player.Name, "| Amount:", amount, "Robux")

	-- PRIORITAS: Jalankan DataStore pertama kali untuk Cek Idempotensi!
	local dataStoreCallback = registeredCallbacks["SaveToDataStore"]
	if dataStoreCallback then
		local ok, success, isNew = pcall(function()
			return dataStoreCallback(player, productId, amount, receiptInfo)
		end)
		
		if not ok or success ~= true then
			debugLog("ERROR", "SaveToDataStore gagal. Transaksi ditunda.")
			activeProcessing[purchaseId] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		
		-- Jika bukan receipt baru (sudah pernah sukses masuk DB), langsung GRANTED!
		if isNew == false then
			debugLog("RECEIPT", "Duplicate receipt di DataStore. Mengabaikan efek visual.")
			markReceiptProcessed(purchaseId)
			activeProcessing[purchaseId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- Jalankan sisa callback visual / broadcast
	local allSuccess = true
	for callbackName, callback in pairs(registeredCallbacks) do
		if callbackName == "SaveToDataStore" then continue end

		local ok, result = pcall(function()
			return callback(player, productId, amount, receiptInfo)
		end)
		if ok and result == true then
			debugLog("RECEIPT", "Callback OK:", callbackName)
		else
			debugLog("ERROR", "Callback FAILED:", callbackName)
			allSuccess = false
		end
	end

	if not allSuccess then
		debugLog("ERROR", "Satu atau lebih callback gagal. Transaksi ditunda.")
		activeProcessing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Tandai sudah diproses (setelah semua callback selesai)
	markReceiptProcessed(purchaseId)
	activeProcessing[purchaseId] = nil -- Lepas kunci thread

	debugLog("RECEIPT", "Receipt selesai diproses")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================
-- INITIALIZATION
-- ============================================

function ProcessReceiptHandler:Initialize()
	if initialized then
		warn("[RECEIPT] Initialize() sudah dipanggil sebelumnya — diabaikan untuk mencegah duplikasi.")
		return false
	end

	initialized = true

	-- Set satu-satunya ProcessReceipt callback
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:ProcessReceipt(receiptInfo)
	end

	-- Cleanup receipt cache secara berkala
	task.spawn(function()
		while true do
			task.wait(600)  -- setiap 10 menit
			cleanupOldReceipts()
		end
	end)

	debugLog("RECEIPT", "ProcessReceiptHandler initialized")
	debugLog("RECEIPT", "Environment:", DonationConfig.IS_TEST_MODE and "STUDIO" or "LIVE")
	debugLog("RECEIPT", "Security Tracking:", DonationConfig.SECURITY.TRACK_PURCHASES and "ON" or "OFF")
	return true
end

return ProcessReceiptHandler