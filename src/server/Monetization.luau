-- Game Passes (permanent) and Developer Products (consumable).
-- IDs live in Config; an id of 0 is skipped until you create the item in Creator Hub.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Monetization = {}

local getSession: (Player) -> any = function()
	return nil
end

local function passByKey(key: string)
	for _, pass in Config.GamePasses do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

local function productById(id: number)
	for _, product in Config.Products do
		if product.id ~= 0 and product.id == id then
			return product
		end
	end
	return nil
end

-- Returns { [passKey] = true } for every pass the player owns.
function Monetization.loadPasses(player: Player)
	local owned = {}
	for _, pass in Config.GamePasses do
		if pass.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and has then
				owned[pass.key] = true
			end
		end
	end
	return owned
end

local function incomeForMinutes(session, minutes: number, minimum: number): number
	local perMinute = math.max(session.currentIncomePerMin(), session.data.incomePerMin)
	return math.max(minimum, math.floor(perMinute * minutes))
end

local PRODUCT_HANDLERS = {
	CashSmall = function(session)
		local amount = incomeForMinutes(session, 5, 100)
		session.addCash(amount)
		session.notify(`+{amount} cash! Thanks for supporting the game.`)
	end,
	CashBig = function(session)
		local amount = incomeForMinutes(session, 60, 1500)
		session.addCash(amount)
		session.notify(`+{amount} cash! Thanks for supporting the game.`)
	end,
	RushHour = function(session)
		local now = os.time()
		session.runtime.rushUntil = math.max(session.runtime.rushUntil, now) + Config.RushHourSeconds
		session.notify("RUSH HOUR! 3x customers for 15 minutes.")
	end,
	CalmEveryone = function(session)
		if session.restaurant then
			session.restaurant:calmEveryone()
		end
		session.notify("Everyone calmed down.")
	end,
}

function Monetization.init(sessionLookup: (Player) -> any)
	getSession = sessionLookup

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local session = getSession(player)
		if not session then
			return
		end
		for _, pass in Config.GamePasses do
			if pass.id == passId then
				session.passes[pass.key] = true
				session.notify(`You got {pass.name}!`)
				session.markDirty()
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local session = player and getSession(player)
		local product = productById(receipt.ProductId)
		if not session or not product then
			-- Roblox retries later (for example when the player rejoins).
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Guard against granting the same purchase twice.
		local receipts = session.data.receipts
		if receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local handler = PRODUCT_HANDLERS[product.key]
		if not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		handler(session)
		receipts[receipt.PurchaseId] = os.time()
		session.markDirty()
		if not session.saveNow() then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

Monetization.passByKey = passByKey

return Monetization
