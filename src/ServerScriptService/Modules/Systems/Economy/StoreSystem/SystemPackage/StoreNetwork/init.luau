--!strict

local Module = {
	-- Each player's wallet sits on their Player as attributes: Coins (number)
	-- and OwnedItems (JSON array of item ids).
	CoinsAttribute = "Coins",
	OwnedItemsAttribute = "OwnedItems",
	-- Client to server: (item id), buy that item with coins.
	BuyWithCoins = script.BuyWithCoins,
}

return Module
