--!strict

--[[
	Ends an if chain that must handle every member of a string-literal union.
	A member the chain misses reaches this call as a type other than never,
	and the type checker reports it.
]]
local function exhaustiveMatch(value: never): never
	error(`Unhandled enum value: {value}`)
end

return exhaustiveMatch
