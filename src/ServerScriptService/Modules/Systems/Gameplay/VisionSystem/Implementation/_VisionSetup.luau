--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)
const VisionCatalog = require("@game/ServerScriptService/Modules/Data/VisionCatalog")

const VisionServerService = require("../SystemPackage/VisionServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

local Module = {}

function Module:Init()
	VisionServerService:SetBrushes(MapLayout.Brushes)
	VisionServerService:SetWalls(MapLayout.Walls)
	for kind, studs in VisionCatalog.SightByKind do
		-- Annotated because luau-lsp types a loop key over string literals as string.
		local unitKind: UnitTypes.UnitKind = kind :: UnitTypes.UnitKind
		VisionServerService:SetSight(unitKind, studs)
	end
	-- Everyone knows where the towers stand, as in any lane battler.
	VisionServerService:SetAlwaysSeen("Structure")
	VisionServerService:SetDamageReveal(VisionCatalog.DamageRevealSeconds)

	UnitServerService:SetVisibility({
		IsUnitVisible = function(unit, team)
			return VisionServerService:IsVisibleTo(unit, team)
		end,
		IsPointVisible = function(position, team)
			return VisionServerService:IsPointVisibleTo(position, team)
		end,
		GetViewerTeam = function(player)
			return VisionServerService:GetPlayerTeam(player)
		end,
	})
end

return Module
