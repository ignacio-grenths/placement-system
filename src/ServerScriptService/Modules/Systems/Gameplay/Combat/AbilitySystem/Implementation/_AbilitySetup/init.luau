--!strict

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")

const AbilityServerService = require("../SystemPackage/AbilityServerService")

const AkaneKit = require("@self/_AkaneKit")
const BrakkKit = require("@self/_BrakkKit")
const HaruKit = require("@self/_HaruKit")
const KenjiKit = require("@self/_KenjiKit")
const MioKit = require("@self/_MioKit")
const Recall = require("@self/_Recall")
const RinKit = require("@self/_RinKit")
const RyukaKit = require("@self/_RyukaKit")
const SeoDanKit = require("@self/_SeoDanKit")
const SummonerSpells = require("@self/_SummonerSpells")
const TorvikKit = require("@self/_TorvikKit")
const Trinkets = require("@self/_Trinkets")
const YukiKit = require("@self/_YukiKit")

const KITS = {
	HaruKit,
	RyukaKit,
	TorvikKit,
	SeoDanKit,
	BrakkKit,
	AkaneKit,
	RinKit,
	YukiKit,
	KenjiKit,
	MioKit,
	SummonerSpells,
	Trinkets,
	Recall,
}

local Module = {}

function Module:Init()
	local handlers = {}
	for _, kit in KITS do
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
