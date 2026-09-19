-- ====================================
-- UI ANIMATOR (INSTANT / NO ANIMATION)
-- ====================================
local UIAnimator = {}

function UIAnimator.Open(frame)
	if not frame then return end
	frame.Visible = true

	local uiScale = frame:FindFirstChild("PopUpScale")
	if uiScale then
		uiScale.Scale = 1
	end
end

function UIAnimator.Close(frame, callback)
	if not frame then return end
	frame.Visible = false

	local uiScale = frame:FindFirstChild("PopUpScale")
	if uiScale then
		uiScale.Scale = 1
	end

	if callback then
		task.spawn(callback)
	end
end

return UIAnimator
