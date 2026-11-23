--!strict

local Module = {
	-- Client to server: (item id), buy that item.
	BuyRequest = script.BuyRequest,
	-- Client to server: (slot), use the consumable in that inventory slot.
	UseRequest = script.UseRequest,
	-- Server to one player: their inventory, one item id per slot and ""
	-- for an empty slot.
	InventoryChanged = script.InventoryChanged,
}

return Module
