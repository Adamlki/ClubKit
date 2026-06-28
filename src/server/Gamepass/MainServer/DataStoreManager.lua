-- ====================================
-- DATASTORE MANAGER
-- ====================================
local Logger = require(script.Parent.Logger)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local DataStoreManager = {}
DataStoreManager.FailedGivesStore = DataStoreService:GetDataStore("FailedGives_v1")
DataStoreManager.TransactionLogStore = DataStoreService:GetDataStore("TransactionLog_v1")

-- Tambahkan variabel ini di atas
local transactionQueue = {}
local isSaving = false

local function processQueue()
	if isSaving then return end
	isSaving = true
	while #transactionQueue > 0 do
		local taskData = table.remove(transactionQueue, 1)
		taskData.retries = taskData.retries or 0
		
		local success = pcall(function()
			-- 🔥 ARCHITECT FIX: Tambahkan GUID agar key tidak tertimpa di detik yang sama
			local uniqueId = string.sub(HttpService:GenerateGUID(false), 1, 8)
			local key = "log_" .. os.time() .. "_" .. tostring(taskData.giver) .. "_" .. uniqueId
			DataStoreManager.TransactionLogStore:SetAsync(key, taskData)
		end)

		if not success then
			taskData.retries += 1
			if taskData.retries < 3 then
				Logger:Warn("Failed to log transaction, retrying later... (Attempt " .. taskData.retries .. ")")
				table.insert(transactionQueue, taskData) -- Masukkan balik jika gagal
			else
				Logger:Warn("Failed to log transaction completely after 3 retries. Dropping data to prevent infinite loop.")
			end
		end

		task.wait(1) -- ?? JEDA AMAN agar tidak terkena Error 429
	end
	isSaving = false
end

function DataStoreManager:LogTransaction(data)
	table.insert(transactionQueue, data)
	task.spawn(processQueue)
end

function DataStoreManager:LogFailedGive(giverUserId, targetUserId, targetName, gamepassType, reason)
	local success = pcall(function()
		-- 🔥 ARCHITECT FIX: Gunakan GUID untuk kunci gagal agar log tidak tertimpa
		local uniqueId = string.sub(HttpService:GenerateGUID(false), 1, 8)
		local key = "failed_" .. giverUserId .. "_" .. os.time() .. "_" .. uniqueId
		local data = {
			giver = giverUserId,
			target = targetUserId,
			targetName = targetName,
			gamepassType = gamepassType,
			reason = reason,
			timestamp = os.time(),
			canRetry = true
		}

		self.FailedGivesStore:SetAsync(key, data) -- 30 days expiry comment preserved

		Logger:Transaction(string.format("Logged failed give: %s -> %s (%s) Reason: %s", 
			giverUserId, targetName, gamepassType, reason))
	end)

	if not success then
		Logger:Warn("Failed to save failed give log")
	end
end

function DataStoreManager:LogExpiredTransaction(transactionId, data)
	Logger:Info(string.format("Transaction expired: %s (Giver: %d, Target: %d, Type: %s)",
		transactionId, data.giver, data.target, data.gamepassType))

	self:LogTransaction({
		type = "expired",
		giver = data.giver,
		target = data.target,
		gamepassType = data.gamepassType,
		timestamp = os.time()
	})
end

-- 🔥 ARCHITECT FIX: PEMBERSIHAN ANTREAN SAAT SERVER SHUTDOWN (Mencegah Kehilangan Transaksi)
game:BindToClose(function()
	if #transactionQueue > 0 then
		Logger:Warn("Server shutting down! Flushing " .. #transactionQueue .. " transactions to DataStore...")
		
		local HttpService = game:GetService("HttpService")
		
		for i, taskData in ipairs(transactionQueue) do
			local ok = pcall(function()
				local uniqueId = string.sub(HttpService:GenerateGUID(false), 1, 8)
				local key = "log_" .. os.time() .. "_" .. tostring(taskData.giver) .. "_" .. uniqueId
				DataStoreManager.TransactionLogStore:SetAsync(key, taskData)
			end)
			
			task.wait(0.2)
		end
		
		task.wait(3)
	end
end)

return DataStoreManager