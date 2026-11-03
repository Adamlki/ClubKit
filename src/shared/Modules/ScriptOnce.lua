--!optimize 2

-- Singleton guard berbasis module cache, pengganti _G.__<Script>Loaded.
local ScriptOnce = {}
local claimed = {}

function ScriptOnce.Claim(name: string): boolean
	if type(name) ~= "string" or name == "" then
		return false
	end
	if claimed[name] then
		return false
	end
	claimed[name] = true
	return true
end

function ScriptOnce.IsClaimed(name: string): boolean
	return claimed[name] == true
end

return ScriptOnce
