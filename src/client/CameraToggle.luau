-- First person by default; V (or the on-screen button) switches to third person.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CameraToggle = {}

local player = Players.LocalPlayer
local firstPerson = true

local function apply()
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 8
		player.CameraMaxZoomDistance = 30
		-- Release the minimum again so the player can scroll closer afterwards.
		task.delay(0.2, function()
			if not firstPerson then
				player.CameraMinZoomDistance = 0.5
			end
		end)
	end
end

function CameraToggle.toggle()
	firstPerson = not firstPerson
	apply()
end

function CameraToggle.isFirstPerson(): boolean
	return firstPerson
end

function CameraToggle.init()
	apply()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.V then
			CameraToggle.toggle()
		end
	end)
end

return CameraToggle
