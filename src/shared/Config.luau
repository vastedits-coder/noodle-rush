-- All game balance lives here. Change numbers, press Play, see the effect.

local Config = {}

Config.Version = "0.1.0"
Config.DataStoreName = "NoodleRush_v1"

Config.Plot = {
	Count = 8,
	Spacing = 160,
}

-- Dishes unlock in order. A dish needs the previous one at `UnlockAtLevel`.
Config.DishMaxLevel = 100
Config.UnlockAtLevel = 50
Config.DishMilestones = { 10, 25, 50, 75, 100 } -- each one: price x2, cook time x0.85
Config.DishPricePerLevel = 0.25 -- +25% of base price per level

Config.Dishes = {
	{
		id = "ramen",
		name = "Classic Ramen",
		basePrice = 4,
		cookTime = 4,
		unlockCost = 0,
		baseUpgradeCost = 10,
		costGrowth = 1.16,
		color = Color3.fromRGB(240, 205, 130),
	},
	{
		id = "egg_noodles",
		name = "Egg Noodles",
		basePrice = 40,
		cookTime = 5,
		unlockCost = 25000,
		baseUpgradeCost = 500,
		costGrowth = 1.16,
		color = Color3.fromRGB(250, 225, 90),
	},
	{
		id = "buldak",
		name = "Buldak Fire Noodles",
		basePrice = 320,
		cookTime = 6,
		unlockCost = 600000,
		baseUpgradeCost = 12000,
		costGrowth = 1.16,
		color = Color3.fromRGB(215, 50, 35),
	},
	{
		id = "tonkotsu",
		name = "Golden Tonkotsu",
		basePrice = 2600,
		cookTime = 7,
		unlockCost = 15000000,
		baseUpgradeCost = 300000,
		costGrowth = 1.16,
		color = Color3.fromRGB(255, 190, 40),
	},
}

Config.Staff = {
	cashier = {
		name = "Cashier",
		startCount = 0,
		maxCount = 2,
		hireBaseCost = 100,
		hireGrowth = 25,
		speedBaseCost = 80,
		speedGrowth = 1.4,
		maxSpeedLevel = 20,
		workTime = 1.6, -- seconds to take one order at level 1
		color = Color3.fromRGB(60, 120, 220),
	},
	chef = {
		name = "Chef",
		startCount = 1,
		maxCount = 6,
		hireBaseCost = 400,
		hireGrowth = 6,
		speedBaseCost = 60,
		speedGrowth = 1.4,
		maxSpeedLevel = 20,
		color = Color3.fromRGB(245, 245, 245),
	},
	waiter = {
		name = "Waiter",
		startCount = 1,
		maxCount = 6,
		hireBaseCost = 300,
		hireGrowth = 6,
		speedBaseCost = 50,
		speedGrowth = 1.4,
		maxSpeedLevel = 20,
		color = Color3.fromRGB(35, 35, 40),
	},
}
Config.StaffOrder = { "cashier", "chef", "waiter" }
Config.StaffBaseWalkSpeed = 8 -- studs per second
Config.StaffWalkPerLevel = 0.7
Config.StaffWorkPerLevel = 0.08 -- +8% work speed per level

Config.Tables = {
	start = 2,
	max = 12,
	baseCost = 60,
	growth = 1.7,
}

Config.Upsell = {
	maxLevel = 20,
	baseCost = 200,
	growth = 1.5,
	chancePerLevel = 0.04,
	value = 0.5, -- an upsell adds 50% of the dish price
}

Config.Marketing = {
	maxLevel = 25,
	baseCost = 150,
	growth = 1.45,
	baseInterval = 7, -- seconds between customers at level 0
	intervalFactor = 0.93,
	minInterval = 1.2,
}

-- Atmosphere 0-100: more patience and bigger tips.
Config.BaseAtmosphere = 10
Config.Decor = {
	{ id = "plants", name = "Plants", cost = 250, atmosphere = 8 },
	{ id = "lamps", name = "Warm Lamps", cost = 900, atmosphere = 10 },
	{ id = "tv", name = "Big TV", cost = 3000, atmosphere = 15 },
	{ id = "speakers", name = "Speakers & Music", cost = 12000, atmosphere = 17 },
	{ id = "neon_sign", name = "Neon Sign", cost = 50000, atmosphere = 15 },
	{ id = "stage", name = "Live Stage", cost = 250000, atmosphere = 25 },
}

Config.Customers = {
	walkSpeed = 7,
	queuePatience = 20, -- seconds, before atmosphere multiplier
	foodPatience = 35,
	eatTime = 4,
	maxTipRate = 0.3, -- tip at 100 atmosphere = 30% of price
}

Config.OfflineEarnings = {
	maxSeconds = 2 * 60 * 60,
	rate = 0.25, -- 25% of your normal income per minute
}

-- Create these in Creator Hub (Monetization), then paste the IDs here.
-- An id of 0 means "not created yet"; the shop shows it as unavailable.
Config.GamePasses = {
	{ key = "DoubleCash", name = "2x Cash", price = 299, id = 0, desc = "Double all income, forever." },
	{ key = "SpeedyStaff", name = "Speedy Staff", price = 199, id = 0, desc = "All staff work and walk 50% faster." },
	{
		key = "PatientCustomers",
		name = "Patient Customers",
		price = 149,
		id = 0,
		desc = "Customers wait twice as long.",
	},
	{ key = "MasterUpseller", name = "Master Upseller", price = 99, id = 0, desc = "+25% upsell chance." },
	{ key = "VIP", name = "VIP", price = 399, id = 0, desc = "+20% tips and a golden name tag." },
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

function Config.getDecor(id: string)
	for _, decor in Config.Decor do
		if decor.id == id then
			return decor
		end
	end
	return nil
end

return Config
