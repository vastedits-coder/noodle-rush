-- Builds a restaurant out of simple parts, so the prototype needs no hand-made map.
-- Layout (local coordinates, door at +Z):
--   kitchen along the back wall (z = -23), pass counter at z = -15,
--   dining room on the left, bar on the right (x = 22), reception just inside the door.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local RestaurantBuilder = {}

local FLOOR_TOP = 1
local WALK_Y = FLOOR_TOP + 3 -- a point at roughly hip height for MoveTo targets
local WALL_HEIGHT = 14

local TABLE_X = { -27, -20, -13, -6 }
local TABLE_Z = { -8, 0, 8 }
local AISLE_X = 2
local BAR_X = 15 -- bar counter, right next to the dining room
local BACK_BAR_X = 19.6 -- drink machines behind it
local BARTENDER_X = 17.5
local BAR_STOOL_Z = { -4, -0.5, 3, 6.5 }

local PALETTE = {
	wall = Color3.fromRGB(245, 232, 210),
	wallTrim = Color3.fromRGB(170, 55, 45),
	floor = Color3.fromRGB(160, 110, 70),
	kitchenFloor = Color3.fromRGB(235, 235, 235),
	wood = Color3.fromRGB(120, 78, 48),
	darkWood = Color3.fromRGB(70, 45, 30),
	steel = Color3.fromRGB(150, 155, 160),
	stool = Color3.fromRGB(200, 60, 50),
}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CollisionGroup = "Furniture"
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, text: string, offsetY: number, size: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(240, 64)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 70
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.FredokaOne
	text_.TextScaled = true
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0.35
	text_.Text = text
	text_.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size or 24
	constraint.Parent = text_
	gui.Parent = parent
	return text_
end

-- A small progress bar that floats over a station while something cooks.
local function progressBar(parent: Instance, offsetY: number): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "Progress"
	gui.Size = UDim2.fromOffset(120, 16)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 60
	gui.Enabled = false
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 230, 120)
	fill.Parent = back
	corner:Clone().Parent = fill
	gui.Parent = parent
	return fill
end

function RestaurantBuilder.runProgress(fill: Frame, duration: number)
	local gui = (fill.Parent :: Instance).Parent :: BillboardGui
	gui.Enabled = true
	fill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(duration, function()
		gui.Enabled = false
	end)
end

local function prompt(parent: Instance, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Parent = parent
	return p
end
RestaurantBuilder.prompt = prompt

function RestaurantBuilder.build(plotIndex: number, owner: Player)
	local base = Vector3.new((plotIndex - 1) * Config.Plot.Spacing, 0, 0)
	local function at(x: number, y: number, z: number): Vector3
		return base + Vector3.new(x, y, z)
	end
	local function walk(x: number, z: number): Vector3
		return base + Vector3.new(x, WALK_Y, z)
	end

	local model = Instance.new("Model")
	model.Name = `Restaurant_{owner.Name}`

	-- Shell -----------------------------------------------------------------
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(64, 1, 52),
		Position = at(0, 0.5, 0),
		Color = PALETTE.floor,
		Material = Enum.Material.WoodPlanks,
		CollisionGroup = "Default",
		Parent = model,
	})
	floor.CollisionGroup = "Default"
	part({
		Name = "KitchenFloor",
		Size = Vector3.new(64, 0.05, 12),
		Position = at(0, FLOOR_TOP + 0.03, -20),
		Color = PALETTE.kitchenFloor,
		Material = Enum.Material.Slate,
		CanCollide = false,
		Parent = model,
	})
	part({
		Name = "Rug",
		Size = Vector3.new(26, 0.05, 22),
		Position = at(-16.5, FLOOR_TOP + 0.03, 1),
		Color = Color3.fromRGB(150, 45, 45),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = model,
	})

	local walls = {
		{ Vector3.new(64, WALL_HEIGHT, 1), at(0, FLOOR_TOP + WALL_HEIGHT / 2, -26) },
		{ Vector3.new(1, WALL_HEIGHT, 52), at(-32, FLOOR_TOP + WALL_HEIGHT / 2, 0) },
		{ Vector3.new(1, WALL_HEIGHT, 52), at(32, FLOOR_TOP + WALL_HEIGHT / 2, 0) },
		{ Vector3.new(27, WALL_HEIGHT, 1), at(-18.5, FLOOR_TOP + WALL_HEIGHT / 2, 26) },
		{ Vector3.new(27, WALL_HEIGHT, 1), at(18.5, FLOOR_TOP + WALL_HEIGHT / 2, 26) },
		{ Vector3.new(10, 4, 1), at(0, FLOOR_TOP + WALL_HEIGHT - 2, 26) }, -- above the door
	}
	for _, w in walls do
		part({ Name = "Wall", Size = w[1], Position = w[2], Color = PALETTE.wall, Parent = model })
	end
	-- Red trim along the bottom of the walls
	for _, w in walls do
		if w[1].Y == WALL_HEIGHT then
			part({
				Name = "Trim",
				Size = Vector3.new(w[1].X + 0.2, 2.5, w[1].Z + 0.2),
				Position = Vector3.new(w[2].X, FLOOR_TOP + 1.25, w[2].Z),
				Color = PALETTE.wallTrim,
				CanCollide = false,
				Parent = model,
			})
		end
	end
	-- Front windows
	for _, x in { -18.5, 18.5 } do
		part({
			Name = "Window",
			Size = Vector3.new(16, 6, 1.2),
			Position = at(x, FLOOR_TOP + 7, 26),
			Color = Color3.fromRGB(170, 220, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.5,
			Parent = model,
		})
	end
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(66, 1, 54),
		Position = at(0, FLOOR_TOP + WALL_HEIGHT + 0.5, 0),
		Color = PALETTE.darkWood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for _, xz in { { -16, -10 }, { -16, 10 }, { 16, -10 }, { 16, 10 }, { 0, 0 } } do
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 225, 190)
		local attachment = Instance.new("Attachment")
		attachment.Parent = roof
		attachment.WorldPosition = at(xz[1], FLOOR_TOP + WALL_HEIGHT - 1, xz[2])
		light.Parent = attachment
	end

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(20, 3.5, 0.6),
		Position = at(0, FLOOR_TOP + WALL_HEIGHT + 2.5, 26.2),
		Color = PALETTE.wallTrim,
		Parent = model,
	})
	label(sign, `{owner.DisplayName}'s Noodle Bar`, 0, 36)

	-- Reception -----------------------------------------------------------------
	local podium = part({
		Name = "Reception",
		Size = Vector3.new(3, 3.6, 2),
		Position = at(8, FLOOR_TOP + 1.8, 18),
		Color = PALETTE.wood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	label(podium, "WELCOME", 3)

	-- Kitchen -------------------------------------------------------------------
	local stations = {}
	for i, dish in Config.Dishes do
		local x = -26 + (i - 1) * 8
		local stove = part({
			Name = "Station_" .. dish.id,
			Size = Vector3.new(6, 3.4, 3),
			Position = at(x, FLOOR_TOP + 1.7, -23.5),
			Color = PALETTE.steel,
			Material = Enum.Material.DiamondPlate,
			Parent = model,
		})
		local pot = part({
			Name = "Pot",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 2.4, 2.4),
			CFrame = CFrame.new(at(x, FLOOR_TOP + 4.2, -23.5)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 60, 65),
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local soup = part({
			Name = "Soup",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 2, 2),
			CFrame = CFrame.new(at(x, FLOOR_TOP + 5.02, -23.5)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = dish.color,
			CanCollide = false,
			Parent = model,
		})
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Rate = 6
		steam.Lifetime = NumberRange.new(1, 1.6)
		steam.Speed = NumberRange.new(2, 3)
		steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2) })
		steam.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Enabled = false
		steam.Parent = soup
		stations[dish.id] = {
			stove = stove,
			pot = pot,
			soup = soup,
			steam = steam,
			label = label(stove, dish.name, 5),
			progress = progressBar(stove, 3.6),
			prompt = prompt(stove, "Cook", dish.name),
			chefSpot = walk(x, -20.8),
			passChefSpot = walk(x, -16.8),
			platePos = at(x, FLOOR_TOP + 3.3 + 0.3, -15),
			pickupSpot = walk(x, -13),
			busy = false,
		}
	end
	part({
		Name = "PassCounter",
		Size = Vector3.new(34, 3.3, 2),
		Position = at(-13, FLOOR_TOP + 1.65, -15),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local hood = part({
		Name = "Hood",
		Size = Vector3.new(34, 2, 4),
		Position = at(-13, FLOOR_TOP + 10, -24),
		Color = PALETTE.steel,
		Material = Enum.Material.Metal,
		Parent = model,
	})
	label(hood, "KITCHEN", 0, 30)

	-- Bar -----------------------------------------------------------------------
	local barCounter = part({
		Name = "BarCounter",
		Size = Vector3.new(2.5, 3.6, 14),
		Position = at(BAR_X, FLOOR_TOP + 1.8, 1),
		Color = PALETTE.darkWood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	label(barCounter, "BAR", 4, 30)
	part({
		Name = "BackBar",
		Size = Vector3.new(1.2, 2.6, 17),
		Position = at(BACK_BAR_X + 1.4, FLOOR_TOP + 1.3, -0.5),
		Color = PALETTE.darkWood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local drinkPass = part({
		Name = "DrinkPass",
		Size = Vector3.new(2.5, 3.6, 2.5),
		Position = at(BAR_X, FLOOR_TOP + 1.8, -8.6),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	label(drinkPass, "DRINKS", 3.5, 18)

	local dispensers = {}
	for i, drink in Config.Drinks do
		local z = -6.5 + (i - 1) * 2.6
		local machine = part({
			Name = "Dispenser_" .. drink.id,
			Size = Vector3.new(1.4, 2.2, 2),
			Position = at(BACK_BAR_X + 1.4, FLOOR_TOP + 3.7, z),
			Color = drink.color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		dispensers[drink.id] = {
			part = machine,
			label = label(machine, drink.name, 2.6, 16),
			progress = progressBar(machine, 1.9),
			prompt = prompt(machine, "Pour", drink.name),
			spot = walk(BARTENDER_X + 0.6, z),
			busy = false,
		}
	end

	local barSeats = {}
	for i, z in BAR_STOOL_Z do
		barSeats[i] = {
			stand = walk(11.4, z),
			approach = walk(8, z),
			top = at(BAR_X - 0.6, FLOOR_TOP + 3.6 + 0.4, z),
			bartenderSpot = walk(BARTENDER_X, z),
			seatPos = at(12.8, FLOOR_TOP + 2.2, z),
			seat = nil :: Seat?,
		}
	end

	-- Dining ------------------------------------------------------------------
	local tableSlots = {}
	for _, z in TABLE_Z do
		for _, x in TABLE_X do
			table.insert(tableSlots, {
				position = at(x, FLOOR_TOP, z),
				top = at(x, FLOOR_TOP + 3.3, z + 0.7),
				seatPos = at(x, FLOOR_TOP + 1.6, z + 2.3),
				stand = walk(x, z + 3.2),
				lane = walk(x, z + 4.5),
				serve = walk(x + 2.6, z + 3.4),
				seat = nil :: Seat?,
			})
		end
	end

	local furniture = Instance.new("Folder")
	furniture.Name = "Built"
	furniture.Parent = model
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = model

	model.Parent = workspace

	return {
		model = model,
		base = base,
		furniture = furniture,
		decorFolder = decorFolder,
		doorOutside = walk(0, 34),
		doorInside = walk(0, 22),
		reception = walk(5, 18),
		aisle = function(z: number)
			return walk(AISLE_X, z)
		end,
		barAisle = function(z: number)
			return walk(8, z)
		end,
		stations = stations,
		dispensers = dispensers,
		drinkPass = { top = at(BAR_X, FLOOR_TOP + 3.6 + 0.4, -8.6), pickupSpot = walk(12.4, -8.6) },
		drinkPassBartender = walk(BARTENDER_X, -8.6),
		barSeats = barSeats,
		tables = tableSlots,
		chefIdle = function(i: number)
			return walk(-28 + (i - 1) * 4, -19)
		end,
		waiterIdle = function(i: number)
			return walk(-2 + (i - 1) * 2.5, -11)
		end,
		bartenderIdle = function(i: number)
			return walk(BARTENDER_X, -2 + (i - 1) * 4)
		end,
		playerSpawn = CFrame.new(at(2, FLOOR_TOP + 3, 12)) * CFrame.Angles(0, 0, 0),
	}
end

local function makeSeat(position: Vector3, facing: Vector3, parent: Instance): Seat
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Size = Vector3.new(1.8, 0.4, 1.8)
	seat.CFrame = CFrame.lookAt(position, position + facing)
	seat.Color = PALETTE.stool
	seat.Material = Enum.Material.Fabric
	seat.CanTouch = false -- players don't get stuck sitting on it
	seat.CollisionGroup = "Furniture"
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = parent
	return seat
end

function RestaurantBuilder.setTables(layout, count: number)
	for i, slot in layout.tables do
		local name = "Table" .. i
		if i <= count and not layout.furniture:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = layout.furniture
			part({
				Name = "Top",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, 4.2, 4.2),
				CFrame = CFrame.new(slot.position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = PALETTE.wood,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			part({
				Name = "Leg",
				Size = Vector3.new(0.6, 2.8, 0.6),
				Position = slot.position + Vector3.new(0, 1.4, 0),
				Color = PALETTE.darkWood,
				Parent = folder,
			})
			part({
				Name = "Leg",
				Size = Vector3.new(0.5, 1.4, 0.5),
				Position = slot.seatPos - Vector3.new(0, 0.8, 0),
				Color = PALETTE.darkWood,
				Parent = folder,
			})
			slot.seat = makeSeat(slot.seatPos, Vector3.new(0, 0, -1), folder)
		end
	end
end

function RestaurantBuilder.setBarSeats(layout, count: number)
	for i, slot in layout.barSeats do
		local name = "BarStool" .. i
		if i <= count and not layout.furniture:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = layout.furniture
			part({
				Name = "Leg",
				Size = Vector3.new(0.4, 2, 0.4),
				Position = slot.seatPos - Vector3.new(0, 1.1, 0),
				Color = PALETTE.steel,
				Material = Enum.Material.Metal,
				Parent = folder,
			})
			slot.seat = makeSeat(slot.seatPos, Vector3.new(1, 0, 0), folder)
		end
	end
end

function RestaurantBuilder.updateStations(layout, data)
	for i, dish in Config.Dishes do
		local station = layout.stations[dish.id]
		local level = data.dishes[dish.id] or 0
		if level > 0 then
			station.label.Text = `{dish.name}\nLv {level}`
			station.soup.Transparency = 0
			station.stove.Color = PALETTE.steel
		else
			local previous = Config.Dishes[i - 1]
			station.label.Text = `LOCKED\n{previous and previous.name or "?"} Lv {Config.UnlockAtLevel}`
			station.soup.Transparency = 1
			station.stove.Color = Color3.fromRGB(70, 70, 75)
		end
	end
end

function RestaurantBuilder.updateDispensers(layout, data)
	for _, drink in Config.Drinks do
		local d = layout.dispensers[drink.id]
		local owned = data.drinks[drink.id] == true
		d.part.Transparency = if owned then 0 else 0.7
		d.label.Text = if owned then drink.name else "LOCKED"
	end
end

local DECOR_BUILDERS = {
	plants = function(layout, folder)
		for _, xz in { { -30, 23 }, { -30, -12 }, { 12, 23 }, { 30, -12 } } do
			local pot = part({
				Size = Vector3.new(1.8, 1.8, 1.8),
				Position = layout.base + Vector3.new(xz[1], FLOOR_TOP + 0.9, xz[2]),
				Color = Color3.fromRGB(150, 90, 50),
				Material = Enum.Material.Brick,
				Parent = folder,
			})
			part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3.4, 3.4, 3.4),
				Position = pot.Position + Vector3.new(0, 2.3, 0),
				Color = Color3.fromRGB(60, 150, 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = folder,
			})
		end
	end,
	lamps = function(layout, folder)
		for _, slot in layout.tables do
			local lamp = part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				Position = slot.position + Vector3.new(0, 9, 0),
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
			Size = Vector3.new(0.4, 5, 8.5),
			Position = layout.base + Vector3.new(-31.3, FLOOR_TOP + 8, 0),
			Color = Color3.fromRGB(15, 15, 15),
			Parent = folder,
		})
		part({
			Size = Vector3.new(0.1, 4.4, 7.9),
			Position = tv.Position + Vector3.new(0.25, 0, 0),
			Color = Color3.fromRGB(80, 160, 255),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end,
	speakers = function(layout, folder)
		for _, xz in { { -30, 14 }, { 30, 14 } } do
			part({
				Size = Vector3.new(2, 4, 2),
				Position = layout.base + Vector3.new(xz[1], FLOOR_TOP + 2, xz[2]),
				Color = Color3.fromRGB(25, 25, 25),
				Parent = folder,
			})
		end
		-- TODO: pick a licensed track in the Creator Store, put its id here and call :Play().
		local music = Instance.new("Sound")
		music.Name = "Music"
		music.Looped = true
		music.Volume = 0.3
		music.Parent = folder
	end,
	neon_sign = function(layout, folder)
		local neon = part({
			Size = Vector3.new(14, 2.5, 0.3),
			Position = layout.base + Vector3.new(0, FLOOR_TOP + WALL_HEIGHT - 5, 26.8),
			Color = Color3.fromRGB(255, 60, 160),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		label(neon, "NOODLES", 0, 40)
	end,
	stage = function(layout, folder)
		local stage = part({
			Size = Vector3.new(10, 1, 8),
			Position = layout.base + Vector3.new(25, FLOOR_TOP + 0.5, 20),
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
