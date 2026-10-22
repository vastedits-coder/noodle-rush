-- All screen UI, built in code: cash bar, upgrade panel with tabs, Robux shop, toasts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CameraToggle = require(script.Parent.CameraToggle)

local Purchase = Remotes.func("Purchase")

local UI = {}

local player = Players.LocalPlayer
local state = nil
local currentTab = "Menu"
local TABS = { "Menu", "Staff", "Restaurant", "Shop" }

local COLORS = {
	panel = Color3.fromRGB(28, 24, 30),
	row = Color3.fromRGB(45, 40, 50),
	accent = Color3.fromRGB(235, 90, 50),
	buy = Color3.fromRGB(70, 190, 90),
	disabled = Color3.fromRGB(90, 90, 95),
	robux = Color3.fromRGB(40, 160, 90),
	text = Color3.fromRGB(255, 255, 255),
	subtext = Color3.fromRGB(200, 195, 205),
}

local function create(className: string, props, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function textLabel(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return create("TextLabel", defaults)
end

-- Screen ---------------------------------------------------------------------

local screen = create("ScreenGui", {
	Name = "NoodleRushUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local topBar = create("Frame", {
	Size = UDim2.fromOffset(300, 74),
	Position = UDim2.fromOffset(12, 12),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.15,
	Parent = screen,
}, { corner(12) })
local cashLabel = textLabel({
	Size = UDim2.new(1, -24, 0, 38),
	Position = UDim2.fromOffset(12, 6),
	Text = "$0",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(120, 255, 130),
	Parent = topBar,
})
local infoLabel = textLabel({
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.fromOffset(12, 46),
	Text = "",
	Font = Enum.Font.Gotham,
	TextColor3 = COLORS.subtext,
	Parent = topBar,
})

local sideButtons = create("Frame", {
	Size = UDim2.fromOffset(150, 170),
	Position = UDim2.new(1, -162, 0.5, -85),
	BackgroundTransparency = 1,
	Parent = screen,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function sideButton(text: string, color: Color3, order: number): TextButton
	return create("TextButton", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = color,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = COLORS.text,
		LayoutOrder = order,
		AutoButtonColor = true,
		Parent = sideButtons,
	}, { corner(10), create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
end

local upgradesButton = sideButton("Upgrades [F]", COLORS.accent, 1)
local shopButton = sideButton("Shop [G]", COLORS.robux, 2)
local cameraButton = sideButton("Camera [V]", Color3.fromRGB(70, 90, 160), 3)

-- Toasts -------------------------------------------------------------------

local toastHolder = create("Frame", {
	Size = UDim2.new(0, 520, 0, 200),
	Position = UDim2.new(0.5, -260, 0, 12),
	BackgroundTransparency = 1,
	Parent = screen,
}, {
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}),
})

function UI.toast(text: string)
	local label = textLabel({
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = COLORS.panel,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = toastHolder,
	})
	corner(8).Parent = label
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = label })
	task.delay(3, function()
		local info = TweenInfo.new(0.5)
		TweenService:Create(label, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.5)
		label:Destroy()
	end)
end

-- Panel ----------------------------------------------------------------------

local panel = create("Frame", {
	Size = UDim2.fromScale(0.5, 0.65),
	Position = UDim2.fromScale(0.5, 0.52),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = COLORS.panel,
	Visible = false,
	Parent = screen,
}, {
	corner(14),
	create("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(640, 560) }),
})

-- A visible Modal button frees the mouse while in first person.
local closeButton = create("TextButton", {
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(1, -44, 0, 8),
	BackgroundColor3 = Color3.fromRGB(200, 60, 60),
	Text = "X",
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = COLORS.text,
	Modal = true,
	Parent = panel,
}, { corner(8) })

local tabBar = create("Frame", {
	Size = UDim2.new(1, -64, 0, 36),
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
	Size = UDim2.new(1, -20, 1, -60),
	Position = UDim2.fromOffset(10, 52),
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

-- Row definitions ------------------------------------------------------------

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
	local affordable = cost ~= nil and state.data.cash >= cost
	return {
		key = key,
		title = title,
		sub = sub,
		buttonText = if cost then Formulas.formatMoney(cost) else (reason or "-"),
		enabled = affordable,
		onClick = buyCash(kind, id),
	}
end

local function menuRows(): { RowDef }
	local defs = {}
	for _, dish in Config.Dishes do
		local level = state.data.dishes[dish.id] or 0
		local nextMilestone = nil
		for _, m in Config.DishMilestones do
			if level < m then
				nextMilestone = m
				break
			end
		end
		local title = if level > 0 then `{dish.name}  Lv {level}/{Config.DishMaxLevel}` else `{dish.name} (locked)`
		local sub = if level > 0
			then `Sells for {Formulas.formatMoney(Formulas.dishPrice(dish, level))}` .. (if nextMilestone
				then ` · Lv {nextMilestone}: price x2, faster cooking`
				else "")
			else `Unlock to add it to the menu`
		table.insert(defs, cashRow("dish_" .. dish.id, title, sub, "dish", dish.id))
	end
	return defs
end

local function staffRows(): { RowDef }
	local defs = {}
	for _, roleId in Config.StaffOrder do
		local role = Config.Staff[roleId]
		local s = state.data.staff[roleId]
		table.insert(
			defs,
			cashRow(
				"hire_" .. roleId,
				`Hire {role.name} ({s.count}/{role.maxCount})`,
				if roleId == "cashier" then "Takes orders so you don't have to" else "More hands, more bowls",
				"staffHire",
				roleId
			)
		)
		table.insert(
			defs,
			cashRow(
				"speed_" .. roleId,
				`{role.name} speed  Lv {s.speed}/{role.maxSpeedLevel}`,
				`Walks {string.format("%.1f", Formulas.staffWalkSpeed(s.speed))} studs/s, works x{string.format(
					"%.2f",
					Formulas.staffWorkMultiplier(s.speed)
				)}`,
				"staffSpeed",
				roleId
			)
		)
	end
	return defs
end

local function restaurantRows(): { RowDef }
	local data = state.data
	local defs = {
		cashRow("tables", `Tables ({data.tables}/{Config.Tables.max})`, "More seats, more customers at once", "tables"),
		cashRow(
			"upsell",
			`Upsell skill  Lv {data.upsell}/{Config.Upsell.maxLevel}`,
			`{math.floor(Formulas.upsellChance(data, state.passes.MasterUpseller == true) * 100)}% chance to sell an extra`,
			"upsell"
		),
		cashRow(
			"marketing",
			`Marketing  Lv {data.marketing}/{Config.Marketing.maxLevel}`,
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
	Staff = staffRows,
	Restaurant = restaurantRows,
	Shop = shopRows,
}

local function makeRow(def: RowDef, order: number)
	local frame = create("Frame", {
		Size = UDim2.new(1, -8, 0, 62),
		BackgroundColor3 = COLORS.row,
		LayoutOrder = order,
		Parent = list,
	}, { corner(10) })
	local title = textLabel({
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(12, 6),
		Parent = frame,
	})
	local sub = textLabel({
		Size = UDim2.new(1, -150, 0, 20),
		Position = UDim2.fromOffset(12, 34),
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subtext,
		Parent = frame,
	})
	local button = create("TextButton", {
		Size = UDim2.fromOffset(124, 44),
		Position = UDim2.new(1, -132, 0.5, -22),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = COLORS.text,
		Parent = frame,
	}, { corner(8), create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
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
	local info = `{Formulas.formatMoney(state.incomePerMin)}/min · Atmosphere {state.atmosphere}`
	if state.rushSecondsLeft > 0 then
		info ..= ` · RUSH {math.ceil(state.rushSecondsLeft / 60)}m`
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
		Size = UDim2.new(0.25, -5, 1, 0),
		BackgroundColor3 = COLORS.row,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = COLORS.text,
		LayoutOrder = i,
		Parent = tabBar,
	}, { corner(8), create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }) })
	button.Activated:Connect(function()
		if currentTab ~= name then
			openTab(name)
		end
	end)
	tabButtons[name] = button
end

closeButton.Activated:Connect(function()
	panel.Visible = false
end)
upgradesButton.Activated:Connect(function()
	openTab(if currentTab == "Shop" then "Menu" else currentTab)
end)
shopButton.Activated:Connect(function()
	openTab("Shop")
end)
cameraButton.Activated:Connect(CameraToggle.toggle)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		openTab(if currentTab == "Shop" then "Menu" else currentTab)
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
