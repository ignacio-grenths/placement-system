--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

const MatchServerService = require("../SystemPackage/MatchServerService")

-- Milestone 1 ships two heroes with kits for players. Bots play every role,
-- the other three heroes with basic attacks only until milestone 2.
const HERO_POOL = { "Haru", "Ryuka" }

const MatchTypes = require("../SystemPackage/MatchTypes")

-- Slot order on each team, top to support.
const ROLE_ORDER: { MatchTypes.Role } = { "Top", "Jungle", "Mid", "Bot", "Support" }

local Module = {}

function Module:Init()
	local botHeroes: { [string]: string } = {}
	for heroId, hero in HeroCatalog.Heroes do
		botHeroes[hero.Role] = heroId
	end

	MatchServerService:SetHeroPool(HERO_POOL)
	MatchServerService:SetRoles(ROLE_ORDER, botHeroes)
	MatchServerService:SetFillWithBots(true)
end

return Module
