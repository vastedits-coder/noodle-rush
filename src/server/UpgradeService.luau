-- Validates and applies cash purchases requested by the client.
-- The client only says what it wants; prices and rules are checked here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local RestaurantBuilder = require(script.Parent.RestaurantBuilder)

local UpgradeService = {}

local VALID_KINDS = {
	dish = true,
	drink = true,
	staffHire = true,
	staffSpeed = true,
	kitchenSpeed = true,
	barSpeed = true,
	tables = true,
	barSeats = true,
	charm = true,
	marketing = true,
	decor = true,
}

local function apply(session, kind: string, id: string?)
	local data = session.data
	local layout = session.layout
	if kind == "dish" then
		local dishId = id :: string
		data.dishes[dishId] = (data.dishes[dishId] or 0) + 1
		RestaurantBuilder.updateStations(layout, data)
	elseif kind == "drink" then
		data.drinks[id :: string] = true
		RestaurantBuilder.updateDispensers(layout, data)
	elseif kind == "staffHire" then
		data.staff[id :: string].count += 1
		session.restaurant:syncStaff()
	elseif kind == "staffSpeed" then
		data.staff[id :: string].speed += 1
	elseif kind == "tables" then
		data.tables += 1
		RestaurantBuilder.setTables(layout, data.tables)
	elseif kind == "barSeats" then
		data.barSeats += 1
		RestaurantBuilder.setBarSeats(layout, data.barSeats)
	elseif kind == "decor" then
		data.decor[id :: string] = true
		RestaurantBuilder.updateDecor(layout, data)
	else
		-- kitchenSpeed, barSpeed, charm, marketing: plain levels
		data[kind] += 1
	end
end

function UpgradeService.purchase(session, kind: unknown, id: unknown): (boolean, string?)
	if type(kind) ~= "string" or not VALID_KINDS[kind] then
		return false, "Invalid purchase"
	end
	if id ~= nil and type(id) ~= "string" then
		return false, "Invalid item"
	end
	if (kind == "staffHire" or kind == "staffSpeed") and not Config.Staff[id :: string] then
		return false, "Invalid role"
	end
	local cost, reason = Formulas.costOf(session.data, kind, id :: string?)
	if not cost then
		return false, reason
	end
	if session.data.cash < cost then
		return false, "Not enough cash"
	end
	session.data.cash -= cost
	apply(session, kind, id :: string?)
	session.markDirty()
	return true, nil
end

return UpgradeService
