--!strict

const Players = game:GetService("Players")

const GoldServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/GoldSystem/SystemPackage/GoldServerService"
)
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const ItemRules = require("./ItemRules")
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
	-- The item this one replaces when bought, which must be held.
	UpgradeOf: string?,
}

local Module = {}

local items: { [string]: ItemDefinition? } = {}
local itemPairs: { ItemRules.Pair } = {}
local inventorySize = 6
-- Items belong to a hero, so bots shop the same way players do.
local inventories: { [Unit]: { string }? } = {}
local activePairs: { [Unit]: string? } = {}
local purchaseCheck: ((Unit) -> boolean)? = nil
local lastRequestTimes: { [Player]: number? } = {}

local function getInventory(hero: Unit): { string }
	local inventory = inventories[hero]
	if inventory then
		return inventory
	end
	local created = table.create(inventorySize, EMPTY_SLOT)
	inventories[hero] = created
	return created
end

local function publish(hero: Unit)
	local player = hero.OwnerPlayer
	if player then
		ItemShopNetwork.InventoryChanged:FireClient(
			player,
			table.clone(getInventory(hero)),
			activePairs[hero] or ""
		)
	end
end

local function updateActivePair(hero: Unit)
	activePairs[hero] = ItemRules.getActivePair(getInventory(hero), itemPairs, activePairs[hero])
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
			SimClock.wait(HEAL_TICK)
			if hero.IsDead or hero.IsRemoved then
				return
			end
			UnitServerService:Heal(hero, amount / ticks)
		end
	end)
end

local function isRequestAllowed(player: Player): boolean
	-- Requests arrive in real time, whatever speed the simulation runs at.
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
	local hero = UnitServerService:FindOwnedHero(player)
	if hero then
		Module:Buy(hero, itemId)
	end
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
	local hero = UnitServerService:FindOwnedHero(player)
	if hero then
		Module:Use(hero, slot)
	end
end

local function onPlayerRemoving(player: Player)
	lastRequestTimes[player] = nil
end

function Module:RegisterItem(itemId: string, definition: ItemDefinition)
	items[itemId] = definition
end

--[[
	Adds a pair: holding all of its items earns its bonus. When a hero
	completes two pairs at once, the one registered first wins.
]]
function Module:RegisterPair(pairId: string, itemIds: { string })
	table.insert(itemPairs, {
		Id = pairId,
		Items = table.clone(itemIds),
	})
end

--[[
	Gives a hero its empty inventory and shows it to the hero's player.
]]
function Module:OpenInventory(hero: Unit)
	getInventory(hero)
	publish(hero)
end

function Module:CloseInventory(hero: Unit)
	inventories[hero] = nil
	activePairs[hero] = nil
end

--[[
	Returns the hero's items, one id per slot and "" for an empty slot.
]]
function Module:GetInventory(hero: Unit): { string }
	local inventory = inventories[hero]
	return if inventory then table.clone(inventory) else table.create(inventorySize, EMPTY_SLOT)
end

--[[
	Whether the hero holds the item. Cheaper than GetInventory, for checks
	that run on every hit.
]]
function Module:Holds(hero: Unit, itemId: string): boolean
	local inventory = inventories[hero]
	return inventory ~= nil and table.find(inventory, itemId) ~= nil
end

--[[
	Returns the id of the hero's active pair bonus, or nil.
]]
function Module:GetActivePair(hero: Unit): string?
	return activePairs[hero]
end

function Module:GetItem(itemId: string): ItemDefinition?
	return items[itemId]
end

function Module:SetInventorySize(size: number)
	inventorySize = size
end

--[[
	Sets where buying is allowed: the check gets a living hero and returns
	whether it may buy where it stands. A dead hero can always buy.
]]
function Module:SetPurchaseCheck(check: (Unit) -> boolean)
	purchaseCheck = check
end

--[[
	Returns the slot a purchase goes into: the item it upgrades, or the first
	empty slot. Returns nil and a reason when there is none.
]]
local function findSlotFor(inventory: { string }, item: ItemDefinition): (number?, string?)
	local upgradeOf = item.UpgradeOf
	if upgradeOf then
		local slot = table.find(inventory, upgradeOf)
		return slot, if slot then nil else "NeedsBaseItem"
	end
	if item.Kind == "Boots" then
		for _, heldId in inventory do
			local held = items[heldId]
			if held and held.Kind == "Boots" then
				return nil, "AlreadyOwned"
			end
		end
	end
	local slot = table.find(inventory, EMPTY_SLOT)
	return slot, if slot then nil else "InventoryFull"
end

--[[
	Buys an item into the first empty slot, or over the item it upgrades.
	Returns false and a reason when the purchase can't happen, in which case
	no gold is spent.
]]
function Module:Buy(hero: Unit, itemId: string): (boolean, string?)
	local item = items[itemId]
	if not item or hero.IsRemoved then
		return false, "Unavailable"
	end
	if not hero.IsDead and purchaseCheck and not purchaseCheck(hero) then
		return false, "NotAtBase"
	end

	local inventory = getInventory(hero)
	local slot, reason = findSlotFor(inventory, item)
	if not slot then
		return false, reason
	end
	if not GoldServerService:TrySpend(hero, item.Cost) then
		return false, "NotEnoughGold"
	end

	local replaced = items[inventory[slot]]
	if replaced then
		removeItemStats(hero, slot, replaced)
	end
	inventory[slot] = itemId
	applyItemStats(hero, slot, item)
	updateActivePair(hero)
	publish(hero)
	return true, nil
end

--[[
	Uses the consumable in a slot, which removes it. Items that are not
	consumables can't be used.
]]
function Module:Use(hero: Unit, slot: number): boolean
	local inventory = getInventory(hero)
	local item = items[inventory[slot]]
	if not item or item.Kind ~= "Consumable" or hero.IsDead then
		return false
	end

	inventory[slot] = EMPTY_SLOT
	removeItemStats(hero, slot, item)
	if item.HealAmount and item.HealDuration then
		healOverTime(hero, item.HealAmount, item.HealDuration)
	end
	updateActivePair(hero)
	publish(hero)
	return true
end

function Module:Init()
	ItemShopNetwork.BuyRequest.OnServerEvent:Connect(onBuyRequest)
	ItemShopNetwork.UseRequest.OnServerEvent:Connect(onUseRequest)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Module
