-- All screen UI, built in code: HUD, upgrade panel with tabs, Robux shop, toasts and reviews.
-- The customer conversation window lives in DialogUI.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraToggle = require(script.Parent.CameraToggle)
local Theme = require(script.Parent.Theme)

local Purchase = Remotes.func("Purchase")

local UI = {}

local player = Players.LocalPlayer
local state = nil
local currentTab = "Menu"
local TABS = { "Menu", "Bar", "Staff", "Restaurant", "Shop" }

local COLORS = Theme.colors
local create = Theme.create
local corner = Theme.corner
local textLabel = Theme.textLabel

-- Screen ---------------------------------------------------------------------------------

local screen = create("ScreenGui", {
	Name = "NoodleRushUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
UI.screen = screen

local topBar = create("Frame", {
	Size = UDim2.fromOffset(320, 96),
	Position = UDim2.fromOffset(12, 12),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.1,
	Parent = screen,
}, { corner(14), Theme.stroke() })
local cashLabel = textLabel({
	Size = UDim2.new(1, -24, 0, 40),
	Position = UDim2.fromOffset(12, 6),
	Text = "$0",
	Font = Enum.Font.FredokaOne,
	TextColor3 = COLORS.money,
	Parent = topBar,
})
local ratingLabel = textLabel({
	Size = UDim2.new(1, -24, 0, 22),
	Position = UDim2.fromOffset(12, 46),
	Text = "",
	TextColor3 = COLORS.gold,
	Parent = topBar,
})
local infoLabel = textLabel({
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.fromOffset(12, 70),
	Text = "",
	Font = Enum.Font.Gotham,
	TextColor3 = COLORS.subtext,
	Parent = topBar,
})

local sideButtons = create("Frame", {
	Size = UDim2.fromOffset(160, 172),
	Position = UDim2.new(1, -172, 0.5, -86),
	BackgroundTransparency = 1,
	Parent = screen,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function sideButton(text: string, color: Color3, order: number): TextButton
	return create("TextButton", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = color,
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = COLORS.text,
		LayoutOrder = order,
		Parent = sideButtons,
	}, { corner(12), Theme.stroke(), Theme.padding(8) })
end

local upgradesButton = sideButton("Upgrades [F]", COLORS.accent, 1)
local shopButton = sideButton("Shop [G]", COLORS.robux, 2)
local cameraButton = sideButton("Camera [V]", COLORS.blue, 3)

-- Toasts and reviews ------------------------------------------------------------------

local toastHolder = create("Frame", {
	Size = UDim2.new(0, 560, 0, 260),
	Position = UDim2.new(0.5, -280, 0, 12),
	BackgroundTransparency = 1,
	Parent = screen,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

local function fadeAway(frame: GuiObject, delay: number)
	task.delay(delay, function()
		local info = TweenInfo.new(0.5)
		for _, d in frame:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			end
		end
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		frame:Destroy()
	end)
end

function UI.toast(text: string)
	local label = textLabel({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = COLORS.panel,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = toastHolder,
	})
	corner(10).Parent = label
	Theme.padding(10).Parent = label
	fadeAway(label, 3.5)
end

function UI.review(review)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = COLORS.cream,
		Parent = toastHolder,
	}, { corner(10), Theme.stroke(), Theme.padding(10) })
	textLabel({
		Size = UDim2.new(1, 0, 0.5, 0),
		Text = `{Formulas.stars(review.stars)}  {review.name}`,
		TextColor3 = if review.stars >= 4 then COLORS.goldDark else COLORS.danger,
		Parent = frame,
	})
	textLabel({
		Size = UDim2.new(1, 0, 0.5, 0),
		Position = UDim2.fromScale(0, 0.5),
		Text = `"{review.text}"`,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.dark,
		Parent = frame,
	})
	fadeAway(frame, 5)
end

-- Panel ----------------------------------------------------------------------------------

local panel = create("Frame", {
	Size = UDim2.fromScale(0.55, 0.7),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.panel,
	Visible = false,
	Parent = screen,
}, {
	corner(16),
	Theme.stroke(),
	create("UISizeConstraint", { MinSize = Vector2.new(340, 320), MaxSize = Vector2.new(720, 600) }),
})

-- A visible Modal button frees the mouse while in first person.
local closeButton = create("TextButton", {
	Size = UDim2.fromOffset(38, 38),
	Position = UDim2.new(1, -46, 0, 8),
	BackgroundColor3 = COLORS.danger,
	Text = "X",
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = COLORS.text,
	Modal = true,
	Parent = panel,
}, { corner(10) })

local tabBar = create("Frame", {
	Size = UDim2.new(1, -66, 0, 38),
	Position = UDim2.fromOffset(10, 8),
	BackgroundTransparency = 1,
	Parent = panel,
}, {
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local list = create("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -64),
	Position = UDim2.fromOffset(10, 56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = panel,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local tabButtons = {}
local rows = {}

local function clearRows()
	for _, row in rows do
		row.frame:Destroy()
	end
	rows = {}
end

-- Row definitions ------------------------------------------------------------------------

type RowDef = {
	key: string,
	title: string,
	sub: string,
	buttonText: string,
	enabled: boolean,
	robux: boolean?,
	onClick: () -> (),
}

local function buyCash(kind: string, id: string?)
	return function()
		local ok, message = Purchase:InvokeServer(kind, id)
		if not ok and message then
			UI.toast(message)
		end
	end
end

local function cashRow(key: string, title: string, sub: string, kind: string, id: string?): RowDef
	local cost, reason = Formulas.costOf(state.data, kind, id)
	return {
		key = key,
		title = title,
		sub = sub,
		buttonText = if cost then (if cost == 0 then "FREE" else Formulas.formatMoney(cost)) else (reason or "-"),
		enabled = cost ~= nil and state.data.cash >= cost,
		onClick = buyCash(kind, id),
	}
end

local function levelRow(key: string, name: string, level: number, maxLevel: number, sub: string, kind: string)
	return cashRow(key, `{name}  Lv {level}/{maxLevel}`, sub, kind)
end

local function menuRows(): { RowDef }
	local data = state.data
	local defs = {}
	for _, dish in Config.Dishes do
		local level = data.dishes[dish.id] or 0
		local nextMilestone = nil
		for _, m in Config.DishMilestones do
			if level < m then
				nextMilestone = m
				break
			end
		end
		local title = if level > 0 then `{dish.name}  Lv {level}/{Config.DishMaxLevel}` else `{dish.name} (locked)`
		local sub = if level > 0
			then `Sells for {Formulas.formatMoney(Formulas.dishPrice(dish, level))}, cooks in {string.format(
				"%.1f",
				Formulas.cookTime(dish, level, data.kitchenSpeed)
			)}s` .. (if nextMilestone then ` · Lv {nextMilestone}: price x2` else "")
			else "Unlock to add it to the menu"
		table.insert(defs, cashRow("dish_" .. dish.id, title, sub, "dish", dish.id))
	end
	table.insert(
		defs,
		levelRow(
			"kitchenSpeed",
			"Kitchen speed",
			data.kitchenSpeed,
			Config.KitchenSpeed.maxLevel,
			"Everything cooks faster (you and your chefs)",
			"kitchenSpeed"
		)
	)
	return defs
end

local function barRows(): { RowDef }
	local data = state.data
	local defs = {}
	for _, drink in Config.Drinks do
		local sub = `Sells for {Formulas.formatMoney(drink.price)}`
		if drink.minAge then
			sub ..= ` · {drink.minAge}+ only, check IDs!`
		end
		table.insert(defs, cashRow("drink_" .. drink.id, drink.name, sub, "drink", drink.id))
	end
	table.insert(
		defs,
		levelRow(
			"barSpeed",
			"Bar speed",
			data.barSpeed,
			Config.BarSpeed.maxLevel,
			"Drinks are poured faster",
			"barSpeed"
		)
	)
	table.insert(
		defs,
		cashRow(
			"barSeats",
			`Bar stools ({data.barSeats}/{Config.BarSeats.max})`,
			"More customers can sit at the bar",
			"barSeats"
		)
	)
	return defs
end

local function staffRows(): { RowDef }
	local defs = {}
	for _, roleId in Config.StaffOrder do
		local role = Config.Staff[roleId]
		local s = state.data.staff[roleId]
		table.insert(
			defs,
			cashRow("hire_" .. roleId, `Hire {role.name} ({s.count}/{role.maxCount})`, role.desc, "staffHire", roleId)
		)
		if s.count > 0 then
			local sub = `Walks {string.format("%.1f", Formulas.staffWalkSpeed(s.speed))} studs/s, works x{string.format(
				"%.2f",
				Formulas.staffWorkMultiplier(s.speed)
			)}`
			if roleId ~= "chef" then
				sub ..= `, spots {math.floor(Formulas.staffIdAccuracy(s.speed) * 100)}% of fake IDs`
			end
			table.insert(
				defs,
				cashRow(
					"speed_" .. roleId,
					`{role.name} training  Lv {s.speed}/{role.maxSpeedLevel}`,
					sub,
					"staffSpeed",
					roleId
				)
			)
		end
	end
	return defs
end

local function restaurantRows(): { RowDef }
	local data = state.data
	local defs = {
		cashRow("tables", `Tables ({data.tables}/{Config.Tables.max})`, "More seats, more customers at once", "tables"),
		levelRow(
			"charm",
			"Charm",
			data.charm,
			Config.Charm.maxLevel,
			`+{math.floor(Formulas.charmBonus(data, state.passes.MasterUpseller == true) * 100)}% on suggestions and upsells`,
			"charm"
		),
		levelRow(
			"marketing",
			"Marketing",
			data.marketing,
			Config.Marketing.maxLevel,
			`A new customer every {string.format("%.1f", Formulas.spawnInterval(data))}s`,
			"marketing"
		),
	}
	for _, decor in Config.Decor do
		table.insert(
			defs,
			cashRow("decor_" .. decor.id, decor.name, `+{decor.atmosphere} atmosphere`, "decor", decor.id)
		)
	end
	return defs
end

local function shopRows(): { RowDef }
	local defs = {}
	for _, pass in Config.GamePasses do
		local owned = state.passes[pass.key] == true
		table.insert(defs, {
			key = "pass_" .. pass.key,
			title = pass.name .. " (Game Pass)",
			sub = pass.desc,
			buttonText = if owned then "OWNED" else `R$ {pass.price}`,
			enabled = not owned,
			robux = true,
			onClick = function()
				if pass.id == 0 then
					UI.toast("This pass isn't set up yet.")
				else
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end,
		})
	end
	for _, product in Config.Products do
		table.insert(defs, {
			key = "product_" .. product.key,
			title = product.name,
			sub = product.desc,
			buttonText = `R$ {product.price}`,
			enabled = true,
			robux = true,
			onClick = function()
				if product.id == 0 then
					UI.toast("This item isn't set up yet.")
				else
					MarketplaceService:PromptProductPurchase(player, product.id)
				end
			end,
		})
	end
	return defs
end

local ROW_BUILDERS = {
	Menu = menuRows,
	Bar = barRows,
	Staff = staffRows,
	Restaurant = restaurantRows,
	Shop = shopRows,
}

local function makeRow(def: RowDef, order: number)
	local frame = create("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = COLORS.row,
		LayoutOrder = order,
		Parent = list,
	}, { corner(12) })
	local title = textLabel({
		Size = UDim2.new(1, -156, 0, 26),
		Position = UDim2.fromOffset(12, 7),
		Font = Enum.Font.FredokaOne,
		Parent = frame,
	})
	local sub = textLabel({
		Size = UDim2.new(1, -156, 0, 20),
		Position = UDim2.fromOffset(12, 36),
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subtext,
		Parent = frame,
	})
	local button = create("TextButton", {
		Size = UDim2.fromOffset(130, 46),
		Position = UDim2.new(1, -138, 0.5, -23),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = COLORS.text,
		Parent = frame,
	}, { corner(10), Theme.padding(6) })
	local row = { frame = frame, title = title, sub = sub, button = button, onClick = def.onClick }
	button.Activated:Connect(function()
		row.onClick()
	end)
	return row
end

local function render()
	if not state then
		return
	end
	local data = state.data
	cashLabel.Text = Formulas.formatMoney(data.cash)
	ratingLabel.Text = `{Formulas.stars(state.rating)} {string.format("%.1f", state.rating)}  ({#data.reviews} reviews)`
	local info = `{Formulas.formatMoney(state.incomePerMin)}/min · Vibe {state.atmosphere}`
	if data.risk >= 1 then
		info ..= ` · Risk {math.floor(data.risk)}%`
	end
	if state.rushSecondsLeft > 0 then
		info ..= ` · RUSH {math.ceil(state.rushSecondsLeft / 60)}m`
	end
	if state.barClosedSeconds > 0 then
		info ..= ` · BAR CLOSED {state.barClosedSeconds}s`
	end
	infoLabel.Text = info

	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then COLORS.accent else COLORS.row
	end

	if not panel.Visible then
		return
	end
	local defs = ROW_BUILDERS[currentTab]()
	local seen = {}
	for i, def in defs do
		seen[def.key] = true
		local row = rows[def.key] or makeRow(def, i)
		rows[def.key] = row
		row.frame.LayoutOrder = i
		row.onClick = def.onClick
		row.title.Text = def.title
		row.sub.Text = def.sub
		row.button.Text = def.buttonText
		row.button.AutoButtonColor = def.enabled
		row.button.BackgroundColor3 = if not def.enabled
			then COLORS.disabled
			elseif def.robux then COLORS.robux
			else COLORS.buy
	end
	for key, row in rows do
		if not seen[key] then
			row.frame:Destroy()
			rows[key] = nil
		end
	end
end

local function openTab(name: string)
	if panel.Visible and currentTab == name then
		panel.Visible = false
		return
	end
	if currentTab ~= name then
		clearRows()
	end
	currentTab = name
	panel.Visible = true
	render()
end

for i, name in TABS do
	local button = create("TextButton", {
		Size = UDim2.new(1 / #TABS, -5, 1, 0),
		BackgroundColor3 = COLORS.row,
		Text = name,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = COLORS.text,
		LayoutOrder = i,
		Parent = tabBar,
	}, { corner(10), Theme.padding(4) })
	button.Activated:Connect(function()
		if currentTab ~= name then
			openTab(name)
		end
	end)
	tabButtons[name] = button
end

local function openUpgrades()
	openTab(if currentTab == "Shop" then "Menu" else currentTab)
end

closeButton.Activated:Connect(function()
	panel.Visible = false
end)
upgradesButton.Activated:Connect(openUpgrades)
shopButton.Activated:Connect(function()
	openTab("Shop")
end)
cameraButton.Activated:Connect(CameraToggle.toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		openUpgrades()
	elseif input.KeyCode == Enum.KeyCode.G then
		openTab("Shop")
	end
end)

function UI.setState(newState)
	state = newState
	render()
end

function UI.init()
	screen.Parent = player:WaitForChild("PlayerGui")
end

return UI
