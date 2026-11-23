--!strict

const Players = game:GetService("Players")

const GoldServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/GoldSystem/SystemPackage/GoldServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const ItemShopNetwork = require("./ItemShopNetwork")

-- Shop requests a client may send per second.
const REQUESTS_PER_SECOND = 8
-- Seconds between the heals of a consumable.
const HEAL_TICK = 0.5
const EMPTY_SLOT = ""

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type StatModifier = UnitTypes.StatModifier
type Unit = UnitTypes.Unit

export type ItemKind = "Stat" | "Boots" | "Consumable"

export type ItemDefinition = {
	Cost: number,
	Kind: ItemKind,
	Stats: { StatModifier },
	HealAmount: number?,
	HealDuration: number?,
}

local Module = {}

local items: { [string]: ItemDefinition? } = {}
local inventorySize = 6
local inventories: { [Player]: { string }? } = {}
local purchaseCheck: ((Player, Unit) -> boolean)? = nil
local lastRequestTimes: { [Player]: number? } = {}

local function getInventory(player: Player): { string }
	local inventory = inventories[player]
	if inventory then
		return inventory
	end
	local created = table.create(inventorySize, EMPTY_SLOT)
	inventories[player] = created
	return created
end

local function publish(player: Player)
	ItemShopNetwork.InventoryChanged:FireClient(player, table.clone(getInventory(player)))
end

local function getModifierKey(slot: number, index: number): string
	return `Item.{slot}.{index}`
end

local function applyItemStats(hero: Unit, slot: number, item: ItemDefinition)
	for index, modifier in item.Stats do
		UnitServerService:AddModifier(hero, getModifierKey(slot, index), modifier, math.huge)
	end
end

local function removeItemStats(hero: Unit, slot: number, item: ItemDefinition)
	for index in item.Stats do
		UnitServerService:RemoveModifier(hero, getModifierKey(slot, index))
	end
end

local function healOverTime(hero: Unit, amount: number, duration: number)
	local ticks = math.max(math.floor(duration / HEAL_TICK), 1)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(HEAL_TICK)
			if hero.IsDead or hero.IsRemoved then
				return
			end
			UnitServerService:Heal(hero, amount / ticks)
		end
	end)
end

local function isRequestAllowed(player: Player): boolean
	local now = os.clock()
	local last = lastRequestTimes[player]
	if last and now - last < 1 / REQUESTS_PER_SECOND then
		return false
	end
	lastRequestTimes[player] = now
	return true
end

local function onBuyRequest(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or not isRequestAllowed(player) then
		return
	end
	Module:Buy(player, itemId)
end

local function onUseRequest(player: Player, slot: unknown)
	if
		typeof(slot) ~= "number"
		or slot ~= math.floor(slot)
		or slot < 1
		or slot > inventorySize
		or not isRequestAllowed(player)
	then
		return
	end
	Module:Use(player, slot)
end

local function onPlayerAdded(player: Player)
	publish(player)
end

local function onPlayerRemoving(player: Player)
	inventories[player] = nil
	lastRequestTimes[player] = nil
end

function Module:RegisterItem(itemId: string, definition: ItemDefinition)
	items[itemId] = definition
end

function Module:SetInventorySize(size: number)
	inventorySize = size
end

--[[
	Sets where buying is allowed: the check gets the player and their living
	hero and returns whether they may buy there. A dead hero can always buy.
]]
function Module:SetPurchaseCheck(check: (Player, Unit) -> boolean)
	purchaseCheck = check
end

--[[
	Buys an item into the first empty slot. Returns false and a reason when
	the purchase can't happen, in which case no gold is spent.
]]
function Module:Buy(player: Player, itemId: string): (boolean, string?)
	local item = items[itemId]
	local hero = UnitServerService:FindOwnedHero(player)
	if not item or not hero then
		return false, "Unavailable"
	end
	if not hero.IsDead and purchaseCheck and not purchaseCheck(player, hero) then
		return false, "NotAtBase"
	end

	local inventory = getInventory(player)
	if item.Kind == "Boots" then
		for _, heldId in inventory do
			local held = items[heldId]
			if held and held.Kind == "Boots" then
				return false, "AlreadyOwned"
			end
		end
	end
	local slot = table.find(inventory, EMPTY_SLOT)
	if not slot then
		return false, "InventoryFull"
	end
	if not GoldServerService:TrySpend(player, item.Cost) then
		return false, "NotEnoughGold"
	end

	inventory[slot] = itemId
	applyItemStats(hero, slot, item)
	publish(player)
	return true, nil
end

--[[
	Uses the consumable in a slot, which removes it. Items that are not
	consumables can't be used.
]]
function Module:Use(player: Player, slot: number): boolean
	local inventory = getInventory(player)
	local item = items[inventory[slot]]
	local hero = UnitServerService:FindOwnedHero(player)
	if not item or item.Kind ~= "Consumable" or not hero or hero.IsDead then
		return false
	end

	inventory[slot] = EMPTY_SLOT
	removeItemStats(hero, slot, item)
	if item.HealAmount and item.HealDuration then
		healOverTime(hero, item.HealAmount, item.HealDuration)
	end
	publish(player)
	return true
end

function Module:Init()
	ItemShopNetwork.BuyRequest.OnServerEvent:Connect(onBuyRequest)
	ItemShopNetwork.UseRequest.OnServerEvent:Connect(onUseRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function Module:Start()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

return Module
