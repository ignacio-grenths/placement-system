--!strict

-- Studs a path node sits beyond the clearance, so a path through it never
-- grazes the wall it rounds.
const NODE_MARGIN = 0.5
const EPSILON = 0.01
-- The four corners around a wall, as (along the wall, across it) signs.
const CORNERS = {
	Vector2.new(-1, -1),
	Vector2.new(-1, 1),
	Vector2.new(1, -1),
	Vector2.new(1, 1),
}

-- A wall: a thick line on the ground with round ends.
export type Wall = {
	From: Vector3,
	To: Vector3,
	-- Studs from the wall's center line to its face.
	Radius: number,
}

type Bounds = {
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}

export type Navigation = {
	Walls: { Wall },
	-- Each wall's footprint grown by Clearance, to skip far walls quickly.
	Bounds: { Bounds },
	-- Studs every path keeps from every wall's face.
	Clearance: number,
	-- Points just off each wall's corners that paths bend around.
	Nodes: { Vector3 },
	-- Links[i] lists the nodes reachable in a straight line from node i.
	Links: { { number } },
}

local Module = {}

local function flatten(point: Vector3): Vector3
	return Vector3.new(point.X, 0, point.Z)
end

local function closestOnSegment(point: Vector3, from: Vector3, to: Vector3): Vector3
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0 then
		return from
	end
	local share = math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
	return from + segment * share
end

-- Which side of the line through origin and a the point b lies on.
local function cross(origin: Vector3, a: Vector3, b: Vector3): number
	return (a.X - origin.X) * (b.Z - origin.Z) - (a.Z - origin.Z) * (b.X - origin.X)
end

local function segmentsCross(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3): boolean
	local d1 = cross(b1, b2, a1)
	local d2 = cross(b1, b2, a2)
	local d3 = cross(a1, a2, b1)
	local d4 = cross(a1, a2, b2)
	local isSplitByB = (d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)
	local isSplitByA = (d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)
	return isSplitByB and isSplitByA
end

local function segmentDistance(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3): number
	if segmentsCross(a1, a2, b1, b2) then
		return 0
	end
	return math.min(
		(a1 - closestOnSegment(a1, b1, b2)).Magnitude,
		(a2 - closestOnSegment(a2, b1, b2)).Magnitude,
		(b1 - closestOnSegment(b1, a1, a2)).Magnitude,
		(b2 - closestOnSegment(b2, a1, a2)).Magnitude
	)
end

local function getBounds(wall: Wall, grow: number): Bounds
	local reach = wall.Radius + grow
	return {
		MinX = math.min(wall.From.X, wall.To.X) - reach,
		MaxX = math.max(wall.From.X, wall.To.X) + reach,
		MinZ = math.min(wall.From.Z, wall.To.Z) - reach,
		MaxZ = math.max(wall.From.Z, wall.To.Z) + reach,
	}
end

local function overlapsBounds(from: Vector3, to: Vector3, bounds: Bounds): boolean
	return math.max(from.X, to.X) >= bounds.MinX
		and math.min(from.X, to.X) <= bounds.MaxX
		and math.max(from.Z, to.Z) >= bounds.MinZ
		and math.min(from.Z, to.Z) <= bounds.MaxZ
end

local function isInsideAny(navigation: Navigation, point: Vector3): boolean
	for _, wall in navigation.Walls do
		local closest = closestOnSegment(point, wall.From, wall.To)
		if (point - closest).Magnitude < wall.Radius + navigation.Clearance - EPSILON then
			return true
		end
	end
	return false
end

local function getAxes(wall: Wall): (Vector3, Vector3)
	local direction = wall.To - wall.From
	local axis = if direction.Magnitude > EPSILON then direction.Unit else Vector3.xAxis
	return axis, Vector3.new(-axis.Z, 0, axis.X)
end

--[[
	Builds the navigation for a set of walls: every path found with it keeps
	clearance studs from every wall's face.
]]
function Module.new(walls: { Wall }, clearance: number): Navigation
	local flatWalls: { Wall } = {}
	local bounds: { Bounds } = {}
	for _, wall in walls do
		local flatWall = {
			From = flatten(wall.From),
			To = flatten(wall.To),
			Radius = wall.Radius,
		}
		table.insert(flatWalls, flatWall)
		table.insert(bounds, getBounds(flatWall, clearance))
	end

	local navigation: Navigation = {
		Walls = flatWalls,
		Bounds = bounds,
		Clearance = clearance,
		Nodes = {},
		Links = {},
	}

	for _, wall in flatWalls do
		local axis, side = getAxes(wall)
		local offset = wall.Radius + clearance + NODE_MARGIN
		for _, corner in CORNERS do
			local base = if corner.X < 0 then wall.From else wall.To
			local node = base + axis * corner.X * offset + side * corner.Y * offset
			-- A corner tucked into another wall is no use to any path.
			if not isInsideAny(navigation, node) then
				table.insert(navigation.Nodes, node)
			end
		end
	end

	for index in navigation.Nodes do
		navigation.Links[index] = {}
	end
	for index, node in navigation.Nodes do
		for otherIndex = index + 1, #navigation.Nodes do
			if Module.isClear(navigation, node, navigation.Nodes[otherIndex]) then
				table.insert(navigation.Links[index], otherIndex)
				table.insert(navigation.Links[otherIndex], index)
			end
		end
	end
	return navigation
end

--[[
	Returns whether a straight walk between two points keeps the clearance
	from every wall.
]]
function Module.isClear(navigation: Navigation, from: Vector3, to: Vector3): boolean
	local start = flatten(from)
	local finish = flatten(to)
	for index, wall in navigation.Walls do
		if not overlapsBounds(start, finish, navigation.Bounds[index]) then
			continue
		end
		local distance = segmentDistance(start, finish, wall.From, wall.To)
		if distance < wall.Radius + navigation.Clearance - EPSILON then
			return false
		end
	end
	return true
end

--[[
	Returns the point moved out of every wall far enough that a unit of the
	given radius standing there no longer overlaps any. A point already clear
	comes back unchanged.
]]
function Module.pushOut(navigation: Navigation, point: Vector3, radius: number): Vector3
	local result = flatten(point)
	-- A second pass settles a point pushed from one wall into a neighbor.
	for _ = 1, 2 do
		for _, wall in navigation.Walls do
			local reach = wall.Radius + radius
			local closest = closestOnSegment(result, wall.From, wall.To)
			local offset = result - closest
			local distance = offset.Magnitude
			if distance < reach then
				local _, side = getAxes(wall)
				local direction = if distance > EPSILON then offset / distance else side
				result = closest + direction * reach
			end
		end
	end
	return result
end

--[[
	Returns the waypoints of the shortest path from one point to another
	that keeps the clearance from every wall, ending at the goal. A goal
	inside a wall's clearance is moved out of it first. When no path exists,
	the goal alone comes back, so the walker heads straight for it.
]]
function Module.findPath(navigation: Navigation, from: Vector3, to: Vector3): { Vector3 }
	-- Both ends sit just outside every wall's clearance, so the straight
	-- legs out of and into them can be tested like any other.
	local start = Module.pushOut(navigation, from, navigation.Clearance + EPSILON * 2)
	local goal = Module.pushOut(navigation, to, navigation.Clearance + EPSILON * 2)
	if Module.isClear(navigation, start, goal) then
		return { goal }
	end

	-- A* over the wall corners, with the straight-line distance to the goal
	-- as its estimate.
	local nodes = navigation.Nodes
	local costs: { number } = table.create(#nodes, math.huge)
	local previous: { number } = table.create(#nodes, 0)
	local isDone: { boolean } = table.create(#nodes, false)
	for index, node in nodes do
		if Module.isClear(navigation, start, node) then
			costs[index] = (node - start).Magnitude
		end
	end

	local bestTotal = math.huge
	local lastIndex = 0
	while true do
		local current = 0
		local currentScore = math.huge
		for index, node in nodes do
			local score = costs[index] + (goal - node).Magnitude
			if not isDone[index] and score < currentScore then
				current = index
				currentScore = score
			end
		end
		if current == 0 or currentScore >= bestTotal then
			break
		end

		isDone[current] = true
		local node = nodes[current]
		if Module.isClear(navigation, node, goal) then
			local total = costs[current] + (goal - node).Magnitude
			if total < bestTotal then
				bestTotal = total
				lastIndex = current
			end
		end
		for _, neighbor in navigation.Links[current] do
			local cost = costs[current] + (nodes[neighbor] - node).Magnitude
			if not isDone[neighbor] and cost < costs[neighbor] then
				costs[neighbor] = cost
				previous[neighbor] = current
			end
		end
	end

	if lastIndex == 0 then
		return { goal }
	end
	local path = { goal }
	local index = lastIndex
	while index ~= 0 do
		table.insert(path, 1, nodes[index])
		index = previous[index]
	end
	return path
end

return Module
