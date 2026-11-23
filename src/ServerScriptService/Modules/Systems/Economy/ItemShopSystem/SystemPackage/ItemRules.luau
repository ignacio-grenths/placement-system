--!strict

export type Pair = {
	Id: string,
	Items: { string },
}

local Module = {}

local function holdsAll(inventory: { string }, itemIds: { string }): boolean
	for _, itemId in itemIds do
		if not table.find(inventory, itemId) then
			return false
		end
	end
	return true
end

--[[
	Returns the pair bonus an inventory earns, or nil. The current bonus stays
	while its pair is still held, so completing a second pair never swaps it;
	otherwise the first complete pair in the list is the one that counts.
]]
function Module.getActivePair(inventory: { string }, itemPairs: { Pair }, current: string?): string?
	if current then
		for _, pair in itemPairs do
			if pair.Id == current and holdsAll(inventory, pair.Items) then
				return current
			end
		end
	end
	for _, pair in itemPairs do
		if holdsAll(inventory, pair.Items) then
			return pair.Id
		end
	end
	return nil
end

return Module
