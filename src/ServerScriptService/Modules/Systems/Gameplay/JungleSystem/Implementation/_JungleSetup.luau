--!strict

const JungleCatalog = require("@game/ServerScriptService/Modules/Data/JungleCatalog")
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")

const JungleServerService = require("../SystemPackage/JungleServerService")

type MonsterOptions = JungleServerService.MonsterOptions

local Module = {}

--[[
	Places a camp's monsters on a circle around its center, so a camp of
	several doesn't spawn stacked on one spot.
]]
local function placeMonsters(center: Vector3, typeIds: { string }): { MonsterOptions }
	local placed = {}
	for index, typeId in typeIds do
		local offset = if #typeIds == 1
			then Vector3.zero
			else CFrame.Angles(0, (index - 1) / #typeIds * math.pi * 2, 0).LookVector
				* JungleCatalog.MonsterSpacing
		table.insert(placed, {
			TypeId = typeId,
			Stats = UnitCatalog.Units[typeId].Stats,
			Position = center + offset,
		})
	end
	return placed
end

function Module:Init()
	JungleServerService:SetLeashRadius(JungleCatalog.LeashRadius)

	for _, spot in MapLayout.Camps do
		local entry = JungleCatalog.Camps[spot.Id]
		if not entry then
			warn(`Camp {spot.Key} has no JungleCatalog entry and stays empty`)
			continue
		end
		JungleServerService:RegisterCamp({
			Key = spot.Key,
			Kind = spot.Kind,
			Position = spot.Position,
			Monsters = placeMonsters(spot.Position, entry.Monsters),
			FirstSpawnTime = entry.FirstSpawn,
			RespawnDelay = entry.Respawn,
		})
	end
end

return Module
