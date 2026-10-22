-- Pure functions shared by server (authoritative) and client (display).

local Config = require(script.Parent.Config)

local Formulas = {}

function Formulas.milestonesReached(level: number): number
	local n = 0
	for _, m in Config.DishMilestones do
		if level >= m then
			n += 1
		end
	end
	return n
end

function Formulas.dishPrice(dish, level: number): number
	if level <= 0 then
		return 0
	end
	local linear = dish.basePrice * (1 + Config.DishPricePerLevel * (level - 1))
	return linear * 2 ^ Formulas.milestonesReached(level)
end

function Formulas.cookTime(dish, dishLevel: number, kitchenLevel: number): number
	return dish.cookTime * 0.85 ^ Formulas.milestonesReached(dishLevel) * Config.KitchenSpeed.factor ^ kitchenLevel
end

function Formulas.prepTime(drink, barLevel: number): number
	return drink.prepTime * Config.BarSpeed.factor ^ barLevel
end

function Formulas.atmosphere(data): number
	local total = Config.BaseAtmosphere
	for _, decor in Config.Decor do
		if data.decor[decor.id] then
			total += decor.atmosphere
		end
	end
	return math.min(total, 100)
end

function Formulas.patienceMultiplier(atmosphere: number): number
	return 0.55 + atmosphere / 100 * 0.9
end

function Formulas.tipRate(atmosphere: number): number
	return Config.Customers.maxTipRate * atmosphere / 100
end

function Formulas.rating(data): number
	local reviews = data.reviews
	if #reviews == 0 then
		return Config.Reviews.startRating
	end
	local sum = 0
	for _, review in reviews do
		sum += review.stars
	end
	return sum / #reviews
end

-- Better reviews bring customers faster.
function Formulas.spawnInterval(data): number
	local m = Config.Marketing
	local ratingFactor = 2 - 0.24 * Formulas.rating(data)
	return math.max(m.minInterval, m.baseInterval * m.intervalFactor ^ data.marketing * ratingFactor)
end

function Formulas.charmBonus(data, hasMasterUpseller: boolean): number
	local bonus = data.charm * Config.Charm.perLevel
	if hasMasterUpseller then
		bonus += 0.25
	end
	return bonus
end

function Formulas.staffWalkSpeed(level: number): number
	return Config.StaffBaseWalkSpeed + Config.StaffWalkPerLevel * (level - 1)
end

function Formulas.staffWorkMultiplier(level: number): number
	return 1 + Config.StaffWorkPerLevel * (level - 1)
end

function Formulas.staffIdAccuracy(level: number): number
	return math.min(0.98, Config.StaffIdAccuracy + Config.StaffIdAccuracyPerLevel * (level - 1))
end

function Formulas.unlockedDishes(data)
	local list = {}
	for _, dish in Config.Dishes do
		if (data.dishes[dish.id] or 0) > 0 then
			table.insert(list, dish)
		end
	end
	return list
end

function Formulas.unlockedDrinks(data)
	local list = {}
	for _, drink in Config.Drinks do
		if data.drinks[drink.id] then
			table.insert(list, drink)
		end
	end
	return list
end

local function levelCost(spec, level: number): (number?, string?)
	if level >= spec.maxLevel then
		return nil, "MAX"
	end
	return math.floor(spec.baseCost * spec.growth ^ level), nil
end

-- Returns the cost of the next step for a purchase, or nil and a reason.
function Formulas.costOf(data, kind: string, id: string?): (number?, string?)
	if kind == "dish" then
		local dish = id and Config.getDish(id)
		if not dish then
			return nil, "Unknown dish"
		end
		local level = data.dishes[dish.id] or 0
		if level >= Config.DishMaxLevel then
			return nil, "MAX"
		end
		if level == 0 then
			local index = table.find(Config.Dishes, dish) :: number
			local previous = Config.Dishes[index - 1]
			if previous and (data.dishes[previous.id] or 0) < Config.UnlockAtLevel then
				return nil, `{previous.name} Lv {Config.UnlockAtLevel}`
			end
			return dish.unlockCost, nil
		end
		return math.floor(dish.baseUpgradeCost * dish.costGrowth ^ (level - 1)), nil
	elseif kind == "drink" then
		local drink = id and Config.getDrink(id)
		if not drink then
			return nil, "Unknown drink"
		end
		if data.drinks[drink.id] then
			return nil, "OWNED"
		end
		return drink.unlockCost, nil
	elseif kind == "staffHire" then
		local role = id and Config.Staff[id]
		if not role then
			return nil, "Unknown role"
		end
		local count = data.staff[id].count
		if count >= role.maxCount then
			return nil, "MAX"
		end
		return math.floor(role.hireBaseCost * role.hireGrowth ^ count), nil
	elseif kind == "staffSpeed" then
		local role = id and Config.Staff[id]
		if not role then
			return nil, "Unknown role"
		end
		local level = data.staff[id].speed
		if level >= role.maxSpeedLevel then
			return nil, "MAX"
		end
		return math.floor(role.speedBaseCost * role.speedGrowth ^ (level - 1)), nil
	elseif kind == "kitchenSpeed" then
		return levelCost(Config.KitchenSpeed, data.kitchenSpeed)
	elseif kind == "barSpeed" then
		return levelCost(Config.BarSpeed, data.barSpeed)
	elseif kind == "tables" then
		local t = Config.Tables
		if data.tables >= t.max then
			return nil, "MAX"
		end
		return math.floor(t.baseCost * t.growth ^ (data.tables - t.start)), nil
	elseif kind == "barSeats" then
		local b = Config.BarSeats
		if data.barSeats >= b.max then
			return nil, "MAX"
		end
		return math.floor(b.baseCost * b.growth ^ (data.barSeats - b.start)), nil
	elseif kind == "charm" then
		return levelCost(Config.Charm, data.charm)
	elseif kind == "marketing" then
		return levelCost(Config.Marketing, data.marketing)
	elseif kind == "decor" then
		local decor = id and Config.getDecor(id)
		if not decor then
			return nil, "Unknown item"
		end
		if data.decor[decor.id] then
			return nil, "OWNED"
		end
		return decor.cost, nil
	end
	return nil, "Unknown purchase"
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Formulas.formatMoney(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return "$" .. tostring(n)
	end
	local i = 1
	local value = n
	while value >= 1000 and i < #SUFFIXES do
		value /= 1000
		i += 1
	end
	return string.format("$%.2f%s", value, SUFFIXES[i])
end

function Formulas.stars(rating: number): string
	local full = math.clamp(math.floor(rating + 0.5), 0, 5)
	return string.rep("★", full) .. string.rep("☆", 5 - full)
end

return Formulas
