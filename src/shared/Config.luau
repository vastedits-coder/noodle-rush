-- All game balance lives here. Change numbers, press Play, see the effect.

local Config = {}

Config.Version = "0.2.0"
Config.DataStoreName = "NoodleRush_v2"

Config.Plot = {
	Count = 6,
	Spacing = 180,
}

-- Dishes --------------------------------------------------------------------
-- Dishes unlock in order. A dish needs the previous one at `UnlockAtLevel`.
Config.DishMaxLevel = 100
Config.UnlockAtLevel = 50
Config.DishMilestones = { 10, 25, 50, 75, 100 } -- each one: price x2, cook time x0.85
Config.DishPricePerLevel = 0.25 -- +25% of base price per level

Config.Dishes = {
	{
		id = "ramen",
		name = "Classic Ramen",
		basePrice = 6,
		cookTime = 6,
		unlockCost = 0,
		baseUpgradeCost = 12,
		costGrowth = 1.16,
		color = Color3.fromRGB(240, 205, 130),
	},
	{
		id = "egg_noodles",
		name = "Egg Noodles",
		basePrice = 50,
		cookTime = 8,
		unlockCost = 25000,
		baseUpgradeCost = 500,
		costGrowth = 1.16,
		color = Color3.fromRGB(250, 225, 90),
	},
	{
		id = "buldak",
		name = "Buldak Fire Noodles",
		basePrice = 380,
		cookTime = 10,
		unlockCost = 600000,
		baseUpgradeCost = 12000,
		costGrowth = 1.16,
		color = Color3.fromRGB(215, 50, 35),
	},
	{
		id = "tonkotsu",
		name = "Golden Tonkotsu",
		basePrice = 3000,
		cookTime = 12,
		unlockCost = 15000000,
		baseUpgradeCost = 300000,
		costGrowth = 1.16,
		color = Color3.fromRGB(255, 190, 40),
	},
}

-- Drinks ----------------------------------------------------------------------
-- `minAge` means the customer must show an ID. Set it on any drink.
-- Kept as an energy drink (16+) so the game stays all-ages on Roblox;
-- alcohol would force the 18+ "Restricted" maturity label.
Config.Drinks = {
	{
		id = "juice",
		name = "Orange Juice",
		price = 3,
		prepTime = 2,
		unlockCost = 0,
		color = Color3.fromRGB(255, 160, 40),
	},
	{
		id = "volt",
		name = "Volt Energy",
		price = 7,
		prepTime = 2,
		unlockCost = 0,
		minAge = 16,
		color = Color3.fromRGB(120, 255, 80),
	},
	{
		id = "lemonade",
		name = "Fresh Lemonade",
		price = 12,
		prepTime = 3,
		unlockCost = 800,
		color = Color3.fromRGB(255, 245, 140),
	},
	{
		id = "bubble_tea",
		name = "Bubble Tea",
		price = 40,
		prepTime = 5,
		unlockCost = 12000,
		color = Color3.fromRGB(200, 150, 110),
	},
	{
		id = "matcha",
		name = "Iced Matcha",
		price = 140,
		prepTime = 6,
		unlockCost = 150000,
		color = Color3.fromRGB(130, 190, 90),
	},
	{
		id = "dragon_soda",
		name = "Dragon Fruit Soda",
		price = 450,
		prepTime = 6,
		unlockCost = 2000000,
		color = Color3.fromRGB(240, 60, 150),
	},
}

-- Staff -----------------------------------------------------------------------
-- Everyone starts at 0: at first YOU are the waiter, the chef and the bartender.
Config.Staff = {
	waiter = {
		name = "Waiter",
		desc = "Takes orders and serves tables",
		maxCount = 6,
		hireBaseCost = 120,
		hireGrowth = 5,
		speedBaseCost = 60,
		speedGrowth = 1.4,
		maxSpeedLevel = 20,
		shirt = Color3.fromRGB(35, 35, 40),
	},
	chef = {
		name = "Chef",
		desc = "Cooks every order automatically",
		maxCount = 6,
		hireBaseCost = 150,
		hireGrowth = 5,
		speedBaseCost = 70,
		speedGrowth = 1.4,
		maxSpeedLevel = 20,
		shirt = Color3.fromRGB(245, 245, 245),
	},
	bartender = {
		name = "Bartender",
		desc = "Pours drinks and runs the bar (checks IDs too)",
		maxCount = 2,
		hireBaseCost = 400,
		hireGrowth = 10,
		speedBaseCost = 90,
		speedGrowth = 1.45,
		maxSpeedLevel = 20,
		shirt = Color3.fromRGB(120, 30, 40),
	},
}
Config.StaffOrder = { "waiter", "chef", "bartender" }
Config.StaffBaseWalkSpeed = 10 -- studs per second
Config.StaffWalkPerLevel = 0.8
Config.StaffWorkPerLevel = 0.08 -- +8% work speed per level
-- How good staff are at spotting a fake ID (bartender, or waiter at tables).
Config.StaffIdAccuracy = 0.75
Config.StaffIdAccuracyPerLevel = 0.01

-- Kitchen and bar speed upgrades (they also help you when you cook).
Config.KitchenSpeed = { maxLevel = 25, baseCost = 100, growth = 1.5, factor = 0.95 }
Config.BarSpeed = { maxLevel = 15, baseCost = 150, growth = 1.55, factor = 0.93 }

-- Restaurant --------------------------------------------------------------------
Config.Tables = { start = 3, max = 12, baseCost = 80, growth = 1.65 }
Config.BarSeats = { start = 2, max = 4, baseCost = 300, growth = 2.2 }

-- "Charm" makes customers say yes to upsells and suggestions.
Config.Charm = {
	maxLevel = 20,
	baseCost = 150,
	growth = 1.5,
	perLevel = 0.03,
}
Config.Upsell = {
	suggestBase = 0.3, -- chance a customer switches to the dish you suggest
	drinkBase = 0.35, -- chance a customer says yes to a drink
	promoBase = 0.6, -- chance they say yes after "50% off, are you sure?"
	promoDiscount = 0.5,
}

Config.Marketing = {
	maxLevel = 25,
	baseCost = 150,
	growth = 1.45,
	baseInterval = 9, -- seconds between customers at level 0
	intervalFactor = 0.93,
	minInterval = 1.5,
	barChance = 0.25, -- share of customers who only come for a drink
}

-- Atmosphere 0-100: more patience, bigger tips, better reviews.
Config.BaseAtmosphere = 10
Config.Decor = {
	{ id = "plants", name = "Plants", cost = 250, atmosphere = 8 },
	{ id = "lamps", name = "Warm Lamps", cost = 900, atmosphere = 10 },
	{ id = "tv", name = "Big TV", cost = 3000, atmosphere = 15 },
	{ id = "speakers", name = "Speakers & Music", cost = 12000, atmosphere = 17 },
	{ id = "neon_sign", name = "Neon Sign", cost = 50000, atmosphere = 15 },
	{ id = "stage", name = "Live Stage", cost = 250000, atmosphere = 25 },
}

-- Customers --------------------------------------------------------------------
Config.Customers = {
	walkSpeed = 9,
	thinkTime = { 3, 6 }, -- seconds reading the menu
	orderPatience = 50, -- seconds waiting for someone to take the order
	foodPatience = 80, -- seconds waiting for the order to arrive
	eatTime = 10,
	maxTipRate = 0.3, -- tip at 100 atmosphere = 30% of the bill
	checkTipBonus = 0.15, -- extra tip when you check on their table
}

-- Reviews and the restaurant rating (1-5 stars)
Config.Reviews = {
	keep = 30, -- rating is the average of the last N reviews
	startRating = 4,
}

-- Fake IDs, risk and the undercover inspector
Config.Risk = {
	fakeIdChance = 0.3, -- share of age-restricted orders that come with a fake ID
	perFakeServed = 15,
	decayPerMinute = 3,
	inspectorThreshold = 40,
	inspectorChancePerCustomer = 0.08, -- when risk is above the threshold
	fineShare = 0.15, -- share of cash lost when the inspector catches you
	minFine = 100,
	barClosedSeconds = 180,
	rewardMinutes = 5, -- minutes of income paid for passing an inspection
}

Config.OfflineEarnings = {
	maxSeconds = 2 * 60 * 60,
	rate = 0.25, -- 25% of your normal income per minute
}

-- Robux ---------------------------------------------------------------------------
-- Create these in Creator Hub (Monetization), then paste the IDs here.
-- An id of 0 means "not created yet"; the shop shows it as unavailable.
Config.GamePasses = {
	{ key = "DoubleCash", name = "2x Cash", price = 299, id = 0, desc = "Double all income, forever." },
	{ key = "SpeedyStaff", name = "Speedy Staff", price = 199, id = 0, desc = "Staff and cooking 50% faster." },
	{
		key = "PatientCustomers",
		name = "Patient Customers",
		price = 149,
		id = 0,
		desc = "Customers wait twice as long.",
	},
	{ key = "MasterUpseller", name = "Master Upseller", price = 99, id = 0, desc = "+25% chance on every upsell." },
	{ key = "VIP", name = "VIP", price = 399, id = 0, desc = "+20% tips and a golden VIP tag." },
}

Config.Products = {
	{ key = "CashSmall", name = "Bag of Cash", price = 29, id = 0, desc = "5 minutes of your income." },
	{ key = "CashBig", name = "Vault of Cash", price = 149, id = 0, desc = "1 hour of your income." },
	{ key = "RushHour", name = "Rush Hour", price = 49, id = 0, desc = "3x customers for 15 minutes." },
	{ key = "CalmEveryone", name = "Calm Everyone", price = 19, id = 0, desc = "Reset everyone's patience." },
}

Config.RushHourSeconds = 15 * 60
Config.RushHourMultiplier = 3

function Config.getDish(id: string)
	for _, dish in Config.Dishes do
		if dish.id == id then
			return dish
		end
	end
	return nil
end

function Config.getDrink(id: string)
	for _, drink in Config.Drinks do
		if drink.id == id then
			return drink
		end
	end
	return nil
end

function Config.getDecor(id: string)
	for _, decor in Config.Decor do
		if decor.id == id then
			return decor
		end
	end
	return nil
end

return Config
