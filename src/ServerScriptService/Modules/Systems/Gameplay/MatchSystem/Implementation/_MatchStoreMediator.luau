--!strict

const StoreServerService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/StoreSystem/SystemPackage/StoreServerService"
)

const MatchServerService = require("../SystemPackage/MatchServerService")

local Module = {}

-- Players pick only heroes they own. Bots may play any hero.
function Module:Init()
	MatchServerService:SetHeroAccessCheck(function(player: Player, heroId: string): boolean
		return StoreServerService:Owns(player, heroId)
	end)
end

return Module
