-- Conversation window with a customer, plus the ID card for age-restricted drinks.
-- Options can be clicked or picked with the number keys 1-4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local DialogChoice = Remotes.event("DialogChoice")

local DialogUI = {}

local COLORS = Theme.colors
local create = Theme.create
local corner = Theme.corner
local textLabel = Theme.textLabel

local current = nil -- the node being shown
local window: Frame
local headshot: ImageLabel
local nameLabel: TextLabel
local bodyLabel: TextLabel
local optionsFrame: Frame
local card: Frame
local cardFields: { [string]: any } = {}

local function headshotUrl(userId: number?): string
	if not userId then
		return ""
	end
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function choose(optionId: string)
	if not current then
		return
	end
	local id = current.customerId
	DialogChoice:FireServer(id, optionId)
	if optionId == "__close" then
		DialogUI.hide()
	end
end

function DialogUI.hide()
	current = nil
	window.Visible = false
	card.Visible = false
end

function DialogUI.show(node)
	if node.close then
		DialogUI.hide()
		return
	end
	current = node
	window.Visible = true
	headshot.Image = headshotUrl(node.userId)
	nameLabel.Text = node.name
	bodyLabel.Text = node.text
	for _, child in optionsFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for i, option in node.options do
		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = if option.id == "id_refuse" then COLORS.danger else COLORS.accent,
			Text = `{i}. {option.label}`,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = COLORS.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			Parent = optionsFrame,
		}, { corner(10), Theme.padding(10) })
		button.Activated:Connect(function()
			choose(option.id)
		end)
	end
	if node.card then
		card.Visible = true
		cardFields.photo.Image = headshotUrl(node.card.photoUserId)
		cardFields.name.Text = node.card.name
		cardFields.dob.Text = "Born: " .. node.card.dob
		cardFields.expires.Text = "Expires: " .. node.card.expires
		cardFields.rule.Text = `Today is {node.card.today} · {node.card.drink}: {node.card.minAge}+ only`
	else
		card.Visible = false
	end
end

function DialogUI.init(screen: ScreenGui)
	window = create("Frame", {
		Size = UDim2.new(0, 560, 0, 290),
		Position = UDim2.new(0.5, -280, 1, -306),
		BackgroundColor3 = COLORS.cream,
		Visible = false,
		Parent = screen,
	}, { corner(16), Theme.stroke() })

	headshot = create("ImageLabel", {
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(230, 215, 195),
		Parent = window,
	}, { corner(42) })
	nameLabel = textLabel({
		Size = UDim2.new(1, -170, 0, 28),
		Position = UDim2.fromOffset(110, 14),
		Font = Enum.Font.FredokaOne,
		TextColor3 = COLORS.accent,
		Parent = window,
	})
	bodyLabel = textLabel({
		Size = UDim2.new(1, -124, 0, 56),
		Position = UDim2.fromOffset(110, 44),
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.dark,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = window,
	})
	create("UITextSizeConstraint", { MaxTextSize = 22, Parent = bodyLabel })

	-- Visible Modal button: frees the mouse in first person while talking.
	local closeButton = create("TextButton", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -44, 0, 10),
		BackgroundColor3 = COLORS.danger,
		Text = "X",
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = COLORS.text,
		Modal = true,
		Parent = window,
	}, { corner(8) })
	closeButton.Activated:Connect(function()
		choose("__close")
	end)

	optionsFrame = create("Frame", {
		Size = UDim2.new(1, -28, 0, 176),
		Position = UDim2.fromOffset(14, 108),
		BackgroundTransparency = 1,
		Parent = window,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- ID card
	card = create("Frame", {
		Size = UDim2.new(0, 360, 0, 200),
		Position = UDim2.new(0.5, -180, 1, -520),
		BackgroundColor3 = Color3.fromRGB(205, 225, 245),
		Visible = false,
		Parent = screen,
	}, { corner(14), Theme.stroke() })
	create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(40, 80, 150),
		Parent = card,
	}, {
		corner(14),
		textLabel({
			Size = UDim2.new(1, -20, 1, -8),
			Position = UDim2.fromOffset(10, 4),
			Text = "NOODLE CITY · IDENTITY CARD",
			Font = Enum.Font.FredokaOne,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
	cardFields.photo = create("ImageLabel", {
		Size = UDim2.fromOffset(96, 110),
		Position = UDim2.fromOffset(14, 44),
		BackgroundColor3 = Color3.fromRGB(240, 240, 240),
		Parent = card,
	}, { corner(6) })
	local function field(y: number, size: number, bold: boolean): TextLabel
		return textLabel({
			Size = UDim2.new(1, -136, 0, size),
			Position = UDim2.fromOffset(124, y),
			Font = if bold then Enum.Font.FredokaOne else Enum.Font.GothamMedium,
			TextColor3 = COLORS.dark,
			Parent = card,
		})
	end
	cardFields.name = field(46, 30, true)
	cardFields.dob = field(84, 24, false)
	cardFields.expires = field(112, 24, false)
	cardFields.rule = textLabel({
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.fromOffset(14, 166),
		Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not current then
			return
		end
		local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
		local index = table.find(keys, input.KeyCode)
		if index and current.options[index] then
			choose(current.options[index].id)
		end
	end)
end

return DialogUI
