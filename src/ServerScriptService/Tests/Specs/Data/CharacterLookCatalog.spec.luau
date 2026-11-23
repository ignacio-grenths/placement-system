--!strict

const JestGlobals = require("@game/ServerScriptService/Tests/Packages/JestGlobals")
const describe = JestGlobals.describe
const expect = JestGlobals.expect
const it = JestGlobals.it

const CharacterLookCatalog = require("@game/ServerScriptService/Modules/Data/CharacterLookCatalog")
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

describe("CharacterLookCatalog", function()
	it("gives every hero a look", function()
		local missing = {}
		for heroId in HeroCatalog.Heroes do
			if not CharacterLookCatalog.Looks[heroId] then
				table.insert(missing, heroId)
			end
		end

		expect(missing).toEqual({})
	end)
end)
