--!native
--!optimize 2

local module = {}

local SEPARATOR = "|"

local function finiteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

function module.encode(animationId, anchorTime, anchorPosition, speed, restartSeq, version)
	animationId = tostring(animationId or ""):gsub(SEPARATOR, "")
	anchorTime = finiteNumber(anchorTime) and anchorTime or 0
	anchorPosition = finiteNumber(anchorPosition) and math.max(0, anchorPosition) or 0
	speed = finiteNumber(speed) and math.clamp(speed, 0.1, 3) or 1
	restartSeq = math.max(0, math.floor(tonumber(restartSeq) or 0))
	version = math.max(0, math.floor(tonumber(version) or 0))

	return table.concat({
		animationId,
		string.format("%.6f", anchorTime),
		string.format("%.6f", anchorPosition),
		string.format("%.6f", speed),
		tostring(restartSeq),
		tostring(version),
	}, SEPARATOR)
end

function module.decode(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	local animationId, anchorTime, anchorPosition, speed, restartSeq, version =
		string.match(value, "^(.-)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")

	if not animationId or animationId == "" then
		return nil
	end

	anchorTime = tonumber(anchorTime)
	anchorPosition = tonumber(anchorPosition)
	speed = tonumber(speed)
	restartSeq = tonumber(restartSeq)
	version = tonumber(version)

	if not finiteNumber(anchorTime) or not finiteNumber(anchorPosition) or not finiteNumber(speed) then
		return nil
	end

	return {
		animationId = animationId,
		anchorTime = anchorTime,
		anchorPosition = math.max(0, anchorPosition),
		speed = math.clamp(speed, 0.1, 3),
		restartSeq = math.max(0, math.floor(restartSeq or 0)),
		version = math.max(0, math.floor(version or 0)),
	}
end

function module.normalizeId(animationId)
	if not animationId then
		return ""
	end
	return tostring(animationId):match("%d+") or tostring(animationId)
end

function module.positionAt(state, length, now, loops)
	if not state or not finiteNumber(length) or length <= 0 then
		return 0
	end

	now = finiteNumber(now) and now or workspace:GetServerTimeNow()
	local elapsed = now - state.anchorTime
	if elapsed < 0 then
		elapsed = 0
	end

	local position = state.anchorPosition + elapsed * state.speed
	if loops == false then
		return math.clamp(position, 0, length)
	end

	position = position % length
	if position < 0 then
		position += length
	end
	return position
end

function module.wrapDiff(diff, length)
	if not finiteNumber(length) or length <= 0 then
		return 0
	end

	diff = diff % length
	if diff > length / 2 then
		diff -= length
	end
	return diff
end

return module
