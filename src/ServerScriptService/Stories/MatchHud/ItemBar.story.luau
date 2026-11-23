--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const ItemBar = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/ItemBar"
)
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")

const source = Vide.source

const CONTROLS = {
	Items = UILabs.Ordered(
		UILabs.ControlGroup({
			-- How many slots hold an item, filled in shop order.
			HeldItems = UILabs.Ordered(UILabs.Slider(3, 0, 6, 1), 1),
			Gold = UILabs.Ordered(UILabs.Slider(1350, 0, 9999, 50), 2),
		}),
		1
	),
}

type StoryProps = {
	controls: {
		Items: {
			HeldItems: () -> number,
			Gold: () -> number,
		},
	},
	target: Frame,
}

-- Catalog items in shop order, so a renamed item still shows.
local function getItemsInOrder(): { ItemCatalog.ItemEntry }
	local entries = {}
	for _, entry in ItemCatalog.Items do
		table.insert(entries, entry)
	end
	table.sort(entries, function(first, second)
		return first.Order < second.Order
	end)
	return entries
end

local function story(props: StoryProps)
	local controls = props.controls.Items
	local ordered = getItemsInOrder()
	local isAutoRanking = source(false)

	local function items(): { ItemBar.ItemSlotView }
		local slots = {}
		for slot = 1, ItemCatalog.InventorySize do
			local entry = if slot <= controls.HeldItems() then ordered[slot] else nil
			table.insert(slots, {
				Name = if entry then entry.Name else "",
				IsEmpty = entry == nil,
				IsConsumable = entry ~= nil and entry.Kind == "Consumable",
				KeyLabel = tostring(slot),
			})
		end
		return slots
	end

	return ItemBar({
		Items = items,
		Gold = controls.Gold,
		IsAutoRanking = isAutoRanking,
		OnUse = function(slot: number)
			print(`Use slot {slot}`)
		end,
		OnShopPressed = function()
			print("Shop pressed")
		end,
		OnAutoRankPressed = function()
			isAutoRanking(not isAutoRanking())
		end,
	})
end

return {
	summary = "Gold, the six item slots with a consumable first, the Shop button, and the auto ranks switch.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
