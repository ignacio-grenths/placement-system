--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const StoreNetwork = require("./StoreNetwork")

local Module = {}

-- Fires when the local player's coins or owned items change.
Module.WalletChanged = Signal.new() :: Signal.Signal<>

function Module:GetCoins(): number
	local coins = Players.LocalPlayer:GetAttribute(StoreNetwork.CoinsAttribute)
	return if typeof(coins) == "number" then coins else 0
end

function Module:GetOwnedItems(): { [string]: boolean? }
	local encoded = Players.LocalPlayer:GetAttribute(StoreNetwork.OwnedItemsAttribute)
	local owned: { [string]: boolean? } = {}
	if typeof(encoded) == "string" and encoded ~= "" then
		for _, itemId in HttpService:JSONDecode(encoded) do
			owned[itemId] = true
		end
	end
	return owned
end

--[[
	Asks the server to buy the item with coins. The wallet changes, and
	WalletChanged fires, only if the server agrees.
]]
function Module:BuyWithCoins(itemId: string)
	StoreNetwork.BuyWithCoins:FireServer(itemId)
end

function Module:Init()
	for _, attribute in { StoreNetwork.CoinsAttribute, StoreNetwork.OwnedItemsAttribute } do
		Players.LocalPlayer:GetAttributeChangedSignal(attribute):Connect(function()
			Module.WalletChanged:Fire()
		end)
	end
end

return Module
