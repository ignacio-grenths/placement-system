--!strict

local Module = {
	-- Server to client: the UnitInfo of units that appeared.
	UnitsAdded = script.UnitsAdded,
	-- Server to client: ids of units that are gone.
	UnitsRemoved = script.UnitsRemoved,
	-- Server to client: encoded UnitSnapshotCodec payloads.
	Snapshot = script.Snapshot,
	-- Server to client: (attacker id, target id), for attack visuals only.
	AttackFired = script.AttackFired,
	-- Client to server: asks for every live unit's UnitInfo.
	SyncRequest = script.SyncRequest,
}

return Module
