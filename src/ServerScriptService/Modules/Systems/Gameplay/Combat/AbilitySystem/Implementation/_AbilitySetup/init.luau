--!strict

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")

const AbilityServerService = require("../SystemPackage/AbilityServerService")

const BrakkKit = require("@self/_BrakkKit")
const HaruKit = require("@self/_HaruKit")
const Recall = require("@self/_Recall")
const RyukaKit = require("@self/_RyukaKit")
const SeoDanKit = require("@self/_SeoDanKit")
const SummonerSpells = require("@self/_SummonerSpells")
const TorvikKit = require("@self/_TorvikKit")

local Module = {}

function Module:Init()
	local handlers = {}
	for _, kit in { HaruKit, RyukaKit, TorvikKit, SeoDanKit, BrakkKit, SummonerSpells, Recall } do
		for abilityId, handler in kit do
			handlers[abilityId] = handler
		end
	end

	for abilityId, entry in AbilityCatalog.Abilities do
		local handler = handlers[abilityId]
		if handler then
			AbilityServerService:RegisterAbility(abilityId, entry, handler)
		else
			warn(`Ability {abilityId} is in the catalog but has no handler`)
		end
	end
end

return Module
