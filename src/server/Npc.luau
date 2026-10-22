-- Simple block characters moved with tweens. Cheap, predictable, no pathfinding.
-- Placeholder visuals: swap for real rigs once the gameplay is fun.

local TweenService = game:GetService("TweenService")

local Npc = {}
Npc.__index = Npc

export type Npc = typeof(setmetatable(
	{} :: {
		model: Model,
		body: Part,
		status: TextLabel,
		alive: boolean,
		moveId: number,
		carried: BasePart?,
	},
	Npc
))

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function attachPart(body: Part, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.Anchored = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = body.CFrame * offset
	weld(body, p)
	p.Parent = body.Parent
	return p
end

function Npc.new(name: string, color: Color3, parent: Instance, position: Vector3, hatColor: Color3?): Npc
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 3, 1.2)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(position)
	body.Parent = model
	model.PrimaryPart = body

	attachPart(
		body,
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(0, 2.3, 0),
		Color3.fromRGB(255, 220, 180),
		Enum.PartType.Ball
	)
	if hatColor then
		attachPart(body, Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 3.4, 0), hatColor)
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.MaxDistance = 70
	gui.Parent = body
	local status = Instance.new("TextLabel")
	status.Size = UDim2.fromScale(1, 1)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Text = ""
	status.Parent = gui

	model.Parent = parent

	return setmetatable({
		model = model,
		body = body,
		status = status,
		alive = true,
		moveId = 0,
		carried = nil,
	}, Npc)
end

-- Walks in a straight line. Yields until arrival. Returns false if a newer move
-- replaced this one or the NPC was destroyed.
function Npc.moveTo(self: Npc, target: Vector3, speed: number): boolean
	if not self.alive then
		return false
	end
	self.moveId += 1
	local myMove = self.moveId
	local from = self.body.Position
	local flat = Vector3.new(target.X, from.Y, target.Z)
	local distance = (flat - from).Magnitude
	if distance < 0.05 then
		return true
	end
	local facing = CFrame.lookAt(from, flat)
	self.body.CFrame = facing
	local duration = distance / math.max(speed, 0.1)
	TweenService:Create(self.body, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = facing.Rotation + flat,
	}):Play()
	task.wait(duration)
	return self.alive and self.moveId == myMove
end

function Npc.setStatus(self: Npc, text: string)
	if self.alive then
		self.status.Text = text
	end
end

function Npc.carry(self: Npc, color: Color3)
	self:dropCarry()
	self.carried = attachPart(
		self.body,
		Vector3.new(0.6, 1.4, 1.4),
		CFrame.new(0, 0.4, -1.1) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
end

function Npc.dropCarry(self: Npc)
	if self.carried then
		self.carried:Destroy()
		self.carried = nil
	end
end

-- Floating "+$12" style text above the NPC.
function Npc.popup(self: Npc, text: string, color: Color3)
	if not self.alive then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 40)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.GothamBlack
	text_.TextScaled = true
	text_.TextColor3 = color
	text_.TextStrokeTransparency = 0.2
	text_.Text = text
	text_.Parent = gui
	gui.Parent = self.body
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 9, 0) }):Play()
	TweenService:Create(text_, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		gui:Destroy()
	end)
end

function Npc.destroy(self: Npc)
	self.alive = false
	self.model:Destroy()
end

return Npc
