--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

const MatchServerService = require("../SystemPackage/MatchServerService")

-- Heroes players are handed, in order, each in its own role.
const HERO_POOL = { "Haru", "Ryuka", "Torvik", "SeoDan", "Brakk" }

const MatchTypes = require("../SystemPackage/MatchTypes")

-- Slot order on each team, top to support.
const ROLE_ORDER: { MatchTypes.Role } = { "Top", "Jungle", "Mid", "Bot", "Support" }

local Module = {}

local random = Random.new()

--[[
	Picks a random hero of the role for a bot, preferring one nobody in the
	match plays yet, so the teams field different heroes.
]]
local function pickBotHero(_team: MatchTypes.Team, role: MatchTypes.Role): string
	local isTaken: { [string]: boolean? } = {}
	for _, participant in MatchServerService:GetParticipants() do
		isTaken[participant.HeroId] = true
	end
	local fresh = {}
	local all = {}
	for heroId, hero in HeroCatalog.Heroes do
		if hero.Role == role then
			table.insert(all, heroId)
			if not isTaken[heroId] then
				table.insert(fresh, heroId)
			end
		end
	end
	local choices = if #fresh > 0 then fresh else all
	return choices[random:NextInteger(1, #choices)]
end

function Module:Init()
	-- Each role's default is its hero in the pool, which is also the role a
	-- player handed that hero plays.
	local poolHeroes: { [string]: string } = {}
	for _, heroId in HERO_POOL do
		poolHeroes[HeroCatalog.Heroes[heroId].Role] = heroId
	end

	MatchServerService:SetHeroPool(HERO_POOL)
	MatchServerService:SetRoles(ROLE_ORDER, poolHeroes)
	MatchServerService:SetBotHeroPicker(pickBotHero)
	MatchServerService:SetFillWithBots(true)
end

return Module
