--!strict

local Module = {}

--[[
	Returns the build with each upgrade's base item placed just before it,
	since an upgrade can only be bought over its base.
]]
function Module.expand(build: { string }, upgradesOf: { [string]: string? }): { string }
	local order = {}
	for _, itemId in build do
		local base = upgradesOf[itemId]
		if base and not table.find(order, base) then
			table.insert(order, base)
		end
		if not table.find(order, itemId) then
			table.insert(order, itemId)
		end
	end
	return order
end

--[[
	Returns the first item in the order the bag still lacks, or nil once the
	build is done. An item counts as had when it is held or when an upgrade
	of it is.
]]
function Module.getNextItem(
	inventory: { string },
	order: { string },
	upgradesOf: { [string]: string? }
): string?
	for _, itemId in order do
		if table.find(inventory, itemId) then
			continue
		end
		local isUpgraded = false
		for _, heldId in inventory do
			if upgradesOf[heldId] == itemId then
				isUpgraded = true
				break
			end
		end
		if not isUpgraded then
			return itemId
		end
	end
	return nil
end

return Module
