--!strict

-- A patch of brush: a thick line on the ground with round ends, like a wall
-- that units walk through.
export type Brush = {
	From: Vector3,
	To: Vector3,
	-- Studs from the center line to the brush's edge.
	Radius: number,
}

export type Viewer = {
	Position: Vector3,
	-- Studs the viewer sees around it.
	Sight: number,
	-- Index of the brush the viewer stands in, or nil.
	Brush: number?,
}

local Module = {}

local function getDistanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	local share = if lengthSquared > 0
		then math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
		else 0
	return (point - (from + segment * share)).Magnitude
end

--[[
	Returns the index of the brush a position stands in, or nil.
]]
function Module.findBrush(brushes: { Brush }, position: Vector3): number?
	for index, brush in brushes do
		if getDistanceToSegment(position, brush.From, brush.To) <= brush.Radius then
			return index
		end
	end
	return nil
end

--[[
	Whether any viewer sees a spot. A spot in brush is seen only by viewers
	standing in that same brush.
]]
function Module.canSee(viewers: { Viewer }, position: Vector3, brush: number?): boolean
	for _, viewer in viewers do
		if
			(brush == nil or viewer.Brush == brush)
			and (viewer.Position - position).Magnitude <= viewer.Sight
		then
			return true
		end
	end
	return false
end

return Module
