-- The live simulation of one player's restaurant.
--
-- Table customers: door -> reception -> table -> read the menu -> ready to order.
-- The order is taken by YOU (a conversation with upsells and ID checks) or by a waiter.
-- Food is cooked at the stations (by you or a chef), drinks are poured at the bar
-- (by you or a bartender), then carried to the customer. They eat, you can check on
-- their table, they pay, tip and leave a review.
--
-- Bar customers sit at the bar and only order a drink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Avatars = require(script.Parent.Avatars)
local Npc = require(script.Parent.Npc)
local RestaurantBuilder = require(script.Parent.RestaurantBuilder)
local Conversation = require(script.Parent.Conversation)
local IdCards = require(script.Parent.IdCards)

local Restaurant = {}
Restaurant.__index = Restaurant

local MONEY_COLOR = Color3.fromRGB(110, 255, 120)
local ANGRY_COLOR = Color3.fromRGB(255, 80, 80)
local INFO_COLOR = Color3.fromRGB(255, 255, 255)

local nextCustomerId = 0

-- session: { player, data, passes, runtime, addCash, notify, review, markDirty }
function Restaurant.new(session, layout)
	local self = setmetatable({}, Restaurant)
	self.session = session
	self.layout = layout
	self.alive = true
	self.customers = {} -- [id] = customer
	self.tickets = {} -- food and drink orders, oldest first
	self.tableUsed = {} -- [index] = customer
	self.barUsed = {} -- [index] = customer
	self.staff = { waiter = {}, chef = {}, bartender = {} }
	self.carry = nil -- ticket the player is holding
	self.turnedAwayAt = -math.huge
	self.barClosedUntil = 0
	self.inspectorActive = false

	self.npcFolder = Instance.new("Folder")
	self.npcFolder.Name = "People"
	self.npcFolder.Parent = layout.model
	self.itemFolder = Instance.new("Folder")
	self.itemFolder.Name = "Items"
	self.itemFolder.Parent = layout.model

	self:connectStationPrompts()
	return self
end

function Restaurant:start()
	self:syncStaff()
	self:refreshKitchenPrompts()
	task.spawn(function()
		self:spawnLoop()
	end)
	task.spawn(function()
		self:patienceLoop()
	end)
end

function Restaurant:destroy()
	self.alive = false
	for _, c in self.customers do
		c.npc:destroy()
	end
	for _, list in self.staff do
		for _, npc in list do
			npc:destroy()
		end
	end
end

-- Helpers ---------------------------------------------------------------------------

function Restaurant:isOwner(player: Player): boolean
	return player == self.session.player
end

function Restaurant:passes()
	return self.session.passes
end

function Restaurant:patienceMultiplier(): number
	local mult = Formulas.patienceMultiplier(Formulas.atmosphere(self.session.data))
	if self:passes().PatientCustomers then
		mult *= 2
	end
	return mult
end

function Restaurant:staffSpeed(role: string): (number, number)
	local level = self.session.data.staff[role].speed
	local walk = Formulas.staffWalkSpeed(level)
	local work = Formulas.staffWorkMultiplier(level)
	if self:passes().SpeedyStaff then
		walk *= 1.5
		work *= 1.5
	end
	return walk, work
end

function Restaurant:speedyFactor(): number
	return if self:passes().SpeedyStaff then 1.5 else 1
end

function Restaurant:barOpen(): boolean
	return os.time() >= self.barClosedUntil
end

local function freeSlot(used, count: number): number?
	for i = 1, count do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- Prompts ------------------------------------------------------------------------------

function Restaurant:connectStationPrompts()
	for _, dish in Config.Dishes do
		local station = self.layout.stations[dish.id]
		station.prompt.Triggered:Connect(function(player)
			if self:isOwner(player) then
				local ticket = self:nextTicket("food", dish.id)
				if ticket and not station.busy then
					self:cook(ticket, 1)
				end
			end
		end)
	end
	for _, drink in Config.Drinks do
		local dispenser = self.layout.dispensers[drink.id]
		dispenser.prompt.Triggered:Connect(function(player)
			if self:isOwner(player) then
				local ticket = self:nextTicket("drink", drink.id)
				if ticket and not dispenser.busy then
					self:pour(ticket, 1, nil)
				end
			end
		end)
	end
end

function Restaurant:pendingCount(kind: string, itemId: string): number
	local n = 0
	for _, t in self.tickets do
		if t.kind == kind and t.item.id == itemId and t.state == "pending" then
			n += 1
		end
	end
	return n
end

function Restaurant:refreshKitchenPrompts()
	for _, dish in Config.Dishes do
		local station = self.layout.stations[dish.id]
		local n = self:pendingCount("food", dish.id)
		station.prompt.Enabled = n > 0 and not station.busy
		station.prompt.ActionText = `Cook ({n} waiting)`
	end
	for _, drink in Config.Drinks do
		local dispenser = self.layout.dispensers[drink.id]
		local n = self:pendingCount("drink", drink.id)
		dispenser.prompt.Enabled = n > 0 and not dispenser.busy
		dispenser.prompt.ActionText = `Pour ({n} waiting)`
	end
end

function Restaurant:refreshPrompt(c)
	local prompt = c.prompt
	if not prompt or c.state == "left" then
		return
	end
	local carry = self.carry
	if c.state == "ready" then
		prompt.ActionText = "Take order"
		prompt.Enabled = true
	elseif c.state == "waiting" and carry and carry.customer == c then
		prompt.ActionText = "Serve " .. carry.item.name
		prompt.Enabled = true
	elseif c.state == "eating" and not c.checked and c.kind == "table" then
		prompt.ActionText = "How's everything?"
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

function Restaurant:refreshAllPrompts()
	for _, c in self.customers do
		self:refreshPrompt(c)
	end
	self:refreshKitchenPrompts()
end

-- Tickets: cooking, pouring, carrying ----------------------------------------------------

function Restaurant:addTicket(kind: string, customer, item)
	table.insert(self.tickets, { kind = kind, customer = customer, item = item, state = "pending" })
	self:refreshKitchenPrompts()
end

function Restaurant:removeTicket(ticket)
	local i = table.find(self.tickets, ticket)
	if i then
		table.remove(self.tickets, i)
	end
	if ticket.part then
		ticket.part:Destroy()
		ticket.part = nil
	end
	ticket.state = "done"
end

function Restaurant:nextTicket(kind: string, itemId: string?, state: string?)
	for _, t in self.tickets do
		if t.kind == kind and (itemId == nil or t.item.id == itemId) and t.state == (state or "pending") then
			return t
		end
	end
	return nil
end

-- Puts a finished bowl or cup on a counter, with a "Pick up" prompt for the player.
function Restaurant:placeReady(ticket, position: Vector3)
	local item = Npc.makeItem(ticket.item.color, ticket.kind == "drink")
	item.Anchored = true
	item.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	item.Parent = self.itemFolder
	local prompt = RestaurantBuilder.prompt(item, "Pick up", ticket.item.name)
	prompt.Enabled = self.carry == nil
	prompt.Triggered:Connect(function(player)
		if self:isOwner(player) then
			self:playerPickUp(ticket)
		end
	end)
	ticket.part = item
	ticket.state = "ready"
end

-- `work` is the worker's speed multiplier (1 for the player).
function Restaurant:cook(ticket, work: number)
	local station = self.layout.stations[ticket.item.id]
	ticket.state = "working"
	station.busy = true
	self:refreshKitchenPrompts()
	local data = self.session.data
	local duration = Formulas.cookTime(ticket.item, data.dishes[ticket.item.id] or 1, data.kitchenSpeed)
		/ (work * self:speedyFactor())
	station.steam.Enabled = true
	RestaurantBuilder.runProgress(station.progress, duration)
	task.wait(duration)
	station.steam.Enabled = false
	station.busy = false
	if not self.alive then
		return
	end
	if ticket.customer.state == "left" then
		self:removeTicket(ticket)
	else
		self:placeReady(ticket, station.platePos + Vector3.new(math.random(-15, 15) / 10, 0, 0))
	end
	self:refreshKitchenPrompts()
end

-- Bartenders serving the bar pass `direct = true` and carry the drink themselves.
function Restaurant:pour(ticket, work: number, direct: boolean?)
	local dispenser = self.layout.dispensers[ticket.item.id]
	ticket.state = "working"
	dispenser.busy = true
	self:refreshKitchenPrompts()
	local duration = Formulas.prepTime(ticket.item, self.session.data.barSpeed) / (work * self:speedyFactor())
	RestaurantBuilder.runProgress(dispenser.progress, duration)
	task.wait(duration)
	dispenser.busy = false
	if not self.alive then
		return
	end
	if ticket.customer.state == "left" then
		self:removeTicket(ticket)
	elseif direct then
		ticket.state = "carried"
	else
		self:placeReady(ticket, self.layout.drinkPass.top + Vector3.new(0, 0, math.random(-8, 8) / 10))
	end
	self:refreshKitchenPrompts()
end

function Restaurant:playerPickUp(ticket)
	if self.carry or ticket.state ~= "ready" or not ticket.part then
		return
	end
	local character = self.session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local item = ticket.part
	local prompt = item:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	item.Anchored = false
	item.Massless = true
	item.CanCollide = false
	item.CFrame = root.CFrame * CFrame.new(0, 0.2, -1.8) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = item
	weld.Parent = item
	item.Parent = character
	ticket.state = "carried"
	self.carry = ticket
	self:setPickupPromptsEnabled(false)
	self:refreshPrompt(ticket.customer)
	self.session.notify(`Carrying {ticket.item.name}. Bring it to {ticket.customer.name}!`)
end

function Restaurant:setPickupPromptsEnabled(enabled: boolean)
	for _, t in self.tickets do
		if t.state == "ready" and t.part then
			local prompt = t.part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = enabled
			end
		end
	end
end

function Restaurant:clearPlayerCarry()
	local ticket = self.carry
	if not ticket then
		return
	end
	self.carry = nil
	if ticket.part then
		ticket.part:Destroy()
		ticket.part = nil
	end
	self:setPickupPromptsEnabled(true)
	if ticket.customer.state == "left" then
		self:removeTicket(ticket)
	elseif ticket.state == "carried" then
		-- Dropped (respawn): it has to be made again.
		ticket.state = "pending"
		self:refreshKitchenPrompts()
	end
	self:refreshPrompt(ticket.customer)
end

function Restaurant:onCharacterRemoving()
	self:clearPlayerCarry()
end

-- Staff ----------------------------------------------------------------------------------

local function addHat(npc, color: Color3, tall: boolean)
	local head = npc.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local hat = Instance.new("Part")
	hat.Name = "StaffHat"
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = if tall then Vector3.new(1.6, 1.3, 1.3) else Vector3.new(0.5, 1.4, 1.4)
	hat.Color = color
	hat.CanCollide = false
	hat.Massless = true
	hat.CollisionGroup = "NPC"
	hat.CFrame = head.CFrame * CFrame.new(0, if tall then 1.2 else 0.75, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hat
	weld.Parent = hat
	hat.Parent = npc.model
end

function Restaurant:syncStaff()
	for _, roleId in Config.StaffOrder do
		local role = Config.Staff[roleId]
		local list = self.staff[roleId]
		while #list < self.session.data.staff[roleId].count do
			local index = #list + 1
			local spawnAt = if roleId == "chef"
				then self.layout.chefIdle(index)
				elseif roleId == "waiter" then self.layout.waiterIdle(index)
				else self.layout.bartenderIdle(index)
			local npc = Npc.new(role.name, self.npcFolder, CFrame.new(spawnAt))
			addHat(npc, role.shirt, roleId == "chef")
			npc:setStatus(role.name)
			task.delay(2, function()
				npc:setStatus("")
			end)
			table.insert(list, npc)
			task.spawn(function()
				if roleId == "chef" then
					self:chefLoop(npc, index)
				elseif roleId == "waiter" then
					self:waiterLoop(npc, index)
				else
					self:bartenderLoop(npc, index)
				end
			end)
		end
	end
end

function Restaurant:chefLoop(npc, index: number)
	local idle = true
	while self.alive and npc.alive do
		local ticket = nil
		for _, t in self.tickets do
			if t.kind == "food" and t.state == "pending" and not self.layout.stations[t.item.id].busy then
				ticket = t
				break
			end
		end
		if ticket then
			idle = false
			local station = self.layout.stations[ticket.item.id]
			ticket.state = "claimed"
			station.busy = true -- reserve while walking
			local walk, work = self:staffSpeed("chef")
			npc:setStatus("Cooking " .. ticket.item.name)
			npc:moveTo(station.chefSpot, walk)
			station.busy = false
			if ticket.customer.state == "left" then
				self:removeTicket(ticket)
			else
				self:cook(ticket, work)
			end
			npc:setStatus("")
		else
			if not idle then
				idle = true
				npc:moveTo(self.layout.chefIdle(index), (self:staffSpeed("chef")))
			end
			task.wait(0.25)
		end
	end
end

-- Serves one ready ticket: walk to it, pick it up, bring it to the customer.
function Restaurant:staffServe(npc, ticket, role: string)
	ticket.state = "claimed"
	local walk = self:staffSpeed(role)
	local pickupSpot = if ticket.kind == "food"
		then self.layout.stations[ticket.item.id].pickupSpot
		else self.layout.drinkPass.pickupSpot
	npc:moveTo(pickupSpot, walk)
	if ticket.part then
		ticket.part:Destroy()
		ticket.part = nil
	end
	local c = ticket.customer
	if c.state == "left" then
		self:removeTicket(ticket)
		return
	end
	npc:carry(ticket.item.color, ticket.kind == "drink")
	local target = if c.kind == "table" then self.layout.tables[c.slot].serve else self.layout.barSeats[c.slot].stand
	npc:moveTo(target, walk)
	npc:dropCarry()
	if c.state ~= "left" then
		self:deliver(ticket)
	else
		self:removeTicket(ticket)
	end
end

function Restaurant:waiterLoop(npc, index: number)
	local idle = true
	while self.alive and npc.alive do
		local job = nil
		for _, t in self.tickets do
			if t.state == "ready" then
				job = t
				break
			end
		end
		if job then
			idle = false
			npc:setStatus("Serving")
			self:staffServe(npc, job, "waiter")
			npc:setStatus("")
		else
			local customer = nil
			for _, c in self.customers do
				if c.kind == "table" and c.state == "ready" and not c.claimed then
					customer = c
					break
				end
			end
			if customer then
				idle = false
				customer.claimed = true
				local walk, work = self:staffSpeed("waiter")
				npc:moveTo(self.layout.tables[customer.slot].serve, walk)
				if customer.state == "ready" then
					customer.state = "ordering"
					self:refreshPrompt(customer)
					npc:face(customer.npc.root.Position)
					npc:setStatus("Taking order")
					task.wait(2 / work)
					npc:setStatus("")
					if (customer.state :: string) == "ordering" then
						local level = self.session.data.staff.waiter.speed
						self:submitOrder(customer, Conversation.auto(self, customer, level))
					end
				end
				customer.claimed = false
			else
				if not idle then
					idle = true
					npc:moveTo(self.layout.waiterIdle(index), (self:staffSpeed("waiter")))
				end
				task.wait(0.25)
			end
		end
	end
end

function Restaurant:bartenderLoop(npc, index: number)
	local idle = true
	while self.alive and npc.alive do
		local ticket = nil
		if self:barOpen() then
			for _, t in self.tickets do
				if t.kind == "drink" and t.state == "pending" and not self.layout.dispensers[t.item.id].busy then
					ticket = t
					break
				end
			end
		end
		if ticket then
			idle = false
			local dispenser = self.layout.dispensers[ticket.item.id]
			ticket.state = "claimed"
			dispenser.busy = true
			local walk, work = self:staffSpeed("bartender")
			npc:setStatus("Pouring " .. ticket.item.name)
			npc:moveTo(dispenser.spot, walk)
			dispenser.busy = false
			local c = ticket.customer
			if c.state == "left" then
				self:removeTicket(ticket)
			elseif c.kind == "bar" then
				self:pour(ticket, work, true)
				if ticket.state == "carried" then
					npc:carry(ticket.item.color, true)
					npc:moveTo(self.layout.barSeats[c.slot].bartenderSpot, walk)
					npc:dropCarry()
					if c.state ~= "left" then
						self:deliver(ticket)
					else
						self:removeTicket(ticket)
					end
				end
			else
				self:pour(ticket, work, false)
			end
			npc:setStatus("")
		else
			local customer = nil
			for _, c in self.customers do
				if c.kind == "bar" and c.state == "ready" and not c.claimed then
					customer = c
					break
				end
			end
			if customer then
				idle = false
				customer.claimed = true
				local walk, work = self:staffSpeed("bartender")
				npc:moveTo(self.layout.barSeats[customer.slot].bartenderSpot, walk)
				if customer.state == "ready" then
					customer.state = "ordering"
					self:refreshPrompt(customer)
					npc:setStatus("Checking order")
					task.wait(1.5 / work)
					npc:setStatus("")
					if (customer.state :: string) == "ordering" then
						local level = self.session.data.staff.bartender.speed
						self:submitOrder(customer, Conversation.auto(self, customer, level))
					end
				end
				customer.claimed = false
			else
				if not idle then
					idle = true
					npc:moveTo(self.layout.bartenderIdle(index), (self:staffSpeed("bartender")))
				end
				task.wait(0.25)
			end
		end
	end
end

-- Customers -----------------------------------------------------------------------------

function Restaurant:spawnLoop()
	task.wait(2)
	while self.alive do
		local interval = Formulas.spawnInterval(self.session.data)
		if os.time() < self.session.runtime.rushUntil then
			interval /= Config.RushHourMultiplier
		end
		task.wait(interval)
		if not self.alive then
			break
		end
		self:trySpawn()
	end
end

function Restaurant:trySpawn()
	local data = self.session.data
	local risk = data.risk
	local barSlot = if self:barOpen() then freeSlot(self.barUsed, data.barSeats) else nil

	if
		barSlot
		and not self.inspectorActive
		and risk >= Config.Risk.inspectorThreshold
		and math.random() < Config.Risk.inspectorChancePerCustomer
	then
		self:spawnCustomer("bar", barSlot, true)
		return
	end
	if barSlot and math.random() < Config.Marketing.barChance then
		self:spawnCustomer("bar", barSlot, false)
		return
	end
	local tableSlot = freeSlot(self.tableUsed, data.tables)
	if tableSlot then
		self:spawnCustomer("table", tableSlot, false)
	else
		self.turnedAwayAt = os.clock()
		if barSlot then
			self:spawnCustomer("bar", barSlot, false)
		end
	end
end

function Restaurant:spawnCustomer(kind: string, slot: number, inspector: boolean)
	local data = self.session.data
	local dishes = Formulas.unlockedDishes(data)
	local drinks = Formulas.unlockedDrinks(data)
	if #dishes == 0 or #drinks == 0 then
		return
	end
	nextCustomerId += 1
	local avatar = Avatars.random()
	local npc = Npc.new("Customer", self.npcFolder, CFrame.new(self.layout.doorOutside), avatar)

	local wantDrink = nil
	if inspector then
		for _, d in drinks do
			if d.minAge then
				wantDrink = d
			end
		end
		wantDrink = wantDrink or drinks[1]
	elseif kind == "bar" then
		wantDrink = drinks[math.random(1, #drinks)]
	end

	local c = {
		id = nextCustomerId,
		kind = kind,
		slot = slot,
		npc = npc,
		name = IdCards.randomName(),
		inspector = inspector,
		state = "arriving",
		deadline = math.huge,
		patience = 0,
		wantDish = dishes[math.random(1, #dishes)],
		wantDrink = wantDrink,
		likesDrinks = math.random() < 0.5,
		mood = 3.5 + Formulas.atmosphere(data) / 100,
		needs = { food = false, drink = false },
		items = {},
		checked = false,
		claimed = false,
		tipBonus = 0,
		identity = nil,
		prompt = nil :: ProximityPrompt?,
	}
	self.customers[c.id] = c
	if kind == "table" then
		self.tableUsed[slot] = c
	else
		self.barUsed[slot] = c
	end
	if inspector then
		self.inspectorActive = true
	end

	local prompt = RestaurantBuilder.prompt(npc.root, "Take order", c.name)
	prompt.Triggered:Connect(function(player)
		if self:isOwner(player) then
			self:onCustomerPrompt(c)
		end
	end)
	c.prompt = prompt

	task.spawn(function()
		local speed = Config.Customers.walkSpeed
		local path
		local seat
		if kind == "table" then
			local t = self.layout.tables[slot]
			npc:walkPath({ self.layout.doorInside, self.layout.reception }, speed)
			npc:setStatus("Table for one!")
			task.wait(1)
			npc:setStatus("")
			path = { self.layout.aisle(t.lane.Z - self.layout.base.Z), t.lane, t.stand }
			seat = t.seat
		else
			local b = self.layout.barSeats[slot]
			path = { self.layout.doorInside, b.approach, b.stand }
			seat = b.seat
		end
		if not npc:walkPath(path, speed) or c.state ~= "arriving" then
			return
		end
		if seat then
			npc:sit(seat)
		end
		c.state = "thinking"
		npc:setStatus(if kind == "table" then "Reading the menu..." else "Hmm...")
		local think = Config.Customers.thinkTime
		task.wait(math.random(think[1] * 10, think[2] * 10) / 10)
		if (c.state :: string) ~= "thinking" then
			return
		end
		self:setWaiting(c, "ready", Config.Customers.orderPatience)
		npc:setStatus(if kind == "table" then "Ready to order!" else "Can I get a drink?")
	end)
end

function Restaurant:setWaiting(c, state: string, patience: number)
	c.state = state
	c.patience = patience * self:patienceMultiplier()
	c.deadline = os.clock() + c.patience
	self:refreshPrompt(c)
end

function Restaurant:onCustomerPrompt(c)
	if c.state == "ready" then
		c.state = "ordering"
		self:refreshPrompt(c)
		Conversation.begin(self, c)
	elseif c.state == "waiting" and self.carry and self.carry.customer == c then
		local ticket = self.carry
		self.carry = nil
		if ticket.part then
			ticket.part:Destroy()
			ticket.part = nil
		end
		self:setPickupPromptsEnabled(true)
		self:deliver(ticket)
	elseif c.state == "eating" and not c.checked then
		Conversation.checkOnTable(self, c)
	end
end

-- Called by Conversation when a player conversation is cancelled half way.
function Restaurant:cancelOrdering(c)
	if c.state == "ordering" then
		c.state = "ready"
		c.deadline = math.max(c.deadline, os.clock() + 8)
		self:refreshPrompt(c)
	end
end

-- order = { dish = dishConfig?, drink = drinkConfig?, discount = number }
function Restaurant:submitOrder(c, order)
	if c.state ~= "ordering" then
		return
	end
	if not order.dish and not order.drink then
		self:leave(c, false, "nothing")
		return
	end
	c.order = order
	c.needs.food = order.dish ~= nil
	c.needs.drink = order.drink ~= nil
	if order.dish then
		self:addTicket("food", c, order.dish)
	end
	if order.drink then
		self:addTicket("drink", c, order.drink)
	end
	local what = if order.dish then order.dish.name else (order.drink :: any).name
	self:setWaiting(c, "waiting", Config.Customers.foodPatience)
	c.npc:setStatus("Waiting for " .. what)
end

function Restaurant:deliver(ticket)
	local c = ticket.customer
	self:removeTicket(ticket)
	if c.state ~= "waiting" then
		return
	end
	if c.deadline - os.clock() < c.patience * 0.35 then
		c.waitedLong = true
	end
	-- Put it on the table (or the bar) in front of them
	local top = if c.kind == "table" then self.layout.tables[c.slot].top else self.layout.barSeats[c.slot].top
	local offset = if ticket.kind == "drink" then Vector3.new(0.9, 0.2, 0) else Vector3.new(-0.3, 0, 0)
	local item = Npc.makeItem(ticket.item.color, ticket.kind == "drink")
	item.Anchored = true
	item.CFrame = CFrame.new(top + offset) * CFrame.Angles(0, 0, math.rad(90))
	item.Parent = self.itemFolder
	table.insert(c.items, item)
	c.needs[ticket.kind] = false
	c.npc:popup(ticket.item.name, INFO_COLOR)
	if not c.needs.food and not c.needs.drink then
		self:startEating(c)
	else
		self:refreshPrompt(c)
	end
end

function Restaurant:startEating(c)
	c.state = "eating"
	c.npc:setStatus(if c.order.dish then "Yum!" else "Cheers!")
	self:refreshPrompt(c)
	local eatTime = if c.order.dish then Config.Customers.eatTime else Config.Customers.eatTime * 0.6
	task.delay(eatTime, function()
		if c.state ~= "eating" or not self.alive then
			return
		end
		self:pay(c)
		self:leave(c, false, nil)
	end)
end

function Restaurant:pay(c)
	local data = self.session.data
	local subtotal = 0
	if c.order.dish then
		subtotal += Formulas.dishPrice(c.order.dish, data.dishes[c.order.dish.id] or 1)
	end
	if c.order.drink then
		subtotal += c.order.drink.price * (1 - (c.order.discount or 0))
	end
	local tipRate = Formulas.tipRate(Formulas.atmosphere(data)) + c.tipBonus
	if self:passes().VIP then
		tipRate += 0.2
	end
	if c.mood < 3.5 then
		tipRate *= 0.3
	end
	local total = subtotal * (1 + tipRate)
	if self:passes().DoubleCash then
		total *= 2
	end
	total = math.max(1, math.floor(total))
	data.served += 1
	self.session.addCash(total)
	c.npc:popup("+" .. Formulas.formatMoney(total), MONEY_COLOR)
end

-- reason: nil (happy), "angry", "nothing", "refused"
function Restaurant:leave(c, angry: boolean, reason: string?)
	if c.state == "left" then
		return
	end
	c.state = "left"
	self.customers[c.id] = nil
	if c.kind == "table" then
		if self.tableUsed[c.slot] == c then
			self.tableUsed[c.slot] = nil
		end
	elseif self.barUsed[c.slot] == c then
		self.barUsed[c.slot] = nil
	end
	if c.inspector then
		self.inspectorActive = false
	end
	if c.prompt then
		c.prompt:Destroy()
		c.prompt = nil
	end
	for _, item in c.items do
		item:Destroy()
	end
	for i = #self.tickets, 1, -1 do
		local t = self.tickets[i]
		if t.customer == c and t.state ~= "carried" and t.state ~= "claimed" and t.state ~= "working" then
			self:removeTicket(t)
		end
	end
	if self.carry and self.carry.customer == c then
		self:clearPlayerCarry()
		self.session.notify(`{c.name} left before you served them.`)
	end
	self:refreshKitchenPrompts()

	if angry then
		self.session.data.angry += 1
		c.npc:setStatus("I'm leaving!")
		c.npc:popup("Too slow!", ANGRY_COLOR)
		Conversation.review(self, c, 1, "Waited forever and left hungry.")
	elseif reason ~= "nothing" then
		Conversation.reviewOnLeave(self, c)
		c.npc:setStatus("")
	else
		c.npc:setStatus("Never mind...")
		if c.refusedLegal then
			Conversation.reviewOnLeave(self, c)
		end
	end

	task.spawn(function()
		c.npc:standUp()
		task.wait(0.4)
		local speed = Config.Customers.walkSpeed
		if c.kind == "table" then
			local t = self.layout.tables[c.slot]
			c.npc:walkPath({ t.lane, self.layout.aisle(t.lane.Z - self.layout.base.Z) }, speed)
		else
			c.npc:moveTo(self.layout.barSeats[c.slot].approach, speed)
		end
		c.npc:walkPath({ self.layout.doorInside, self.layout.doorOutside }, speed)
		c.npc:destroy()
	end)
end

function Restaurant:patienceLoop()
	while self.alive do
		task.wait(0.5)
		local data = self.session.data
		data.risk = math.max(0, data.risk - Config.Risk.decayPerMinute / 120)
		local now = os.clock()
		for _, c in self.customers do
			if c.state == "ready" or c.state == "waiting" then
				local remaining = c.deadline - now
				if remaining <= 0 then
					self:leave(c, true, "angry")
				elseif remaining < c.patience * 0.25 then
					c.npc:setStatus("Hurry up!")
				end
			elseif c.state == "ordering" and c.convo and c.convo.started and now - c.convo.started > 45 then
				Conversation.timeout(self, c)
			end
		end
	end
end

function Restaurant:calmEveryone()
	for _, c in self.customers do
		if c.state == "ready" or c.state == "waiting" then
			c.deadline = os.clock() + c.patience
		end
	end
end

-- Money helpers used by Conversation (inspector fines and rewards)
function Restaurant:fine(): number
	local data = self.session.data
	local amount = math.max(Config.Risk.minFine, math.floor(data.cash * Config.Risk.fineShare))
	amount = math.min(amount, data.cash)
	data.cash -= amount
	self.barClosedUntil = os.time() + Config.Risk.barClosedSeconds
	self.session.markDirty()
	return amount
end

function Restaurant:reward(): number
	local perMinute = math.max(self.session.currentIncomePerMin(), self.session.data.incomePerMin)
	local amount = math.max(200, math.floor(perMinute * Config.Risk.rewardMinutes))
	self.session.addCash(amount)
	return amount
end

-- The player's character, for distance checks in conversations.
function Restaurant:playerNear(c, maxDistance: number): boolean
	local character = self.session.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and c.npc.alive and (root.Position - c.npc.root.Position).Magnitude <= maxDistance
end

return Restaurant
