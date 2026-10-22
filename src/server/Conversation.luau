-- Conversations with customers: taking orders (with dish suggestions, drink upsells
-- and the "50% off, are you sure?" push), ID checks, the undercover inspector,
-- checking on a table, and reviews.
--
-- The player talks through the Dialog remotes. Staff use `auto`, which rolls the same
-- outcomes without UI (and can get ID checks wrong, depending on their level).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local IdCards = require(script.Parent.IdCards)

local DialogEvent = Remotes.event("Dialog")

local Conversation = {}

local TALK_DISTANCE = 16

local function money(n: number): string
	return Formulas.formatMoney(n)
end

local function charm(r): number
	return Formulas.charmBonus(r.session.data, r:passes().MasterUpseller == true)
end

local function dishPrice(r, dish): number
	return Formulas.dishPrice(dish, r.session.data.dishes[dish.id] or 1)
end

local function betterDish(r, current)
	local best = nil
	for _, dish in Formulas.unlockedDishes(r.session.data) do
		if dish ~= current and dishPrice(r, dish) > dishPrice(r, current) then
			if not best or dishPrice(r, dish) > dishPrice(r, best) then
				best = dish
			end
		end
	end
	return best
end

local function betterDrink(r, current)
	local best = nil
	for _, drink in Formulas.unlockedDrinks(r.session.data) do
		if drink ~= current and drink.price > current.price and (not best or drink.price > best.price) then
			best = drink
		end
	end
	return best
end

local function show(r, c, text: string, options, card)
	local allowed = {}
	for _, o in options do
		allowed[o.id] = true
	end
	c.convo.allowed = allowed
	DialogEvent:FireClient(r.session.player, {
		customerId = c.id,
		name = c.name,
		userId = c.npc.avatar.userId,
		text = text,
		options = options,
		card = card,
	})
end

local function close(r)
	DialogEvent:FireClient(r.session.player, { close = true })
end

-- Reviews -------------------------------------------------------------------------------

function Conversation.review(r, c, stars: number, text: string)
	local data = r.session.data
	stars = math.clamp(math.floor(stars + 0.5), 1, 5)
	table.insert(data.reviews, { stars = stars, text = text, name = c.name })
	while #data.reviews > Config.Reviews.keep do
		table.remove(data.reviews, 1)
	end
	r.session.review(stars, text, c.name)
	r.session.markDirty()
end

local HAPPY_LINES = {
	"Best noodles in town!",
	"Amazing food, I'll be back!",
	"So good. 10/10 would slurp again.",
	"Great service and great ramen!",
}
local OK_LINES = { "Pretty good.", "Decent food, nothing crazy.", "Not bad at all." }
local BAD_LINES = { "Meh. Could be better.", "Took too long and the vibe was off.", "Disappointing." }

function Conversation.reviewOnLeave(r, c)
	if c.inspector then
		return -- inspectors already filed their report
	end
	local stars = c.mood
	if c.waitedLong then
		stars -= 1
	end
	if c.checked then
		stars += 0.5
	end
	local text
	if c.refusedLegal then
		stars = 1
		text = "Refused my REAL ID. Never coming back!"
	elseif c.waitedLong and stars < 4 then
		text = "Food was okay but the wait was way too long."
	elseif stars >= 4.5 then
		text = HAPPY_LINES[math.random(1, #HAPPY_LINES)]
	elseif stars >= 3 then
		text = OK_LINES[math.random(1, #OK_LINES)]
	else
		text = BAD_LINES[math.random(1, #BAD_LINES)]
	end
	Conversation.review(r, c, stars, text)
end

-- Ordering --------------------------------------------------------------------------------

local function finish(r, c, text: string)
	c.convo.step = "done"
	show(r, c, text, { { id = "close", label = "OK" } })
	local draft = c.convo.draft
	if not r:barOpen() then
		draft.drink = nil
	end
	r:submitOrder(c, { dish = draft.dish, drink = draft.drink, discount = draft.discount })
end

local function drinkOptions(r, c, text: string)
	c.convo.step = "drinks"
	local options = {}
	if r:barOpen() then
		local drinks = Formulas.unlockedDrinks(r.session.data)
		-- Offer the newest (priciest) drinks first, up to four.
		table.sort(drinks, function(a, b)
			return a.price > b.price
		end)
		for i = 1, math.min(4, #drinks) do
			local d = drinks[i]
			table.insert(options, { id = "drink:" .. d.id, label = `Something to drink? {d.name} ({money(d.price)})` })
		end
	end
	table.insert(options, { id = "none", label = "That's all? Great, coming right up!" })
	show(r, c, text, options)
end

local function askId(r, c, drink, prefix: string)
	c.convo.step = "id"
	c.convo.pendingDrink = drink
	c.identity = c.identity or IdCards.generate(c.name, c.npc.avatar, drink.minAge, if c.inspector then "fake" else nil)
	show(r, c, `{prefix} Here's my ID.`, {
		{ id = "id_ok", label = "Looks good, enjoy!" },
		{ id = "id_refuse", label = "Sorry, I can't serve you this." },
	}, {
		name = c.identity.card.name,
		dob = c.identity.card.dob,
		expires = c.identity.card.expires,
		photoUserId = c.identity.card.photoUserId,
		today = c.identity.card.today,
		minAge = drink.minAge,
		drink = drink.name,
	})
end

-- The drink was accepted (maybe at a discount): check ID if needed, else finish.
local function drinkAccepted(r, c, drink, discount: number, line: string)
	c.convo.draft.discount = discount
	if drink.minAge then
		askId(r, c, drink, line)
	else
		c.convo.draft.drink = drink
		finish(r, c, line .. " That's all, thanks!")
	end
end

local function caughtByInspector(r, c): number
	local amount = r:fine()
	r.session.data.risk = 20
	Conversation.review(r, c, 1, "Inspection report: served a restricted drink with a bad ID.")
	return amount
end

local function passedInspection(r, c): number
	local amount = r:reward()
	r.session.data.risk = 0
	Conversation.review(r, c, 5, "Inspection passed. Responsible, well-run place!")
	return amount
end

local function handleIdDecision(r, c, accepted: boolean)
	local identity = c.identity
	local drink = c.convo.pendingDrink
	local data = r.session.data
	if accepted then
		if identity.legal then
			c.convo.draft.drink = drink
			finish(r, c, "Thanks!")
		elseif c.inspector then
			local fine = caughtByInspector(r, c)
			c.convo.draft.drink = nil
			finish(
				r,
				c,
				`Undercover inspector! That ID was no good. Fine: {money(fine)}, and your bar is closed for {Config.Risk.barClosedSeconds // 60} minutes.`
			)
		else
			c.convo.draft.drink = drink
			c.mood += 0.7
			c.servedIllegal = true
			data.risk = math.min(100, data.risk + Config.Risk.perFakeServed)
			finish(r, c, "Sweet, thanks!!")
		end
	else
		if identity.legal then
			c.mood -= 2.5
			c.refusedLegal = true
			c.convo.draft.drink = nil
			finish(r, c, "What?! That's my REAL ID! Unbelievable.")
		elseif c.inspector then
			local reward = passedInspection(r, c)
			c.convo.draft.drink = nil
			finish(r, c, `Undercover inspector! Good catch, you passed the inspection. Bonus: {money(reward)}`)
		else
			c.convo.draft.drink = nil
			finish(r, c, if identity.fake then "Ugh... worth a try." else "Okay, okay... I'm not old enough yet.")
		end
	end
end

function Conversation.begin(r, c)
	c.convo = { draft = { dish = nil, drink = nil, discount = 0 }, promoTried = false, started = os.clock() }
	if c.kind == "table" then
		c.convo.step = "intro"
		c.convo.draft.dish = c.wantDish
		local options = { { id = "accept", label = "Great choice, coming right up!" } }
		local better = betterDish(r, c.wantDish)
		if better then
			table.insert(options, {
				id = "suggest",
				label = `Have you tried our {better.name}? It's our best! ({money(dishPrice(r, better))})`,
			})
		end
		show(r, c, `Hi! I'm {c.name}. I'd like the {c.wantDish.name}, please.`, options)
	else
		c.convo.step = "bar_intro"
		if not r:barOpen() then
			finish(r, c, "The bar is closed? Ugh, okay...")
			return
		end
		local options = { { id = "accept", label = "Sure thing!" } }
		local better = betterDrink(r, c.wantDrink)
		if better then
			table.insert(options, {
				id = "suggest",
				label = `How about our {better.name} instead? ({money(better.price)})`,
			})
		end
		show(r, c, `Hey! I'm {c.name}. Can I get a {c.wantDrink.name}?`, options)
	end
end

function Conversation.onChoice(r, c, optionId: string)
	local convo = c.convo
	if not convo or not convo.allowed or not convo.allowed[optionId] then
		return
	end
	if convo.step ~= "done" and convo.step ~= "check" and not r:playerNear(c, TALK_DISTANCE) then
		close(r)
		r:cancelOrdering(c)
		r.session.notify("You walked away from the customer.")
		return
	end
	local data = r.session.data
	local step = convo.step

	if optionId == "close" then
		close(r)
		c.convo = nil
		return
	end

	if step == "intro" then
		if optionId == "suggest" then
			local better = betterDish(r, c.wantDish)
			if better and math.random() < Config.Upsell.suggestBase + charm(r) then
				convo.draft.dish = better
				drinkOptions(r, c, `Ooh, okay! I'll try the {better.name}.`)
			else
				drinkOptions(r, c, `Nah, I'll stick with the {c.wantDish.name}.`)
			end
		else
			drinkOptions(r, c, "Thanks!")
		end
	elseif step == "drinks" then
		if optionId == "none" then
			finish(r, c, "Perfect, thank you!")
			return
		end
		local drink = Config.getDrink(string.sub(optionId, 7))
		if not drink or not data.drinks[drink.id] then
			return
		end
		local chance = Config.Upsell.drinkBase + charm(r) + (if c.likesDrinks then 0.2 else 0)
		if math.random() < chance then
			drinkAccepted(r, c, drink, 0, "Sure, why not!")
		else
			convo.step = "drink_refused"
			convo.pendingDrink = drink
			show(r, c, "No thanks, I'm good.", {
				{
					id = "promo",
					label = `Are you sure? {drink.name} is new and {math.floor(Config.Upsell.promoDiscount * 100)}% off today!`,
				},
				{ id = "none", label = "No problem!" },
			})
		end
	elseif step == "drink_refused" then
		if optionId == "promo" then
			local drink = convo.pendingDrink
			if math.random() < Config.Upsell.promoBase + charm(r) then
				drinkAccepted(r, c, drink, Config.Upsell.promoDiscount, "Oh, half price? Okay, sure!")
			else
				c.mood -= 0.3
				finish(r, c, "Really, I'm fine. Just the food, thanks.")
			end
		else
			finish(r, c, "Thanks!")
		end
	elseif step == "bar_intro" then
		local drink = c.wantDrink
		local line = "Thanks!"
		if optionId == "suggest" then
			local better = betterDrink(r, drink)
			if better and math.random() < Config.Upsell.suggestBase + charm(r) then
				drink = better
				line = `Ooh, the {better.name}? Let's do it!`
			else
				line = `Nah, just the {drink.name} please.`
			end
		end
		drinkAccepted(r, c, drink, 0, line)
	elseif step == "id" then
		handleIdDecision(r, c, optionId == "id_ok")
	end
end

-- The player left a conversation open for too long.
function Conversation.timeout(r, c)
	close(r)
	Conversation.onClose(r, c)
end

-- Player closed the window (or walked away) before finishing.
function Conversation.onClose(r, c)
	if c.convo and c.convo.step ~= "done" and c.convo.step ~= "check" then
		r:cancelOrdering(c)
	end
	c.convo = nil
end

-- Staff ------------------------------------------------------------------------------------

function Conversation.auto(r, c, staffLevel: number)
	local order = { dish = nil, drink = nil, discount = 0 }
	local data = r.session.data
	local drink = nil
	if c.kind == "table" then
		order.dish = c.wantDish
		local better = betterDish(r, c.wantDish)
		if better and math.random() < 0.5 * (Config.Upsell.suggestBase + charm(r)) then
			order.dish = better
		end
		local drinks = Formulas.unlockedDrinks(data)
		local chance = Config.Upsell.drinkBase + charm(r) + (if c.likesDrinks then 0.2 else 0)
		if r:barOpen() and #drinks > 0 and math.random() < chance then
			drink = drinks[math.random(1, #drinks)]
		end
	elseif r:barOpen() then
		drink = c.wantDrink
	end

	if drink and drink.minAge then
		c.identity = c.identity
			or IdCards.generate(c.name, c.npc.avatar, drink.minAge, if c.inspector then "fake" else nil)
		local accuracy = Formulas.staffIdAccuracy(staffLevel)
		if c.identity.legal then
			if math.random() < 0.97 then
				order.drink = drink
			else
				c.mood -= 2.5
				c.refusedLegal = true
			end
		elseif math.random() < accuracy then
			if c.inspector then
				local reward = passedInspection(r, c)
				r.session.notify(`Your staff spotted an undercover inspector's fake ID! Bonus {money(reward)}`)
			end
		elseif c.inspector then
			local fine = caughtByInspector(r, c)
			r.session.notify(`Your staff served an undercover inspector with a fake ID! Fine: {money(fine)}`)
		else
			order.drink = drink
			c.servedIllegal = true
			data.risk = math.min(100, data.risk + Config.Risk.perFakeServed)
		end
	else
		order.drink = drink
	end
	return order
end

-- Checking on a table -------------------------------------------------------------------

local COMPLIMENTS = {
	"Everything is delicious!",
	"Honestly the best noodles I've had.",
	"Love it here!",
	"So good, my compliments to the chef!",
}

local function feedback(r, c): string?
	local data = r.session.data
	local ideas = {}
	if c.waitedLong then
		table.insert(
			ideas,
			if data.staff.chef.count == 0
				then "The food took a while... maybe hire a chef?"
				else "The food took a while... the kitchen could be faster."
		)
	end
	if os.clock() - r.turnedAwayAt < 120 and data.tables < Config.Tables.max then
		table.insert(ideas, "It was hard to get a table. You need more tables!")
	end
	if not data.decor.speakers then
		table.insert(ideas, "Some music would be really nice in here.")
	end
	if not data.decor.tv then
		table.insert(ideas, "A TV would be cool to watch while eating.")
	end
	if not data.decor.plants then
		table.insert(ideas, "It feels a bit empty. Some plants maybe?")
	end
	if #Formulas.unlockedDrinks(data) < 4 then
		table.insert(ideas, "You should add more drinks to the menu!")
	end
	if #ideas == 0 then
		return nil
	end
	-- Mostly the most important idea, sometimes the next one, so it doesn't repeat.
	return ideas[math.min(#ideas, math.random(1, 2))]
end

function Conversation.checkOnTable(r, c)
	c.checked = true
	c.mood += 0.5
	c.tipBonus = Config.Customers.checkTipBonus
	r:refreshPrompt(c)
	c.convo = { step = "check", draft = {} }
	local text = COMPLIMENTS[math.random(1, #COMPLIMENTS)]
	if c.mood < 3.5 then
		text = "It's okay..."
	end
	local idea = feedback(r, c)
	if idea then
		text ..= " " .. idea
	end
	if c.mood >= 3.5 then
		text ..= " I'll leave you a nice tip!"
	end
	show(r, c, text, { { id = "close", label = "Thank you, enjoy!" } })
end

return Conversation
