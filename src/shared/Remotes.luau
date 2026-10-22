-- Server creates the remotes; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	StateUpdated = "RemoteEvent", -- server -> client: full state snapshot
	Notify = "RemoteEvent", -- server -> client: toast message
	Review = "RemoteEvent", -- server -> client: a customer left a review
	Dialog = "RemoteEvent", -- server -> client: show/close a conversation with a customer
	DialogChoice = "RemoteEvent", -- client -> server: the option the player picked
	Purchase = "RemoteFunction", -- client -> server: buy an upgrade with cash
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, className in DEFINITIONS do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
