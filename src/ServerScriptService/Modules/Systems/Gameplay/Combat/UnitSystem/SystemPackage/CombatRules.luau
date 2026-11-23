--!strict

local Module = {}

--[[
	Returns the damage left after armor. Each point of armor adds 1% effective
	health, so 100 armor halves damage and no amount of armor ever blocks it
	all. Negative armor (from armor shred) raises damage, up to double.
]]
function Module.mitigateDamage(amount: number, armor: number): number
	if armor >= 0 then
		return amount * 100 / (100 + armor)
	end

	return amount * (2 - 100 / (100 - armor))
end

return Module
