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

function Formulas.dishCookTime(dish, level: number): number
	return dish.cookTime * 0.85 ^ Formulas.milestonesReached(level)
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

function Formulas.spawnInterval(data): number
	local m = Config.Marketing
	return math.max(m.minInterval, m.baseInterval * m.intervalFactor ^ data.marketing)
end

function Formulas.upsellChance(data, hasMasterUpseller: boolean): number
	local chance = data.upsell * Config.Upsell.chancePerLevel
	if hasMasterUpseller then
		chance += 0.25
	end
	return math.min(chance, 0.95)
end

function Formulas.staffWalkSpeed(level: number): number
	return Config.StaffBaseWalkSpeed + Config.StaffWalkPerLevel * (level - 1)
end

function Formulas.staffWorkMultiplier(level: number): number
	return 1 + Config.StaffWorkPerLevel * (level - 1)
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
				return nil, `Needs {previous.name} Lv {Config.UnlockAtLevel}`
			end
			return dish.unlockCost, nil
		end
		return math.floor(dish.baseUpgradeCost * dish.costGrowth ^ (level - 1)), nil
	elseif kind == "staffHire" then
		local role = id and Config.Staff[id]
		if not role then
			return nil, "Unknown role"
		end
		local count = data.staff[id].count
		if count >= role.maxCount then
			return nil, "MAX"
		end
		return math.floor(role.hireBaseCost * role.hireGrowth ^ math.max(0, count - role.startCount)), nil
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
	elseif kind == "tables" then
		local t = Config.Tables
		if data.tables >= t.max then
			return nil, "MAX"
		end
		return math.floor(t.baseCost * t.growth ^ (data.tables - t.start)), nil
	elseif kind == "upsell" then
		local u = Config.Upsell
		if data.upsell >= u.maxLevel then
			return nil, "MAX"
		end
		return math.floor(u.baseCost * u.growth ^ data.upsell), nil
	elseif kind == "marketing" then
		local m = Config.Marketing
		if data.marketing >= m.maxLevel then
			return nil, "MAX"
		end
		return math.floor(m.baseCost * m.growth ^ data.marketing), nil
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

return Formulas
