-- Entry point: one session per player, each with its own restaurant plot.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local RestaurantBuilder = require(script.Parent.RestaurantBuilder)
local Restaurant = require(script.Parent.Restaurant)
local UpgradeService = require(script.Parent.UpgradeService)
local Monetization = require(script.Parent.Monetization)
local Avatars = require(script.Parent.Avatars)
local Conversation = require(script.Parent.Conversation)

local StateUpdated = Remotes.event("StateUpdated")
local Notify = Remotes.event("Notify")
local Purchase = Remotes.func("Purchase")
local ReviewEvent = Remotes.event("Review")
local DialogChoice = Remotes.event("DialogChoice")

-- NPCs only collide with the floor, so they never get stuck on furniture or players.
for _, group in { "NPC", "Furniture", "Players" } do
	PhysicsService:RegisterCollisionGroup(group)
end
PhysicsService:CollisionGroupSetCollidable("NPC", "NPC", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "Furniture", false)
PhysicsService:CollisionGroupSetCollidable("NPC", "Players", false)

Avatars.start()

local AUTOSAVE_SECONDS = 60
local MAX_RECEIPTS = 100

local sessions: { [Player]: any } = {}
local plotOwners: { [number]: Player } = {}

local function claimPlot(player: Player): number?
	for i = 1, Config.Plot.Count do
		if not plotOwners[i] then
			plotOwners[i] = player
			return i
		end
	end
	return nil
end

local function pruneReceipts(data)
	local list = {}
	for id, time in data.receipts do
		table.insert(list, { id = id, time = time })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a.time > b.time
	end)
	for i = MAX_RECEIPTS + 1, #list do
		data.receipts[list[i].id] = nil
	end
end

local function createSession(player: Player, data, canSave: boolean)
	local session = {
		player = player,
		data = data,
		canSave = canSave,
		passes = {},
		runtime = { rushUntil = 0, incomeLog = {} },
		dirty = true,
		layout = nil :: any,
		restaurant = nil :: any,
		plot = nil :: number?,
	}

	function session.markDirty()
		session.dirty = true
	end

	function session.notify(text: string)
		Notify:FireClient(player, text)
	end

	function session.review(stars: number, text: string, name: string)
		ReviewEvent:FireClient(player, { stars = stars, text = text, name = name })
	end

	function session.currentIncomePerMin(): number
		local now = os.clock()
		local log = session.runtime.incomeLog
		local total = 0
		for i = #log, 1, -1 do
			if now - log[i].t > 60 then
				table.remove(log, i)
			else
				total += log[i].v
			end
		end
		return total
	end

	function session.addCash(amount: number)
		data.cash += amount
		data.totalEarned += amount
		table.insert(session.runtime.incomeLog, { t = os.clock(), v = amount })
		local stats = player:FindFirstChild("leaderstats")
		local earned = stats and stats:FindFirstChild("Earned")
		if earned then
			(earned :: StringValue).Value = Formulas.formatMoney(data.totalEarned)
		end
		session.dirty = true
	end

	function session.saveNow(): boolean
		if not session.canSave then
			return true -- nothing we can persist (Studio without API access, or load failed)
		end
		local current = session.currentIncomePerMin()
		if current > 0 then
			data.incomePerMin = current
		end
		pruneReceipts(data)
		return PlayerData.save(player, data)
	end

	return session
end

local function snapshot(session)
	return {
		data = session.data,
		passes = session.passes,
		atmosphere = Formulas.atmosphere(session.data),
		incomePerMin = session.currentIncomePerMin(),
		rushSecondsLeft = math.max(0, session.runtime.rushUntil - os.time()),
		rating = Formulas.rating(session.data),
		barClosedSeconds = if session.restaurant then math.max(0, session.restaurant.barClosedUntil - os.time()) else 0,
	}
end

local function giveOfflineEarnings(session)
	local data = session.data
	if data.lastOnline <= 0 or data.incomePerMin <= 0 then
		return
	end
	local away = math.min(os.time() - data.lastOnline, Config.OfflineEarnings.maxSeconds)
	if away < 60 then
		return
	end
	local amount = math.floor(data.incomePerMin * away / 60 * Config.OfflineEarnings.rate)
	if amount > 0 then
		session.addCash(amount)
		session.notify(`Welcome back! Your restaurant earned {Formulas.formatMoney(amount)} while you were away.`)
	end
end

local function setPlayerCollisionGroup(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end)
end

local function moveCharacterHome(session, character: Model)
	setPlayerCollisionGroup(character)
	if not session.layout then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		character:PivotTo(session.layout.playerSpawn)
	end
	if session.passes.VIP then
		local head = character:WaitForChild("Head", 10)
		if head then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(80, 24)
			gui.StudsOffset = Vector3.new(0, 2.5, 0)
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBlack
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(255, 200, 40)
			text.TextStrokeTransparency = 0.2
			text.Text = "VIP"
			text.Parent = gui
			gui.Parent = head
		end
	end
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local earned = Instance.new("StringValue")
	earned.Name = "Earned"
	earned.Value = "$0"
	earned.Parent = stats
	stats.Parent = player

	local data, canSave = PlayerData.load(player)
	if not player.Parent then
		return
	end
	local session = createSession(player, data, canSave)
	sessions[player] = session
	session.passes = Monetization.loadPasses(player)
	earned.Value = Formulas.formatMoney(data.totalEarned)

	if not canSave then
		session.notify("Progress can't be saved right now (Studio: enable API Services). Playing anyway!")
	end

	local plot = claimPlot(player)
	if not plot then
		player:Kick("This server is full, please join another one.")
		return
	end
	session.plot = plot
	session.layout = RestaurantBuilder.build(plot, player)
	RestaurantBuilder.setTables(session.layout, data.tables)
	RestaurantBuilder.setBarSeats(session.layout, data.barSeats)
	RestaurantBuilder.updateDispensers(session.layout, data)
	RestaurantBuilder.updateStations(session.layout, data)
	RestaurantBuilder.updateDecor(session.layout, data)
	session.restaurant = Restaurant.new(session, session.layout)
	session.restaurant:start()

	giveOfflineEarnings(session)

	player.CharacterAdded:Connect(function(character)
		moveCharacterHome(session, character)
	end)
	player.CharacterRemoving:Connect(function()
		if session.restaurant then
			session.restaurant:onCharacterRemoving()
		end
	end)
	if player.Character then
		moveCharacterHome(session, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	session.saveNow()
	if session.restaurant then
		session.restaurant:destroy()
	end
	if session.layout then
		session.layout.model:Destroy()
	end
	if session.plot then
		plotOwners[session.plot] = nil
	end
end

Monetization.init(function(player)
	return sessions[player]
end)

Purchase.OnServerInvoke = function(player, kind, id)
	local session = sessions[player]
	if not session or not session.restaurant then
		return false, "Still loading"
	end
	return UpgradeService.purchase(session, kind, id)
end

DialogChoice.OnServerEvent:Connect(function(player, customerId, optionId)
	local session = sessions[player]
	local restaurant = session and session.restaurant
	if not restaurant or type(customerId) ~= "number" or type(optionId) ~= "string" then
		return
	end
	local customer = restaurant.customers[customerId]
	if not customer then
		return
	end
	if optionId == "__close" then
		Conversation.onClose(restaurant, customer)
	else
		Conversation.onChoice(restaurant, customer, optionId)
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Push state to clients a few times per second, only when something changed.
task.spawn(function()
	while true do
		task.wait(0.25)
		for player, session in sessions do
			if session.dirty then
				session.dirty = false
				StateUpdated:FireClient(player, snapshot(session))
			end
		end
	end
end)

-- Autosave, and refresh the income display once per second.
task.spawn(function()
	local elapsed = 0
	while true do
		task.wait(1)
		elapsed += 1
		for _, session in sessions do
			session.dirty = true
			if elapsed % AUTOSAVE_SECONDS == 0 then
				task.spawn(session.saveNow)
			end
		end
	end
end)

game:BindToClose(function()
	-- Save everyone in parallel; Roblox gives us up to 30 seconds here.
	local pending = 0
	for _, session in sessions do
		pending += 1
		task.spawn(function()
			session.saveNow()
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		waited += task.wait(0.5)
	end
end)
