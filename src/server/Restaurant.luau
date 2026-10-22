-- The live simulation of one player's restaurant:
-- customers queue -> cashier (or the player) takes the order -> chef cooks ->
-- waiter serves and tries an upsell -> customer eats, pays, tips, leaves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Npc = require(script.Parent.Npc)

local Restaurant = {}
Restaurant.__index = Restaurant

local CUSTOMER_COLORS = {
	Color3.fromRGB(230, 120, 60),
	Color3.fromRGB(90, 180, 90),
	Color3.fromRGB(200, 80, 160),
	Color3.fromRGB(80, 170, 200),
	Color3.fromRGB(230, 200, 70),
	Color3.fromRGB(150, 110, 210),
}

local MONEY_COLOR = Color3.fromRGB(110, 255, 120)
local ANGRY_COLOR = Color3.fromRGB(255, 80, 80)

-- session: { player, data, passes, runtime, addCash, notify, markDirty }
function Restaurant.new(session, layout)
	local self = setmetatable({}, Restaurant)
	self.session = session
	self.layout = layout
	self.alive = true
	self.queue = {} -- customers waiting at the counter, in order
	self.kitchen = {} -- customers whose order is waiting for a chef
	self.ready = {} -- cooked bowls waiting for a waiter
	self.customers = {}
	self.tables = {} -- [tableIndex] = customer
	self.staff = { cashier = {}, chef = {}, waiter = {} }

	self.npcFolder = Instance.new("Folder")
	self.npcFolder.Name = "NPCs"
	self.npcFolder.Parent = layout.model

	layout.prompt.Triggered:Connect(function(who)
		if who == session.player then
			self:playerTakesOrder()
		end
	end)
	return self
end

function Restaurant:start()
	self:syncStaff()
	task.spawn(function()
		self:spawnLoop()
	end)
	task.spawn(function()
		self:patienceLoop()
	end)
end

function Restaurant:destroy()
	self.alive = false
	for c in self.customers do
		c.npc:destroy()
	end
	for _, list in self.staff do
		for _, npc in list do
			npc:destroy()
		end
	end
end

-- Helpers -----------------------------------------------------------------

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

function Restaurant:freeTable(): number?
	for i = 1, self.session.data.tables do
		if not self.tables[i] then
			return i
		end
	end
	return nil
end

-- Staff ---------------------------------------------------------------------

function Restaurant:syncStaff()
	for _, roleId in Config.StaffOrder do
		local role = Config.Staff[roleId]
		local list = self.staff[roleId]
		while #list < self.session.data.staff[roleId].count do
			local index = #list + 1
			local spawnAt = if roleId == "chef"
				then self.layout.chefIdle(index)
				elseif roleId == "waiter" then self.layout.waiterIdle(index)
				else self.layout.cashierSpot(index)
			local hat = if roleId == "chef" then Color3.new(1, 1, 1) else nil
			local npc = Npc.new(role.name, role.color, self.npcFolder, spawnAt, hat)
			table.insert(list, npc)
			task.spawn(function()
				if roleId == "cashier" then
					self:cashierLoop(npc, index)
				elseif roleId == "chef" then
					self:chefLoop(npc, index)
				else
					self:waiterLoop(npc, index)
				end
			end)
		end
	end
end

function Restaurant:cashierLoop(npc, index: number)
	local spot = self.layout.cashierSpot(index)
	while self.alive and npc.alive do
		local c = self.queue[1]
		if c and c.state == "queued" and not c.beingServed then
			c.beingServed = true
			local walk, work = self:staffSpeed("cashier")
			npc:moveTo(spot, walk)
			npc:setStatus("...")
			c.npc:setStatus("...")
			task.wait(Config.Staff.cashier.workTime / work)
			npc:setStatus("")
			if c.state == "queued" then
				self:takeOrder(c)
			end
		else
			task.wait(0.25)
		end
	end
end

function Restaurant:chefLoop(npc, index: number)
	local idle = true
	while self.alive and npc.alive do
		local c = table.remove(self.kitchen, 1)
		if c then
			idle = false
			if c.state == "left" then
				continue
			end
			local station = self.layout.stations[c.dish.id]
			local walk, work = self:staffSpeed("chef")
			npc:moveTo(station.chefSpot, walk)
			npc:setStatus("COOKING")
			local level = self.session.data.dishes[c.dish.id] or 1
			task.wait(Formulas.dishCookTime(c.dish, level) / work)
			npc:carry(c.dish.color)
			npc:setStatus("")
			npc:moveTo(station.passChefSpot, walk)
			npc:dropCarry()
			if c.state ~= "left" and self.alive then
				local bowl = Instance.new("Part")
				bowl.Name = "Bowl"
				bowl.Shape = Enum.PartType.Cylinder
				bowl.Size = Vector3.new(0.6, 1.4, 1.4)
				bowl.Anchored = true
				bowl.CanCollide = false
				bowl.Color = c.dish.color
				bowl.CFrame = CFrame.new(station.platePos + Vector3.new(math.random(-15, 15) / 10, 0, 0))
					* CFrame.Angles(0, 0, math.rad(90))
				bowl.Parent = self.npcFolder
				table.insert(self.ready, { customer = c, bowl = bowl, pickup = station.passWaiterSpot })
			end
		else
			if not idle then
				idle = true
				local walk = self:staffSpeed("chef")
				npc:moveTo(self.layout.chefIdle(index), walk)
			end
			task.wait(0.2)
		end
	end
end

function Restaurant:waiterLoop(npc, index: number)
	local idle = true
	while self.alive and npc.alive do
		local item = table.remove(self.ready, 1)
		if item then
			idle = false
			local walk = self:staffSpeed("waiter")
			npc:moveTo(item.pickup, walk)
			item.bowl:Destroy()
			local c = item.customer
			if c.state == "left" then
				continue
			end
			npc:carry(c.dish.color)
			npc:moveTo(self.layout.tables[c.tableIndex].serve, walk)
			npc:dropCarry()
			if c.state ~= "left" then
				local upsell = math.random()
					< Formulas.upsellChance(self.session.data, self:passes().MasterUpseller == true)
				c.upsell = upsell
				npc:setStatus(if upsell then "Upsell!" else "Enjoy!")
				self:deliver(c)
				task.delay(1, function()
					npc:setStatus("")
				end)
			end
		else
			if not idle then
				idle = true
				local walk = self:staffSpeed("waiter")
				npc:moveTo(self.layout.waiterIdle(index), walk)
			end
			task.wait(0.2)
		end
	end
end

-- Customers -----------------------------------------------------------------

function Restaurant:spawnLoop()
	while self.alive do
		local interval = Formulas.spawnInterval(self.session.data)
		if os.time() < self.session.runtime.rushUntil then
			interval /= Config.RushHourMultiplier
		end
		task.wait(interval)
		if not self.alive then
			break
		end
		local tableIndex = self:freeTable()
		if tableIndex and #self.queue < #self.layout.queueSpots then
			self:spawnCustomer(tableIndex)
		end
	end
end

function Restaurant:spawnCustomer(tableIndex: number)
	local dishes = Formulas.unlockedDishes(self.session.data)
	if #dishes == 0 then
		return
	end
	local dish = dishes[math.random(1, #dishes)]
	local npc =
		Npc.new("Customer", CUSTOMER_COLORS[math.random(1, #CUSTOMER_COLORS)], self.npcFolder, self.layout.doorOutside)
	local c = {
		npc = npc,
		dish = dish,
		tableIndex = tableIndex,
		state = "walking_in",
		deadline = math.huge,
		beingServed = false,
		delivered = false,
		upsell = false,
		bowl = nil :: BasePart?,
	}
	self.customers[c] = true
	self.tables[tableIndex] = c
	table.insert(self.queue, c)

	task.spawn(function()
		npc:moveTo(self.layout.doorInside, Config.Customers.walkSpeed)
		if c.state ~= "walking_in" then
			return
		end
		self:walkToQueueSpot(c)
		if c.state == "walking_in" then
			c.state = "queued"
			c.deadline = os.clock() + Config.Customers.queuePatience * self:patienceMultiplier()
			npc:setStatus(dish.name .. "?")
		end
	end)
end

function Restaurant:walkToQueueSpot(c)
	while self.alive do
		local index = table.find(self.queue, c)
		if not index then
			return
		end
		c.npc:moveTo(self.layout.queueSpots[index], Config.Customers.walkSpeed)
		if table.find(self.queue, c) == index then
			return
		end
	end
end

function Restaurant:shiftQueue()
	for _, c in self.queue do
		if c.state == "queued" then
			task.spawn(function()
				self:walkToQueueSpot(c)
			end)
		end
	end
end

function Restaurant:playerTakesOrder()
	local c = self.queue[1]
	if c and c.state == "queued" and not c.beingServed then
		self:takeOrder(c)
		c.npc:popup("Order taken!", Color3.new(1, 1, 1))
	end
end

function Restaurant:takeOrder(c)
	local index = table.find(self.queue, c)
	if not index then
		return
	end
	table.remove(self.queue, index)
	self:shiftQueue()
	c.state = "to_table"
	c.npc:setStatus("")
	table.insert(self.kitchen, c)
	task.spawn(function()
		c.npc:moveTo(self.layout.tables[c.tableIndex].seat, Config.Customers.walkSpeed)
		if c.state ~= "to_table" then
			return
		end
		if c.delivered then
			self:startEating(c)
		else
			c.state = "waiting_food"
			c.deadline = os.clock() + Config.Customers.foodPatience * self:patienceMultiplier()
			c.npc:setStatus("Waiting...")
		end
	end)
end

function Restaurant:deliver(c)
	c.delivered = true
	local bowl = Instance.new("Part")
	bowl.Name = "Bowl"
	bowl.Shape = Enum.PartType.Cylinder
	bowl.Size = Vector3.new(0.6, 1.4, 1.4)
	bowl.Anchored = true
	bowl.CanCollide = false
	bowl.Color = c.dish.color
	bowl.CFrame = CFrame.new(self.layout.tables[c.tableIndex].top) * CFrame.Angles(0, 0, math.rad(90))
	bowl.Parent = self.npcFolder
	c.bowl = bowl
	if c.state == "waiting_food" then
		self:startEating(c)
	end
end

function Restaurant:startEating(c)
	c.state = "eating"
	c.npc:setStatus("Yum!")
	task.delay(Config.Customers.eatTime, function()
		if c.state ~= "eating" or not self.alive then
			return
		end
		self:pay(c)
		self:leave(c, false)
	end)
end

function Restaurant:pay(c)
	local data = self.session.data
	local price = Formulas.dishPrice(c.dish, data.dishes[c.dish.id] or 1)
	local atmosphere = Formulas.atmosphere(data)
	local tipRate = Formulas.tipRate(atmosphere)
	if self:passes().VIP then
		tipRate += 0.2
	end
	local total = price * (1 + tipRate)
	if c.upsell then
		total += price * Config.Upsell.value
	end
	if self:passes().DoubleCash then
		total *= 2
	end
	total = math.max(1, math.floor(total))
	data.served += 1
	self.session.addCash(total)
	c.npc:popup("+" .. Formulas.formatMoney(total), MONEY_COLOR)
end

function Restaurant:leave(c, angry: boolean)
	if c.state == "left" then
		return
	end
	c.state = "left"
	self.customers[c] = nil
	local index = table.find(self.queue, c)
	if index then
		table.remove(self.queue, index)
		self:shiftQueue()
	end
	if self.tables[c.tableIndex] == c then
		self.tables[c.tableIndex] = nil
	end
	if c.bowl then
		c.bowl:Destroy()
	end
	if angry then
		self.session.data.angry += 1
		c.npc:setStatus("ANGRY!")
		c.npc:popup("Too slow!", ANGRY_COLOR)
		self.session.notify("A customer left angry. Hire staff or improve the atmosphere!")
	else
		c.npc:setStatus("")
	end
	task.spawn(function()
		c.npc:moveTo(self.layout.doorInside, Config.Customers.walkSpeed)
		c.npc:moveTo(self.layout.doorOutside, Config.Customers.walkSpeed)
		c.npc:destroy()
	end)
end

function Restaurant:patienceLoop()
	while self.alive do
		task.wait(0.5)
		local now = os.clock()
		for c in self.customers do
			local waiting = (c.state == "queued" and not c.beingServed) or c.state == "waiting_food"
			if waiting then
				local remaining = c.deadline - now
				if remaining <= 0 then
					self:leave(c, true)
				elseif remaining < 6 then
					c.npc:setStatus("Hurry up!")
				end
			end
		end
	end
end

function Restaurant:calmEveryone()
	local now = os.clock()
	local mult = self:patienceMultiplier()
	for c in self.customers do
		if c.state == "queued" then
			c.deadline = now + Config.Customers.queuePatience * mult
			c.npc:setStatus(c.dish.name .. "?")
		elseif c.state == "waiting_food" then
			c.deadline = now + Config.Customers.foodPatience * mult
			c.npc:setStatus("Waiting...")
		end
	end
end

return Restaurant
