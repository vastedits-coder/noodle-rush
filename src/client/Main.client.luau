local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraToggle = require(script.Parent.CameraToggle)
local UI = require(script.Parent.UI)

UI.init()
CameraToggle.init()

Remotes.event("StateUpdated").OnClientEvent:Connect(UI.setState)
Remotes.event("Notify").OnClientEvent:Connect(UI.toast)
