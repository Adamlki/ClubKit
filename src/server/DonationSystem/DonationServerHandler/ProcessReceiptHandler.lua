local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local DonationConfig     = require(script.Parent.DonationConfig)

local ProcessReceiptHandler = {}

-- STATE
local initialized        = false
local registeredCallbacks = {}
local processedReceipts  = {} 
local activeProcessing   = {}
local warnedPriceMismatch = {}

-- HELPER
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

-- CALLBACK MANAGEMENT

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

-- MAIN RECEIPT PROCESSOR

function ProcessReceiptHandler:ProcessReceipt(receiptInfo)
	local userId    = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	debugLog("RECEIPT", "=== New Receipt ===")
	debugLog("RECEIPT", "UserId:", userId, "| ProductId:", productId, "| PurchaseId:", purchaseId)

	if isReceiptProcessed(purchaseId) then
		debugLog("RECEIPT", "Duplicate receipt, returning PurchaseGranted")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if activeProcessing[purchaseId] then
		debugLog("RECEIPT", "Receipt sedang diproses thread lain, ditunda.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	activeProcessing[purchaseId] = true

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		debugLog("ERROR", "Player tidak ditemukan, userId:", userId)
		activeProcessing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local configuredAmount = DonationConfig.PRODUCT_PRICES[productId]
	if not configuredAmount then
		local giftCallback = registeredCallbacks["GiftSystem"]
		if giftCallback then
			local ok, success = pcall(function()
				return giftCallback(player, productId, 0, receiptInfo)
			end)
			if not ok then
				warn("[RECEIPT] ❌ GiftSystem callback error:", tostring(success))
				activeProcessing[purchaseId] = nil
				return Enum.ProductPurchaseDecision.NotProcessedYet
			elseif success == true then
				markReceiptProcessed(purchaseId)
				activeProcessing[purchaseId] = nil
				return Enum.ProductPurchaseDecision.PurchaseGranted
			elseif success == false then
				activeProcessing[purchaseId] = nil
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end

		warn("[RECEIPT] ⚠️ UNKNOWN productId:", productId,
			"| userId:", userId,
			"| purchaseId:", tostring(purchaseId),
			"| Reward TIDAK diberikan, receipt DITAHAN (NotProcessedYet). Cek config produk!")
		activeProcessing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local spent = tonumber(receiptInfo.CurrencySpent)
	local amount = (spent and spent > 0) and spent or configuredAmount

	if spent and spent > 0 and spent ~= configuredAmount and not warnedPriceMismatch[productId] then
		warnedPriceMismatch[productId] = true
		warn(string.format(
			"[RECEIPT] ⚠️ Harga produk %d beda dengan config: aktual=%s, config=%s. Memakai nominal aktual.",
			productId, tostring(spent), tostring(configuredAmount)
		))
	end

	debugLog("RECEIPT", "Player:", player.Name, "| Amount:", amount, "Robux")

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
		
		if isNew == false then
			debugLog("RECEIPT", "Duplicate receipt di DataStore. Mengabaikan efek visual.")
			markReceiptProcessed(purchaseId)
			activeProcessing[purchaseId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	for callbackName, callback in pairs(registeredCallbacks) do
		if callbackName == "SaveToDataStore" then continue end

		task.spawn(function()
			local ok, result = pcall(function()
				return callback(player, productId, amount, receiptInfo)
			end)
			if ok and result == true then
				debugLog("RECEIPT", "Callback OK:", callbackName)
			else
				debugLog("ERROR", "Callback non-fatal failed:", callbackName, result)
			end
		end)
	end

	markReceiptProcessed(purchaseId)
	activeProcessing[purchaseId] = nil

	debugLog("RECEIPT", "Receipt selesai diproses dan diberikan PurchaseGranted")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- INITIALIZATION

function ProcessReceiptHandler:Initialize()
	if initialized then
		warn("[RECEIPT] Initialize() sudah dipanggil sebelumnya — diabaikan untuk mencegah duplikasi.")
		return false
	end

	initialized = true

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:ProcessReceipt(receiptInfo)
	end

	task.spawn(function()
		while true do
			task.wait(600)
			cleanupOldReceipts()
		end
	end)

	debugLog("RECEIPT", "ProcessReceiptHandler initialized")
	debugLog("RECEIPT", "Environment:", DonationConfig.IS_TEST_MODE and "STUDIO" or "LIVE")
	debugLog("RECEIPT", "Security Tracking:", DonationConfig.SECURITY.TRACK_PURCHASES and "ON" or "OFF")
	return true
end

return ProcessReceiptHandler
