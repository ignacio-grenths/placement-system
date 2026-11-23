--!strict

const Players = game:GetService("Players")

const GoldServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/GoldSystem/SystemPackage/GoldServerService"
)
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
local inventories: { [Player]: { string }? } = {}
local activePairs: { [Player]: string? } = {}
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
	ItemShopNetwork.InventoryChanged:FireClient(
		player,
		table.clone(getInventory(player)),
		activePairs[player] or ""
	)
end

local function updateActivePair(player: Player)
	activePairs[player] =
		ItemRules.getActivePair(getInventory(player), itemPairs, activePairs[player])
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
	activePairs[player] = nil
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
	Returns the player's items, one id per slot and "" for an empty slot.
]]
function Module:GetInventory(player: Player): { string }
	return table.clone(getInventory(player))
end

--[[
	Returns the id of the player's active pair bonus, or nil.
]]
function Module:GetActivePair(player: Player): string?
	return activePairs[player]
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
	local slot, reason = findSlotFor(inventory, item)
	if not slot then
		return false, reason
	end
	if not GoldServerService:TrySpend(player, item.Cost) then
		return false, "NotEnoughGold"
	end

	local replaced = items[inventory[slot]]
	if replaced then
		removeItemStats(hero, slot, replaced)
	end
	inventory[slot] = itemId
	applyItemStats(hero, slot, item)
	updateActivePair(player)
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
	updateActivePair(player)
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
