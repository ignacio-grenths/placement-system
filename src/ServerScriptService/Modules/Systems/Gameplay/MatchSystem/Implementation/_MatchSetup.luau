--!strict

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")

const MatchServerService = require("../SystemPackage/MatchServerService")

-- One hero per role, handed out first to players who pick none. Every other
-- catalog hero follows them in the pool.
const DEFAULT_HEROES = { "Haru", "Ryuka", "Torvik", "SeoDan", "Brakk" }

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

local function buildHeroPool(): { MatchTypes.PoolHero }
	local others = {}
	for heroId in HeroCatalog.Heroes do
		if not table.find(DEFAULT_HEROES, heroId) then
			table.insert(others, heroId)
		end
	end
	table.sort(others)

	local pool: { MatchTypes.PoolHero } = {}
	for _, heroId in DEFAULT_HEROES do
		table.insert(pool, { HeroId = heroId, Role = HeroCatalog.Heroes[heroId].Role })
	end
	for _, heroId in others do
		table.insert(pool, { HeroId = heroId, Role = HeroCatalog.Heroes[heroId].Role })
	end
	return pool
end

function Module:Init()
	local defaultHeroes: { [string]: string } = {}
	for _, heroId in DEFAULT_HEROES do
		defaultHeroes[HeroCatalog.Heroes[heroId].Role] = heroId
	end

	MatchServerService:SetHeroPool(buildHeroPool())
	MatchServerService:SetRoles(ROLE_ORDER, defaultHeroes)
	MatchServerService:SetBotHeroPicker(pickBotHero)
	MatchServerService:SetFillWithBots(true)
end

return Module
