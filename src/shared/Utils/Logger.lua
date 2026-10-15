--!strict
-- ============================================================
-- Logger (ClubKit Shared Utility)
-- Standardized, level-based logger with tag prefixing
-- ============================================================

local RunService = game:GetService("RunService")

export type LoggerInstance = {
	prefix: string,
	debugEnabled: boolean,
	SetDebug: (self: LoggerInstance, enabled: boolean) -> (),
	Debug: (self: LoggerInstance, ...any) -> (),
	Info: (self: LoggerInstance, ...any) -> (),
	Success: (self: LoggerInstance, ...any) -> (),
	Warn: (self: LoggerInstance, ...any) -> (),
	Error: (self: LoggerInstance, ...any) -> (),
	Transaction: (self: LoggerInstance, ...any) -> (),
}

local Logger = {}
Logger.__index = Logger

function Logger.new(prefix: string, isDebugEnabled: boolean?): LoggerInstance
	local self = setmetatable({}, Logger)
	self.prefix = prefix or "ClubKit"
	self.debugEnabled = if isDebugEnabled ~= nil then isDebugEnabled else RunService:IsStudio()
	return (self :: any) :: LoggerInstance
end

function Logger:SetDebug(enabled: boolean)
	self.debugEnabled = enabled
end

function Logger:Debug(...: any)
	if self.debugEnabled then
		print(string.format("[%s] 🔍", self.prefix), ...)
	end
end

function Logger:Info(...: any)
	if self.debugEnabled then
		print(string.format("[%s] ℹ️", self.prefix), ...)
	end
end

function Logger:Success(...: any)
	if self.debugEnabled then
		print(string.format("[%s] ✅", self.prefix), ...)
	end
end

function Logger:Transaction(...: any)
	if self.debugEnabled then
		print(string.format("[%s] 💰", self.prefix), ...)
	end
end

function Logger:Warn(...: any)
	warn(string.format("[%s] ⚠️", self.prefix), ...)
end

function Logger:Error(...: any)
	warn(string.format("[%s] ❌", self.prefix), ...)
end

-- Default fallback instance
local defaultLogger = Logger.new("ClubKit")
return setmetatable(Logger, {
	__index = defaultLogger,
})
