-- Shared colors and small UI helpers.

local Theme = {}

Theme.colors = {
	panel = Color3.fromRGB(34, 26, 32),
	row = Color3.fromRGB(58, 44, 52),
	accent = Color3.fromRGB(235, 90, 50),
	buy = Color3.fromRGB(70, 190, 90),
	disabled = Color3.fromRGB(95, 88, 92),
	robux = Color3.fromRGB(40, 160, 90),
	blue = Color3.fromRGB(70, 100, 180),
	text = Color3.fromRGB(255, 255, 255),
	subtext = Color3.fromRGB(215, 200, 205),
	money = Color3.fromRGB(130, 255, 140),
	gold = Color3.fromRGB(255, 205, 70),
	goldDark = Color3.fromRGB(190, 120, 10),
	danger = Color3.fromRGB(215, 65, 60),
	cream = Color3.fromRGB(255, 245, 225),
	dark = Color3.fromRGB(40, 30, 35),
}

function Theme.create(className: string, props, children: { Instance }?): any
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

function Theme.corner(radius: number?)
	return Theme.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke()
	return Theme.create("UIStroke", {
		Color = Color3.fromRGB(0, 0, 0),
		Transparency = 0.6,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px: number)
	return Theme.create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, math.floor(px / 2)),
		PaddingBottom = UDim.new(0, math.floor(px / 2)),
	})
end

function Theme.textLabel(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.colors.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Theme.create("TextLabel", defaults)
end

return Theme
