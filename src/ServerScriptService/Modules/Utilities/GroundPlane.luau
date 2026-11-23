--!strict

-- The arena is flat, and its ground surface sits at this height (studs).
const GROUND_HEIGHT = 0

local Module = {}

--[[
	Returns where a ray meets the ground, or nil when it points level or up.
]]
function Module.intersect(ray: Ray): Vector3?
	local direction = ray.Direction
	if direction.Y >= 0 then
		return nil
	end

	local distance = (GROUND_HEIGHT - ray.Origin.Y) / direction.Y
	return ray.Origin + direction * distance
end

return Module
