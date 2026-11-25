--!strict

const Players = game:GetService("Players")

const ModuleLoader = require("@game/ReplicatedStorage/Packages/ModuleLoader")

-- Systems are found by their LOAD_MODULE tag, and the loader reads tags only with this setting on.
ModuleLoader.ChangeSettings({ USE_COLLECTION_SERVICE = true })
ModuleLoader.Start()
-- Start returns once every system has started. The loading screen waits for
-- this, and hero select tells the server.
Players.LocalPlayer:SetAttribute("IsClientLoaded", true)
