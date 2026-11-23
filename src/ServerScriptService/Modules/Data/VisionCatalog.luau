--!strict

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

-- Studs each kind of unit sees. Every reach must fit inside its sight, or a
-- unit could never attack at full range. Monsters have none: they fight
-- whoever comes near, and give neither team vision.
Module.SightByKind = {
	Hero = 48,
	Minion = 34,
	Structure = 42,
	Summon = 24,
	Ward = 30,
} :: { [UnitTypes.UnitKind]: number }

-- Seconds a hero stays seen by the team of an enemy hero it damages.
Module.DamageRevealSeconds = 2

-- The fog drawn over what a team can't see.
Module.FogColor = Color3.fromRGB(8, 5, 22)
Module.FogOpacity = 0.6

return Module
