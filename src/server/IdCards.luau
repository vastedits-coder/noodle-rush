-- Generates customer identities and ID cards for age-restricted drinks.
-- A card can be real (adult or underage) or fake with exactly one flaw to spot:
-- expired, wrong name, wrong photo, or a date that doesn't exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Avatars = require(script.Parent.Avatars)

local IdCards = {}

local FIRST_NAMES = {
	"Alex",
	"Maya",
	"Leo",
	"Sofia",
	"Noah",
	"Emma",
	"Liam",
	"Ava",
	"Lucas",
	"Mia",
	"Ethan",
	"Zoe",
	"Ryan",
	"Chloe",
	"Kai",
	"Luna",
	"Adam",
	"Ella",
	"Sam",
	"Nina",
	"Victor",
	"Ioana",
	"Andrei",
	"Elena",
	"Mateo",
	"Hana",
	"Omar",
	"Yuki",
	"Jin",
	"Sara",
}
local LAST_NAMES = {
	"Smith",
	"Popescu",
	"Kim",
	"Garcia",
	"Novak",
	"Silva",
	"Tanaka",
	"Brown",
	"Rossi",
	"Ionescu",
	"Lee",
	"Martin",
	"Costa",
	"Weber",
	"Park",
	"Nguyen",
	"Lopez",
	"Dumitru",
	"Sato",
	"Fischer",
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function formatDate(day: number, month: number, year: number): string
	return string.format("%02d.%02d.%04d", day, month, year)
end

function IdCards.today()
	local t = os.date("!*t")
	return { day = t.day, month = t.month, year = t.year, text = formatDate(t.day, t.month, t.year) }
end

function IdCards.randomName(): string
	return pick(FIRST_NAMES) .. " " .. pick(LAST_NAMES)
end

-- avatar: the customer's avatar (its userId is the photo on a real card)
-- minAge: the drink's age limit
-- kind: "real" | "fake" (nil = random by Config.Risk.fakeIdChance)
function IdCards.generate(name: string, avatar: Avatars.Avatar, minAge: number, kind: string?)
	local today = IdCards.today()
	local isFake = if kind then kind == "fake" else math.random() < Config.Risk.fakeIdChance
	local realAge
	if isFake then
		realAge = math.random(math.max(10, minAge - 4), minAge - 1)
	else
		-- Most real IDs are adults; some honest teens try their luck too.
		realAge = if math.random() < 0.2 then math.random(minAge - 3, minAge - 1) else math.random(minAge, 55)
	end

	local cardAge = if isFake then math.random(minAge + 1, minAge + 8) else realAge
	local birthMonth = math.random(1, 12)
	local birthDay = math.random(1, 28)
	-- Make sure the birthday already happened this year, so the age reads exactly.
	if birthMonth > today.month or (birthMonth == today.month and birthDay > today.day) then
		birthMonth = math.max(1, today.month - 1)
		birthDay = math.min(birthDay, 28)
		if today.month == 1 then
			birthMonth = 1
			birthDay = 1
		end
	end
	local card = {
		name = name,
		dob = formatDate(birthDay, birthMonth, today.year - cardAge),
		expires = formatDate(math.random(1, 28), math.random(1, 12), today.year + math.random(1, 6)),
		photoUserId = avatar.userId,
		today = today.text,
	}

	local flaw = nil
	if isFake then
		local flaws = { "expired", "name", "date" }
		if avatar.userId and Avatars.otherWithPhoto(avatar.userId) then
			table.insert(flaws, "photo")
		end
		flaw = pick(flaws)
		if flaw == "expired" then
			card.expires = formatDate(math.random(1, 28), math.random(1, 12), today.year - math.random(1, 3))
		elseif flaw == "name" then
			local first = string.split(name, " ")[1]
			local other = first
			while other == first do
				other = pick(FIRST_NAMES)
			end
			card.name = other .. " " .. string.split(name, " ")[2]
		elseif flaw == "date" then
			card.dob = formatDate(math.random(30, 31), 2, today.year - cardAge)
		elseif flaw == "photo" then
			local other = Avatars.otherWithPhoto(avatar.userId)
			card.photoUserId = other and other.userId
		end
	end

	return {
		card = card,
		realAge = realAge,
		fake = isFake,
		flaw = flaw,
		-- Serving is legal only with a real card showing the right age.
		legal = not isFake and realAge >= minAge,
	}
end

return IdCards
