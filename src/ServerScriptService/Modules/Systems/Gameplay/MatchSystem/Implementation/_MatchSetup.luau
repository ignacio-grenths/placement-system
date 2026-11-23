--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

const MatchServerService = require("../SystemPackage/MatchServerService")

-- Heroes players are handed, in order, each in its own role.
const HERO_POOL = { "Haru", "Ryuka", "Torvik", "SeoDan", "Brakk" }

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
