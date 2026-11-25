--!strict

const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const MinionWaveServerService = require("../SystemPackage/MinionWaveServerService")

-- Seconds on the match clock. The same everywhere, Studio included.
const FIRST_WAVE_TIME = 60
const WAVE_INTERVAL = 30

local Module = {}

function Module:Init()
	MinionWaveServerService:SetSchedule(FIRST_WAVE_TIME, WAVE_INTERVAL)

	MinionWaveServerService:RegisterMinionType("Melee", "Zib", UnitCatalog.Units.Zib.Stats)
	MinionWaveServerService:RegisterMinionType("Archer", "Quill", UnitCatalog.Units.Quill.Stats)
	MinionWaveServerService:RegisterMinionType("Caster", "Blip", UnitCatalog.Units.Blip.Stats)
	MinionWaveServerService:RegisterMinionType(
		"Siege",
		"GrubTank",
		UnitCatalog.Units.GrubTank.Stats
	)
	MinionWaveServerService:RegisterMinionType("Super", "MegaZib", UnitCatalog.Units.MegaZib.Stats)

	for team, routes in MapLayout.Routes do
		for laneName, route in routes do
			MinionWaveServerService:RegisterLane(team :: MapLayout.MapTeam, laneName, route)
		end
	end
end

return Module
