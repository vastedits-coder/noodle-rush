-- A pool of real Roblox avatars for customers and staff, fetched in the background.
-- Each entry keeps the userId so the client can show that avatar's headshot on ID cards.

local Players = game:GetService("Players")

local Avatars = {}

export type Avatar = { description: HumanoidDescription, userId: number? }

local POOL_SIZE = 40
local pool: { Avatar } = {}

local SKIN_TONES = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 100, 70),
	Color3.fromRGB(105, 64, 40),
}

local function fallback(): Avatar
	local d = Instance.new("HumanoidDescription")
	local skin = SKIN_TONES[math.random(1, #SKIN_TONES)]
	d.HeadColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.TorsoColor = Color3.fromHSV(math.random(), 0.6, 0.85)
	d.LeftLegColor = Color3.fromHSV(math.random(), 0.4, 0.4)
	d.RightLegColor = d.LeftLegColor
	return { description = d, userId = nil }
end

local function fetchRandom(): Avatar?
	local userId = math.random(1, 2000000000)
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if ok and description then
		return { description = description, userId = userId }
	end
	return nil
end

function Avatars.start()
	task.spawn(function()
		local failures = 0
		while #pool < POOL_SIZE and failures < 200 do
			local avatar = fetchRandom()
			if avatar then
				table.insert(pool, avatar)
			else
				failures += 1
			end
			task.wait(0.2)
		end
	end)
end

function Avatars.random(): Avatar
	if #pool == 0 then
		return fallback()
	end
	return pool[math.random(1, #pool)]
end

-- A different avatar with a userId, used as the wrong photo on a fake ID.
function Avatars.otherWithPhoto(notUserId: number?): Avatar?
	for _ = 1, 10 do
		local candidate = Avatars.random()
		if candidate.userId and candidate.userId ~= notUserId then
			return candidate
		end
	end
	return nil
end

return Avatars
