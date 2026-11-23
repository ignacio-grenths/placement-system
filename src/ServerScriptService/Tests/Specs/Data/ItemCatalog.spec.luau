--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")

describe("ItemCatalog", function()
	it("links every pair and upgrade to items that exist and agree", function()
		local broken = {}
		for pairId, pair in ItemCatalog.PairBonuses do
			for _, itemId in pair.Items do
				local item = ItemCatalog.Items[itemId]
				if not item then
					table.insert(broken, `{pairId} names missing item {itemId}`)
				elseif item.Pair ~= pairId then
					table.insert(broken, `{itemId} is in {pairId} but names {item.Pair}`)
				end
			end
		end
		for itemId, item in ItemCatalog.Items do
			local pairId = item.Pair
			if pairId and not ItemCatalog.PairBonuses[pairId] then
				table.insert(broken, `{itemId} names missing pair {pairId}`)
			end
			local upgradeOf = item.UpgradeOf
			if upgradeOf and not ItemCatalog.Items[upgradeOf] then
				table.insert(broken, `{itemId} upgrades missing item {upgradeOf}`)
			end
		end

		expect(broken).toEqual({})
	end)

	it("suggests only items the shop sells", function()
		local missing = {}
		for heroId, hero in HeroCatalog.Heroes do
			for _, itemId in hero.SuggestedBuild do
				if not ItemCatalog.Items[itemId] then
					table.insert(missing, `{heroId} suggests {itemId}`)
				end
			end
		end

		expect(missing).toEqual({})
	end)
end)
