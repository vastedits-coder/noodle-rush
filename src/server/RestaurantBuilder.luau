-- Builds a restaurant out of simple parts, so the prototype needs no hand-made map.
-- Layout (local coordinates, door at +Z):
--   kitchen stations along the back wall (z = -19.5), pass counter at z = -11,
--   cashier counter on the right (x = 18), tables in the dining room, door at z = 22.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RestaurantBuilder = {}

local FLOOR_TOP = 1
local NPC_Y = FLOOR_TOP + 1.5 -- center of an NPC body
local WALL_HEIGHT = 12

local TABLE_X = { -24, -14, -4, 6 }
local TABLE_Z = { 0, 8, 16 }

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, text: string, offsetY: number, size: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = false
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.GothamBold
	text_.TextScaled = true
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.4
	text_.Text = text
	text_.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size or 22
	constraint.Parent = text_
	gui.Parent = parent
	return text_
end

function RestaurantBuilder.build(plotIndex: number, owner: Player)
	local base = Vector3.new((plotIndex - 1) * Config.Plot.Spacing, 0, 0)
	local function at(x: number, y: number, z: number): Vector3
		return base + Vector3.new(x, y, z)
	end
	local function walk(x: number, z: number): Vector3
		return base + Vector3.new(x, NPC_Y, z)
	end

	local model = Instance.new("Model")
	model.Name = `Restaurant_{owner.Name}`

	-- Shell
	part({
		Name = "Floor",
		Size = Vector3.new(60, 1, 44),
		Position = at(0, 0.5, 0),
		Color = Color3.fromRGB(200, 170, 130),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	part({
		Name = "KitchenFloor",
		Size = Vector3.new(60, 0.05, 12),
		Position = at(0, FLOOR_TOP + 0.03, -16),
		Color = Color3.fromRGB(225, 225, 225),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local wallColor = Color3.fromRGB(180, 60, 50)
	local walls = {
		{ Vector3.new(60, WALL_HEIGHT, 1), at(0, FLOOR_TOP + WALL_HEIGHT / 2, -22) },
		{ Vector3.new(1, WALL_HEIGHT, 44), at(-30, FLOOR_TOP + WALL_HEIGHT / 2, 0) },
		{ Vector3.new(1, WALL_HEIGHT, 44), at(30, FLOOR_TOP + WALL_HEIGHT / 2, 0) },
		{ Vector3.new(26, WALL_HEIGHT, 1), at(-17, FLOOR_TOP + WALL_HEIGHT / 2, 22) },
		{ Vector3.new(26, WALL_HEIGHT, 1), at(17, FLOOR_TOP + WALL_HEIGHT / 2, 22) },
	}
	for _, w in walls do
		part({ Name = "Wall", Size = w[1], Position = w[2], Color = wallColor, Parent = model })
	end

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(16, 3, 0.6),
		Position = at(0, FLOOR_TOP + WALL_HEIGHT + 1.5, 22),
		Color = Color3.fromRGB(30, 30, 30),
		Parent = model,
	})
	label(sign, `{owner.DisplayName}'s Noodle Bar`, 0, 32)

	-- Kitchen stations, one per dish
	local stations = {}
	for i, dish in Config.Dishes do
		local x = -24 + (i - 1) * 8
		local stove = part({
			Name = "Station_" .. dish.id,
			Size = Vector3.new(6, 3, 3),
			Position = at(x, FLOOR_TOP + 1.5, -19.5),
			Color = Color3.fromRGB(90, 90, 95),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local pot = part({
			Name = "Pot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 2.2, 2.2),
			CFrame = CFrame.new(at(x, FLOOR_TOP + 3.6, -19.5)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = dish.color,
			Parent = model,
		})
		stations[dish.id] = {
			stove = stove,
			pot = pot,
			label = label(stove, dish.name, 4),
			chefSpot = walk(x, -16.5),
			passChefSpot = walk(x, -12.8),
			passWaiterSpot = walk(x, -9.2),
			platePos = at(x, FLOOR_TOP + 3.2 + 0.3, -11),
		}
	end

	part({
		Name = "PassCounter",
		Size = Vector3.new(32, 3.2, 2),
		Position = at(-12, FLOOR_TOP + 1.6, -11),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Parent = model,
	})

	-- Cashier counter, with a prompt so the player can take orders too
	local counter = part({
		Name = "CashierCounter",
		Size = Vector3.new(8, 3.5, 2),
		Position = at(18, FLOOR_TOP + 1.75, -8),
		Color = Color3.fromRGB(120, 80, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	label(counter, "ORDER HERE", 3.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take order"
	prompt.ObjectText = "Counter"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	local queueSpots = {}
	for i = 1, 6 do
		queueSpots[i] = walk(18, -5.5 + (i - 1) * 3)
	end

	-- Tables are created on demand (see setTables)
	local tableSlots = {}
	for _, z in TABLE_Z do
		for _, x in TABLE_X do
			table.insert(tableSlots, {
				position = at(x, FLOOR_TOP + 1.5, z),
				top = at(x, FLOOR_TOP + 3.3, z + 0.8),
				seat = walk(x, z + 2.8),
				serve = walk(x + 2.8, z + 1),
			})
		end
	end

	local tablesFolder = Instance.new("Folder")
	tablesFolder.Name = "Tables"
	tablesFolder.Parent = model
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = model

	model.Parent = workspace

	return {
		model = model,
		base = base,
		npcY = NPC_Y,
		doorOutside = walk(0, 34),
		doorInside = walk(0, 19),
		queueSpots = queueSpots,
		stations = stations,
		tables = tableSlots,
		tablesFolder = tablesFolder,
		decorFolder = decorFolder,
		prompt = prompt,
		cashierSpot = function(i: number)
			return walk(18 - (i - 1) * 3, -10.5)
		end,
		chefIdle = function(i: number)
			return walk(-26 + (i - 1) * 4, -14.5)
		end,
		waiterIdle = function(i: number)
			return walk(-24 + (i - 1) * 4, -6.5)
		end,
		playerSpawn = CFrame.new(at(14, FLOOR_TOP + 3, 4)) * CFrame.Angles(0, math.rad(180), 0),
	}
end

function RestaurantBuilder.setTables(layout, count: number)
	for i, slot in layout.tables do
		local name = "Table" .. i
		local existing = layout.tablesFolder:FindFirstChild(name)
		if i <= count and not existing then
			local t = part({
				Name = name,
				Size = Vector3.new(4, 0.4, 4),
				Position = slot.position + Vector3.new(0, 1.3, 0),
				Color = Color3.fromRGB(150, 100, 60),
				Material = Enum.Material.Wood,
				Parent = layout.tablesFolder,
			})
			part({
				Name = "Leg",
				Size = Vector3.new(0.6, 2.8, 0.6),
				Position = slot.position - Vector3.new(0, 0.2, 0),
				Color = Color3.fromRGB(60, 60, 60),
				Parent = t,
			})
			part({
				Name = "Stool",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, 1.6, 1.6),
				CFrame = CFrame.new(slot.seat.X, slot.position.Y - 0.7, slot.seat.Z)
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(200, 50, 50),
				Parent = t,
			})
		end
	end
end

function RestaurantBuilder.updateStations(layout, data)
	for i, dish in Config.Dishes do
		local station = layout.stations[dish.id]
		local level = data.dishes[dish.id] or 0
		if level > 0 then
			station.label.Text = `{dish.name}\nLv {level}`
			station.pot.Transparency = 0
			station.stove.Color = Color3.fromRGB(90, 90, 95)
		else
			local previous = Config.Dishes[i - 1]
			station.label.Text =
				`LOCKED {dish.name}\nNeeds {previous and previous.name or "?"} Lv {Config.UnlockAtLevel}`
			station.pot.Transparency = 0.8
			station.stove.Color = Color3.fromRGB(50, 50, 55)
		end
	end
end

local DECOR_BUILDERS = {
	plants = function(layout, folder)
		for _, xz in { { -28, 20 }, { -28, -4 }, { 10, 20 }, { 28, -2 } } do
			local pot = part({
				Size = Vector3.new(1.6, 1.6, 1.6),
				Position = layout.base + Vector3.new(xz[1], FLOOR_TOP + 0.8, xz[2]),
				Color = Color3.fromRGB(150, 90, 50),
				Parent = folder,
			})
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3, 3, 3),
				Position = pot.Position + Vector3.new(0, 2, 0),
				Color = Color3.fromRGB(60, 150, 60),
				Material = Enum.Material.Grass,
				Parent = folder,
			})
		end
	end,
	lamps = function(layout, folder)
		for _, slot in layout.tables do
			local lamp = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = slot.position + Vector3.new(0, 7, 0),
				Color = Color3.fromRGB(255, 200, 120),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			local light = Instance.new("PointLight")
			light.Color = lamp.Color
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = lamp
		end
	end,
	tv = function(layout, folder)
		local tv = part({
			Size = Vector3.new(0.4, 5, 8),
			Position = layout.base + Vector3.new(-29.3, FLOOR_TOP + 7, 8),
			Color = Color3.fromRGB(15, 15, 15),
			Parent = folder,
		})
		part({
			Size = Vector3.new(0.1, 4.4, 7.4),
			Position = tv.Position + Vector3.new(0.25, 0, 0),
			Color = Color3.fromRGB(80, 160, 255),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end,
	speakers = function(layout, folder)
		for _, xz in { { -28, 12 }, { 28, 12 } } do
			part({
				Size = Vector3.new(2, 4, 2),
				Position = layout.base + Vector3.new(xz[1], FLOOR_TOP + 2, xz[2]),
				Color = Color3.fromRGB(25, 25, 25),
				Parent = folder,
			})
		end
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.Looped = true
		music.Volume = 0.3
		-- TODO: upload or pick a licensed track in Creator Store and put its id here.
		music.SoundId = ""
		music.Parent = folder
	end,
	neon_sign = function(layout, folder)
		local neon = part({
			Size = Vector3.new(14, 2.5, 0.3),
			Position = layout.base + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT - 2, 22.7),
			Color = Color3.fromRGB(255, 60, 160),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		label(neon, "NOODLES", 0, 40)
	end,
	stage = function(layout, folder)
		local stage = part({
			Size = Vector3.new(10, 1, 6),
			Position = layout.base + Vector3.new(24, FLOOR_TOP + 0.5, 18),
			Color = Color3.fromRGB(40, 20, 60),
			Parent = folder,
		})
		label(stage, "LIVE MUSIC SOON", 4)
		for _, dx in { -3, 0, 3 } do
			part({
				Size = Vector3.new(0.3, 4, 0.3),
				Position = stage.Position + Vector3.new(dx, 2.5, 0),
				Color = Color3.fromRGB(180, 180, 180),
				Material = Enum.Material.Metal,
				Parent = folder,
			})
		end
	end,
}

function RestaurantBuilder.updateDecor(layout, data)
	for _, decor in Config.Decor do
		if data.decor[decor.id] and not layout.decorFolder:FindFirstChild(decor.id) then
			local folder = Instance.new("Folder")
			folder.Name = decor.id
			folder.Parent = layout.decorFolder
			local builder = DECOR_BUILDERS[decor.id]
			if builder then
				builder(layout, folder)
			end
		end
	end
end

return RestaurantBuilder
