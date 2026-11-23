--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const ItemShopServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/ItemShopSystem/SystemPackage/ItemShopServerService"
)
const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const BotBuild = require("../SystemPackage/BotBuild")

-- Seconds between two shopping trips through every bot's build.
const SHOP_INTERVAL = 1

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

local upgradesOf: { [string]: string? } = {}
-- By hero id: every item a bot of that hero buys, in order.
local buildOrders: { [string]: { string } } = {}
local shopTimer = 0

--[[
	A bot buys its hero's suggested build first, then the costliest stat
	items it lacks until its bag is full. Potions are left to players.
]]
local function createBuildOrder(suggested: { string }): { string }
	local order = BotBuild.expand(suggested, upgradesOf)
	local extras = {}
	for itemId, item in ItemCatalog.Items do
		if item.Kind == "Stat" and not table.find(order, itemId) then
			table.insert(extras, itemId)
		end
	end
	table.sort(extras, function(first, second)
		return ItemCatalog.Items[first].Cost > ItemCatalog.Items[second].Cost
	end)
	table.move(extras, 1, #extras, #order + 1, order)
	return order
end

local function shop(hero: Unit)
	local order = buildOrders[hero.TypeId]
	if not order then
		return
	end
	-- Buy until the next item is out of reach, so a bot back at base with a
	-- pile of gold spends it all in one trip.
	while true do
		local inventory = ItemShopServerService:GetInventory(hero)
		local nextItem = BotBuild.getNextItem(inventory, order, upgradesOf)
		if not nextItem or not ItemShopServerService:Buy(hero, nextItem) then
			return
		end
	end
end

local function onStep(frameTime: number)
	shopTimer += frameTime
	if shopTimer < SHOP_INTERVAL then
		return
	end
	shopTimer = 0

	for _, unit in UnitServerService:GetUnits() do
		if unit.Kind == "Hero" and not unit.OwnerPlayer and not unit.IsRemoved then
			shop(unit)
		end
	end
end

function Module:Init()
	for itemId, item in ItemCatalog.Items do
		upgradesOf[itemId] = item.UpgradeOf
	end
	for heroId, hero in HeroCatalog.Heroes do
		buildOrders[heroId] = createBuildOrder(hero.SuggestedBuild)
	end
end

function Module:Start()
	SimClock.onStep(onStep)
end

return Module
