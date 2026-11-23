--!strict

export type Route = {
	Points: { Vector3 },
	-- Distance along the route at each point, from the first point.
	Distances: { number },
	Length: number,
}

local Module = {}

function Module.new(points: { Vector3 }): Route
	local distances = { 0 }
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		table.insert(distances, total)
	end
	return {
		Points = points,
		Distances = distances,
		Length = total,
	}
end

--[[
	Returns how far along the route a point lies, measured at the route's
	closest spot to it, and how far the point is from that spot.
]]
function Module.project(route: Route, point: Vector3): (number, number)
	local bestProgress = 0
	local bestGap = math.huge
	for index = 1, #route.Points - 1 do
		local from = route.Points[index]
		local segment = route.Points[index + 1] - from
		local length = segment.Magnitude
		local along = if length > 0
			then math.clamp((point - from):Dot(segment) / length, 0, length)
			else 0
		local closest = if length > 0 then from + segment / length * along else from
		local gap = (point - closest).Magnitude
		if gap < bestGap then
			bestGap = gap
			bestProgress = route.Distances[index] + along
		end
	end
	return bestProgress, bestGap
end

--[[
	Returns the point a distance along the route, held to its ends.
]]
function Module.pointAt(route: Route, progress: number): Vector3
	local clamped = math.clamp(progress, 0, route.Length)
	for index = 1, #route.Points - 1 do
		local startDistance = route.Distances[index]
		local endDistance = route.Distances[index + 1]
		if clamped <= endDistance then
			local span = endDistance - startDistance
			local share = if span > 0 then (clamped - startDistance) / span else 0
			return route.Points[index]:Lerp(route.Points[index + 1], share)
		end
	end
	return route.Points[#route.Points]
end

return Module
