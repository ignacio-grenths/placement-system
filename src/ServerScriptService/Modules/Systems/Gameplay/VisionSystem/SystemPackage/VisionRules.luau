--!strict

-- A patch of brush: a thick line on the ground with round ends, like a wall
-- that units walk through.
export type Brush = {
	From: Vector3,
	To: Vector3,
	-- Studs from the center line to the brush's edge.
	Radius: number,
}

-- A wall that blocks sight, the same shape as a patch of brush.
export type Wall = Brush

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

-- Twice the signed area of the triangle o, p, q on the ground plane: its
-- sign says which side of the line o-p the point q lies on.
local function getTurn(o: Vector3, p: Vector3, q: Vector3): number
	return (p.X - o.X) * (q.Z - o.Z) - (p.Z - o.Z) * (q.X - o.X)
end

local function doSegmentsCross(a: Vector3, b: Vector3, c: Vector3, d: Vector3): boolean
	local turnA = getTurn(c, d, a)
	local turnB = getTurn(c, d, b)
	local turnC = getTurn(a, b, c)
	local turnD = getTurn(a, b, d)
	return turnA * turnB < 0 and turnC * turnD < 0
end

local function getSegmentsDistance(a: Vector3, b: Vector3, c: Vector3, d: Vector3): number
	if doSegmentsCross(a, b, c, d) then
		return 0
	end
	return math.min(
		getDistanceToSegment(a, c, d),
		getDistanceToSegment(b, c, d),
		getDistanceToSegment(c, a, b),
		getDistanceToSegment(d, a, b)
	)
end

--[[
	Returns how far a spot is from a wall's center line, in studs.
]]
function Module.getDistanceToWall(position: Vector3, wall: Wall): number
	return getDistanceToSegment(position, wall.From, wall.To)
end

--[[
	Whether the straight line between two spots passes no wall.
]]
function Module.isLineClear(from: Vector3, to: Vector3, walls: { Wall }): boolean
	for _, wall in walls do
		if getSegmentsDistance(from, to, wall.From, wall.To) <= wall.Radius then
			return false
		end
	end
	return true
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
	standing in that same brush, and walls block the line between them.
]]
function Module.canSee(
	viewers: { Viewer },
	position: Vector3,
	brush: number?,
	walls: { Wall }?
): boolean
	for _, viewer in viewers do
		if
			(brush == nil or viewer.Brush == brush)
			and (viewer.Position - position).Magnitude <= viewer.Sight
			and (walls == nil or Module.isLineClear(viewer.Position, position, walls))
		then
			return true
		end
	end
	return false
end

return Module
