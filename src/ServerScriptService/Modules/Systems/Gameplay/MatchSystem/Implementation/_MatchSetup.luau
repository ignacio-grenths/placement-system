--!strict

const MatchServerService = require("../SystemPackage/MatchServerService")

-- Milestone 1 ships two heroes. The other three join the pool in milestone 2.
const HERO_POOL = { "Haru", "Ryuka" }

local Module = {}

function Module:Init()
	MatchServerService:SetHeroPool(HERO_POOL)
end

return Module
