--!strict

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")
const AbilityNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityNetwork"
)

const UnitVisualsClientService = require("../SystemPackage/UnitVisualsClientService")

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const CharacterRig = require("../SystemPackage/CharacterRig")

type Effect = AbilityTypes.Effect
type Motion = CharacterRig.Motion

-- The pose a figure strikes when it casts, by how the ability is aimed,
-- unless CAST_MOTIONS names one.
const DEFAULT_MOTIONS: { [AbilityTypes.Targeting]: Motion } = {
	Direction = "Shoot",
	Point = "Shoot",
	Unit = "Shoot",
	Self = "Raise",
}

-- By ability id, for abilities whose pose differs from their aim's.
const CAST_MOTIONS: { [string]: Motion? } = {
	["Haru.W"] = "Slash",
	["Haru.R"] = "Slash",
	["Ryuka.R"] = "Blast",
	["Torvik.Q"] = "DualSlash",
	["Torvik.W"] = "Blast",
	["Torvik.E"] = "Slam",
	["SeoDan.Q"] = "Slash",
	["SeoDan.R"] = "Raise",
	["Brakk.Q"] = "Punch",
	["Brakk.E"] = "Slam",
	["Akane.Q"] = "Punch",
	["Akane.W"] = "Slash",
	["Akane.E"] = "Slam",
	["Akane.R"] = "Punch",
	["Rin.Q"] = "Slash",
	["Rin.R"] = "Raise",
	["Yuki.W"] = "Raise",
	["Yuki.R"] = "Raise",
	["Kenji.E"] = "Slash",
	["Kenji.R"] = "Blast",
	["Mio.E"] = "Slam",
	["Spell.Warp"] = "Raise",
}

-- Moves that are over at once, like a blink or a swap, strike no pose.
const MOTIONLESS: { [string]: true? } = {
	["Haru.E"] = true,
	["Ryuka.E"] = true,
	["SeoDan.E"] = true,
	["Kenji.W"] = true,
	["Spell.Blink"] = true,
}

local Module = {}

local function getCastMotion(abilityId: string): Motion?
	if MOTIONLESS[abilityId] then
		return nil
	end
	local entry = AbilityCatalog.Abilities[abilityId]
	local default = if entry then DEFAULT_MOTIONS[entry.Targeting] else nil
	-- Cast because luau-lsp widens the motions joined by or to string.
	return (CAST_MOTIONS[abilityId] or default) :: Motion?
end

local function onEffect(effect: Effect)
	if effect.Kind ~= "Cast" then
		return
	end
	local motion = getCastMotion(effect.AbilityId)
	if motion then
		-- Cast because luau-lsp widens the narrowed motion to string.
		UnitVisualsClientService:PlayMotion(effect.CasterId, motion :: Motion)
	end
end

function Module:Init()
	AbilityNetwork.Effect.OnClientEvent:Connect(onEffect)
end

return Module
