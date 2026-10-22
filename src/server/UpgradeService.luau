-- Validates and applies cash purchases requested by the client.
-- The client only says what it wants; prices and rules are checked here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local RestaurantBuilder = require(script.Parent.RestaurantBuilder)

local UpgradeService = {}

local VALID_KINDS = {
	dish = true,
	staffHire = true,
	staffSpeed = true,
	tables = true,
	upsell = true,
	marketing = true,
	decor = true,
}

local function apply(session, kind: string, id: string?)
	local data = session.data
	if kind == "dish" then
		local dishId = id :: string
		data.dishes[dishId] = (data.dishes[dishId] or 0) + 1
		RestaurantBuilder.updateStations(session.layout, data)
	elseif kind == "staffHire" then
		data.staff[id :: string].count += 1
		session.restaurant:syncStaff()
	elseif kind == "staffSpeed" then
		data.staff[id :: string].speed += 1
	elseif kind == "tables" then
		data.tables += 1
		RestaurantBuilder.setTables(session.layout, data.tables)
	elseif kind == "upsell" then
		data.upsell += 1
	elseif kind == "marketing" then
		data.marketing += 1
	elseif kind == "decor" then
		data.decor[id :: string] = true
		RestaurantBuilder.updateDecor(session.layout, data)
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
