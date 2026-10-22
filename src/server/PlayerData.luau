-- Loads and saves player progress with DataStoreService.
-- If loading fails we never save, so a hiccup can't wipe someone's progress.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

local store: DataStore? = nil
local ok, result = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if ok then
	store = result
else
	warn("[PlayerData] DataStore unavailable (enable API Services in Game Settings to save in Studio):", result)
end

local function defaultData()
	local staff = {}
	for roleId in Config.Staff do
		staff[roleId] = { count = 0, speed = 1 }
	end
	return {
		version = 2,
		cash = 0,
		totalEarned = 0,
		served = 0,
		angry = 0,
		dishes = { ramen = 1 },
		drinks = { juice = true, volt = true },
		staff = staff,
		tables = Config.Tables.start,
		barSeats = Config.BarSeats.start,
		kitchenSpeed = 0,
		barSpeed = 0,
		charm = 0,
		marketing = 0,
		decor = {},
		reviews = {}, -- newest last: { stars = 1-5, text = string }
		risk = 0,
		receipts = {}, -- [PurchaseId] = os.time(), so a product is never granted twice
		incomePerMin = 0,
		lastOnline = 0,
	}
end

-- Fill keys that were added to the defaults after the player last saved.
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
	return target
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- Returns data and whether it is safe to save later.
function PlayerData.load(player: Player): (any, boolean)
	if not store then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local success, value = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if success then
			if value == nil then
				return defaultData(), true
			end
			return reconcile(value, defaultData()), true
		end
		warn(`[PlayerData] load attempt {attempt} failed for {player.Name}:`, value)
		task.wait(attempt)
	end
	return defaultData(), false
end

function PlayerData.save(player: Player, data): boolean
	if not store then
		return false
	end
	data.lastOnline = os.time()
	for attempt = 1, 3 do
		local success, err = pcall(function()
			store:SetAsync(keyFor(player), data, { player.UserId })
		end)
		if success then
			return true
		end
		warn(`[PlayerData] save attempt {attempt} failed for {player.Name}:`, err)
		task.wait(attempt)
	end
	return false
end

return PlayerData
