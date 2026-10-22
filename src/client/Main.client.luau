local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraToggle = require(script.Parent.CameraToggle)
local DialogUI = require(script.Parent.DialogUI)
local UI = require(script.Parent.UI)

UI.init()
DialogUI.init(UI.screen)
CameraToggle.init()

Remotes.event("StateUpdated").OnClientEvent:Connect(UI.setState)
Remotes.event("Notify").OnClientEvent:Connect(UI.toast)
Remotes.event("Review").OnClientEvent:Connect(UI.review)
Remotes.event("Dialog").OnClientEvent:Connect(DialogUI.show)
