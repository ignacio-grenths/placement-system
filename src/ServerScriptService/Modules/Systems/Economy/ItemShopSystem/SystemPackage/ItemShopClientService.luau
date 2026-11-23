--!strict

const UserInputService = game:GetService("UserInputService")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const ItemShopNetwork = require("./ItemShopNetwork")

-- The number keys use the item in that inventory slot.
const USE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
}

local Module = {}

Module.InventoryChanged = Signal.new() :: Signal.Signal<>

-- One item id per slot, "" for an empty slot.
local inventory: { string } = {}

local function onInventoryChanged(newInventory: { string })
	inventory = newInventory
	Module.InventoryChanged:Fire()
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end
	local slot = USE_KEYS[input.KeyCode]
	if slot then
		Module:RequestUse(slot)
	end
end

--[[
	Returns the local player's items, one id per slot and "" for an empty
	slot. Read it; never change it.
]]
function Module:GetInventory(): { string }
	return inventory
end

function Module:RequestBuy(itemId: string)
	ItemShopNetwork.BuyRequest:FireServer(itemId)
end

function Module:RequestUse(slot: number)
	ItemShopNetwork.UseRequest:FireServer(slot)
end

function Module:Init()
	ItemShopNetwork.InventoryChanged.OnClientEvent:Connect(onInventoryChanged)
end

function Module:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return Module
