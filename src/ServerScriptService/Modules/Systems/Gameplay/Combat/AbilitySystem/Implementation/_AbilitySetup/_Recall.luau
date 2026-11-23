--!strict

const HeroServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/HeroSystem/SystemPackage/HeroServerService"
)
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const AbilityServerService = require("../../SystemPackage/AbilityServerService")

const RECALL_COLOR = Color3.fromRGB(120, 200, 255)
const RING_RADIUS = 3

const AbilityTypes = require("../../SystemPackage/AbilityTypes")

type AbilityHandler = AbilityTypes.AbilityHandler
type CastContext = AbilityTypes.CastContext

local function recall(context: CastContext): boolean
	local hero = context.Caster
	local fountain = HeroServerService:GetFountainPosition(hero.Team)
	if not fountain then
		return false
	end

	local channelTime = context.Values.ChannelTime
	AbilityServerService:PlayEffect({
		Kind = "Ring",
		Position = hero.Position,
		Radius = RING_RADIUS,
		Color = RECALL_COLOR,
		Duration = channelTime,
	})
	AbilityServerService:StartChannel(hero, {
		Name = context.Info.Name,
		Duration = channelTime,
		CancelOnOrder = true,
		CancelOnDamage = true,
		OnComplete = function()
			if not hero.IsDead then
				UnitServerService:Teleport(hero, fountain)
			end
		end,
	})
	return true
end

local handlers: { [string]: AbilityHandler } = {
	Recall = recall,
}

return handlers
