--!strict
-- ============================================================
-- CarryState (Server Module)
-- Manages in-memory state, sessions, and pending requests for Carry System
-- ============================================================

local Players = game:GetService("Players")

export type PendingRequest = {
	carrier: Player,
	style: string,
	time: number,
}

local CarryState = {}

local pendingRequests: { [number]: PendingRequest } = {}
local activeCarries: { [number]: number } = {} -- bidirectional: [userId] = partnerUserId

function CarryState.setPending(targetUserId: number, carrier: Player, style: string)
	pendingRequests[targetUserId] = {
		carrier = carrier,
		style = style,
		time = os.clock(),
	}
end

function CarryState.getPending(targetUserId: number): PendingRequest?
	return pendingRequests[targetUserId]
end

function CarryState.removePending(targetUserId: number)
	pendingRequests[targetUserId] = nil
end

function CarryState.clearPendingForCarrier(carrierUserId: number, onTargetCancelled: ((target: Player) -> ())?)
	for targetId, data in pairs(pendingRequests) do
		if data.carrier and data.carrier.UserId == carrierUserId then
			local target = Players:GetPlayerByUserId(targetId)
			if target and onTargetCancelled then
				onTargetCancelled(target)
			end
			pendingRequests[targetId] = nil
		end
	end
end

function CarryState.cleanupExpiredRequests(timeout: number, onExpired: (targetId: number, req: PendingRequest) -> ())
	local now = os.clock()
	for targetId, data in pairs(pendingRequests) do
		if now - data.time > timeout then
			onExpired(targetId, data)
			pendingRequests[targetId] = nil
		end
	end
end

function CarryState.setActiveCarry(userId1: number, userId2: number)
	activeCarries[userId1] = userId2
	activeCarries[userId2] = userId1
end

function CarryState.getActivePartner(userId: number): number?
	return activeCarries[userId]
end

function CarryState.clearActiveCarry(userId: number): number?
	local partnerId = activeCarries[userId]
	activeCarries[userId] = nil
	if partnerId then
		activeCarries[partnerId] = nil
	end
	return partnerId
end

function CarryState.isInCarry(character: Model?): boolean
	if not character then return false end
	local carryable = character:FindFirstChild("Carryable") :: BoolValue?
	return carryable ~= nil and carryable.Value == false
end

function CarryState.canAcceptRequest(player: Player): boolean
	local flag = player:FindFirstChild("CanAskCarry") :: BoolValue?
	return flag ~= nil and flag.Value == true
end

return CarryState
