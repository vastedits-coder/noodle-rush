-- Roblox-avatar NPCs (R15) that walk with Humanoid:MoveTo and play the default animations.
-- NPCs are in the "NPC" collision group: they only collide with the floor, so they never
-- get stuck on furniture, players or each other.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Avatars = require(script.Parent.Avatars)

local Npc = {}
Npc.__index = Npc

-- Default Roblox R15 animations
local ANIMATIONS = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://507777826",
	sit = "rbxassetid://2506281703",
}

export type Npc = typeof(setmetatable(
	{} :: {
		model: Model,
		humanoid: Humanoid,
		root: BasePart,
		status: TextLabel,
		alive: boolean,
		moveId: number,
		carried: BasePart?,
		tracks: { [string]: AnimationTrack },
		seat: Seat?,
		avatar: Avatars.Avatar,
	},
	Npc
))

local function buildModel(avatar: Avatars.Avatar): Model
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(avatar.description:Clone(), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[Npc] avatar failed, using a plain one:", model)
	return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
end

function Npc.new(name: string, parent: Instance, cframe: CFrame, avatar: Avatars.Avatar?): Npc
	local chosen = avatar or Avatars.random()
	local model = buildModel(chosen)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "NPC"
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model:PivotTo(cframe)
	model.Parent = parent
	root:SetNetworkOwner(nil)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for key, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok then
			track.Looped = true
			tracks[key] = track
		end
	end
	if tracks.idle then
		tracks.idle:Play()
	end

	local head = model:FindFirstChild("Head") :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 44)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
	gui.Parent = head
	local status = Instance.new("TextLabel")
	status.Size = UDim2.fromScale(1, 1)
	status.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(40, 30, 40)
	status.Text = ""
	status.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = status
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = status

	return setmetatable({
		model = model,
		humanoid = humanoid,
		root = root,
		status = status,
		alive = true,
		moveId = 0,
		carried = nil,
		tracks = tracks,
		seat = nil,
		avatar = chosen,
	}, Npc)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Walks to a point. Yields until arrival. Returns false if a newer move replaced
-- this one or the NPC was destroyed.
function Npc.moveTo(self: Npc, target: Vector3, speed: number): boolean
	if not self.alive then
		return false
	end
	self.moveId += 1
	local myMove = self.moveId
	self.humanoid.WalkSpeed = speed
	if self.tracks.walk then
		self.tracks.walk:Play(0.15)
		self.tracks.walk:AdjustSpeed(speed / 12)
	end
	local timeout = flatDistance(self.root.Position, target) / math.max(speed, 1) + 3
	local started = os.clock()
	local lastIssue = 0
	while self.alive and self.moveId == myMove do
		local now = os.clock()
		if flatDistance(self.root.Position, target) < 1 or now - started > timeout then
			break
		end
		if now - lastIssue > 4 then
			self.humanoid:MoveTo(target)
			lastIssue = now
		end
		task.wait(0.1)
	end
	if self.alive and self.moveId == myMove then
		if self.tracks.walk then
			self.tracks.walk:Stop(0.2)
		end
		-- Snap the last bit so NPCs line up neatly at counters and seats.
		if flatDistance(self.root.Position, target) > 1 then
			self.model:PivotTo(CFrame.new(target.X, self.root.Position.Y, target.Z) * self.root.CFrame.Rotation)
		end
		return true
	end
	return false
end

function Npc.walkPath(self: Npc, points: { Vector3 }, speed: number): boolean
	for _, point in points do
		if not self:moveTo(point, speed) then
			return false
		end
	end
	return true
end

function Npc.face(self: Npc, point: Vector3)
	if not self.alive then
		return
	end
	local pos = self.root.Position
	local look = Vector3.new(point.X, pos.Y, point.Z)
	if (look - pos).Magnitude > 0.1 then
		self.model:PivotTo(CFrame.lookAt(pos, look))
	end
end

function Npc.sit(self: Npc, seat: Seat)
	if not self.alive then
		return
	end
	self.seat = seat
	seat:Sit(self.humanoid)
	if self.tracks.sit then
		self.tracks.sit:Play(0.2)
	end
end

function Npc.standUp(self: Npc)
	if not self.alive then
		return
	end
	if self.tracks.sit then
		self.tracks.sit:Stop(0.2)
	end
	if self.seat then
		local weld = self.seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		self.seat = nil
	end
	self.humanoid.Sit = false
	self.humanoid.Jump = true
end

function Npc.setStatus(self: Npc, text: string)
	if self.alive then
		self.status.Text = text
		self.status.BackgroundTransparency = if text == "" then 1 else 0.1
	end
end

local function makeItem(color: Color3, isDrink: boolean): Part
	local p = Instance.new("Part")
	p.Name = if isDrink then "Cup" else "Bowl"
	p.Shape = Enum.PartType.Cylinder
	p.Size = if isDrink then Vector3.new(1.1, 0.6, 0.6) else Vector3.new(0.6, 1.4, 1.4)
	p.Color = color
	p.Material = if isDrink then Enum.Material.Glass else Enum.Material.SmoothPlastic
	p.Transparency = if isDrink then 0.15 else 0
	p.CanCollide = false
	p.Massless = true
	return p
end
Npc.makeItem = makeItem

-- Holds a bowl or cup in front of the NPC.
function Npc.carry(self: Npc, color: Color3, isDrink: boolean?)
	self:dropCarry()
	local item = makeItem(color, isDrink == true)
	item.CollisionGroup = "NPC"
	item.CFrame = self.root.CFrame * CFrame.new(0, 0.3, -1.3) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.root
	weld.Part1 = item
	weld.Parent = item
	item.Parent = self.model
	self.carried = item
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
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = self.root
	local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.5, function()
		gui:Destroy()
	end)
end

function Npc.destroy(self: Npc)
	self.alive = false
	self.model:Destroy()
end

return Npc
