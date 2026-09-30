--!strict
-- Dark Fantasy notifications:
--   * Loot cards (top right) when the server grants you boss drops
--   * Banners (top centre) when a boss spawns or is vanquished
--   * Short notices (bottom centre), e.g. "claim a plot to fight the boss"
-- Legendary and Mythic drops add a shimmering border, an edge glow and a
-- centred splash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local CARD_WIDTH = 380
local MAX_CARDS = 4
local ROW_HEIGHT = 44
local HEADER_HEIGHT = 74
local FOOTER_HEIGHT = 40
local BANNER_DURATION = 4.5

local LootNotifications = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui
local cardStack: Frame
local bannerHolder: Frame
local noticeHolder: Frame
local currentNotice: CanvasGroup? = nil
local splashLayer: Frame
local cardCounter = 0
local bannerQueue: { any } = {}
local bannerRunning = false

-- Helpers ---------------------------------------------------------------------

local function create(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Parchment,
		Font = Theme.BodyFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return create("TextLabel", defaults)
end

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

local function escape(text: string): string
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end

local function rarityOf(name: string): Rarities.RarityInfo
	if Rarities.IsValid(name) then
		return Rarities.Get(name :: Rarities.RarityName)
	end
	return Rarities.Get("Common")
end

-- A thin gold line that fades out at both ends, with a diamond in the middle.
local function ornamentDivider(parent: Instance, y: number, color: Color3)
	local line = create("Frame", {
		Name = "Divider",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, y),
		Size = UDim2.new(1, -36, 0, 1),
		Parent = parent,
	}, {
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	create("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(7, 7),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = line,
	})
end

-- Rotates a gradient forever (until the gradient is destroyed).
local function spin(gradient: UIGradient, speed: number)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		if not gradient.Parent then
			connection:Disconnect()
			return
		end
		gradient.Rotation = (gradient.Rotation + dt * speed) % 360
	end)
end

-- Big drop flourish -------------------------------------------------------------

local function edgeGlow(color: Color3)
	local edges = {
		{ Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromScale(0, 0), Rotation = 90 },
		{ Size = UDim2.new(1, 0, 0, 160), Position = UDim2.new(0, 0, 1, -160), Rotation = -90 },
		{ Size = UDim2.new(0, 160, 1, 0), Position = UDim2.fromScale(0, 0), Rotation = 0 },
		{ Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(1, -160, 0, 0), Rotation = 180 },
	}
	for _, edge in edges do
		local frame = create("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Size = edge.Size,
			Position = edge.Position,
			Parent = splashLayer,
		}, {
			create("UIGradient", {
				Rotation = edge.Rotation,
				Transparency = NumberSequence.new(0, 1),
			}),
		})
		tween(frame, 2.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Connect(function()
			frame:Destroy()
		end)
	end
end

local function splash(rarity: Rarities.RarityInfo)
	local text = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(900, 90),
		Font = Theme.TitleFont,
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = rarity.Color,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		Text = `{string.upper(rarity.Name)} DROP`,
		Parent = splashLayer,
	})
	local scale = create("UIScale", { Scale = 1.6, Parent = text })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(text, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0.2 })
	task.delay(1.8, function()
		tween(text, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Sine)
		tween(scale, 0.8, { Scale = 0.9 }, Enum.EasingStyle.Sine)
		task.wait(0.85)
		text:Destroy()
	end)
end

-- Loot cards ------------------------------------------------------------------

type ItemPayload = {
	Id: string,
	Name: string,
	Type: string,
	Rarity: string,
	Description: string,
	Power: number,
	Exclusive: boolean,
	Image: string?,
}

type LootPayload = {
	BossName: string,
	BossTitle: string,
	BossRarity: string,
	Items: { ItemPayload },
	Damage: number,
	Share: number,
	Rank: number,
	Helpers: number,
	Saved: boolean,
}

local function itemRow(parent: Instance, item: ItemPayload, index: number)
	local rarity = rarityOf(item.Rarity)
	local row = create("Frame", {
		Name = "Item" .. index,
		BackgroundColor3 = rarity.Color,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 14, 0, HEADER_HEIGHT + (index - 1) * ROW_HEIGHT),
		Size = UDim2.new(1, -28, 0, ROW_HEIGHT - 6),
		Parent = parent,
	}, { corner(4) })

	if item.Image and item.Image ~= "" then
		create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = item.Image,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = row,
		})
	else
		-- Faceted gem in the item's rarity color.
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 20, 0.5, 0),
			Size = UDim2.fromOffset(13, 13),
			Rotation = 45,
			BackgroundColor3 = rarity.Color,
			BorderSizePixel = 0,
			Parent = row,
		}, {
			create("UIStroke", { Color = rarity.AccentColor, Thickness = 1.5 }),
			create("UIGradient", {
				Rotation = 45,
				Color = ColorSequence.new(Color3.new(1, 1, 1), rarity.Color),
				Transparency = NumberSequence.new(0.3, 0),
			}),
		})
	end

	label({
		Position = UDim2.new(0, 40, 0, 3),
		Size = UDim2.new(1, -48, 0, 18),
		Font = Theme.HeadingFont,
		TextSize = 17,
		TextColor3 = rarity.Color,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = escape(item.Name),
		Parent = row,
	})

	local details = `{string.upper(rarity.Name)} {string.upper(item.Type)}  ·  Power {item.Power}`
	if item.Exclusive then
		details ..= `  ·  <font color="{hex(Theme.Gold)}">EXCLUSIVE</font>`
	end
	label({
		Position = UDim2.new(0, 40, 0, 20),
		Size = UDim2.new(1, -48, 0, 14),
		TextSize = 11,
		TextColor3 = Theme.Muted,
		Text = details,
		Parent = row,
	})
end

local function trimStack()
	local slots = {}
	for _, child in cardStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(slots, child)
		end
	end
	-- Newest cards have the lowest LayoutOrder.
	table.sort(slots, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = MAX_CARDS + 1, #slots do
		slots[index]:Destroy()
	end
end

function LootNotifications.ShowLoot(payload: LootPayload)
	local items = payload.Items
	if #items == 0 then
		return
	end

	local bossRarity = rarityOf(payload.BossRarity)
	local best = rarityOf(items[1].Rarity)
	for _, item in items do
		local rarity = rarityOf(item.Rarity)
		if rarity.Rank > best.Rank then
			best = rarity
		end
	end
	local isBigDrop = best.Rank >= Rarities.Rank("Legendary")
	local height = HEADER_HEIGHT + #items * ROW_HEIGHT + FOOTER_HEIGHT
	local lifetime = 7 + #items + (if isBigDrop then 3 else 0)

	cardCounter += 1
	local slot = create("Frame", {
		Name = "LootCard",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = -cardCounter,
		Parent = cardStack,
	})

	-- The CanvasGroup fades and slides the whole card as one. Its background
	-- lives on an inner frame, because a gradient on the group itself would
	-- tint everything inside it.
	local card = create("CanvasGroup", {
		Name = "Card",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(CARD_WIDTH + 40, 0),
		GroupTransparency = 1,
		Parent = slot,
	})
	local background = create("Frame", {
		Name = "Background",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		-- Inset so the border isn't clipped by the CanvasGroup.
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 0,
		Parent = card,
	}, {
		corner(8),
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.BackgroundLight, Theme.Background),
		}),
	})

	-- Border in the best item's rarity; shimmers for Legendary and Mythic.
	local stroke = create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = if isBigDrop then 2 else 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = background,
	})
	local strokeGradient = create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, best.AccentColor),
			ColorSequenceKeypoint.new(0.5, best.Color),
			ColorSequenceKeypoint.new(1, best.AccentColor),
		}),
		Parent = stroke,
	})
	if isBigDrop then
		spin(strokeGradient, 120)
	end

	-- Rarity strip down the left edge.
	create("Frame", {
		BackgroundColor3 = best.Color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		Parent = card,
	}, {
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	label({
		Position = UDim2.fromOffset(18, 8),
		Size = UDim2.new(1, -36, 0, 30),
		Font = Theme.TitleFont,
		TextSize = 28,
		TextColor3 = Theme.Gold,
		Text = "Spoils of Victory",
		Parent = card,
	})
	label({
		Position = UDim2.new(1, -36, 0, 12),
		Size = UDim2.fromOffset(20, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 16,
		TextColor3 = best.Color,
		Text = "◆",
		Parent = card,
	})
	label({
		Position = UDim2.fromOffset(18, 38),
		Size = UDim2.new(1, -36, 0, 20),
		Font = Theme.HeadingFont,
		TextSize = 16,
		TextColor3 = Theme.Parchment,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = `<font color="{hex(bossRarity.Color)}">{escape(payload.BossName)}</font> has fallen`,
		Parent = card,
	})
	ornamentDivider(card, HEADER_HEIGHT - 10, Theme.Gold)

	for index, item in items do
		itemRow(card, item, index)
	end

	local footerY = HEADER_HEIGHT + #items * ROW_HEIGHT
	local footerText = string.format(
		"Your share: <b>%d%%</b> damage  ·  Rank <b>#%d</b> of %d",
		math.floor(payload.Share * 100 + 0.5),
		payload.Rank,
		payload.Helpers
	)
	if not payload.Saved then
		footerText = `<font color="{hex(Theme.Blood)}">Could not save these items. Please rejoin.</font>`
	end
	label({
		Position = UDim2.fromOffset(18, footerY),
		Size = UDim2.new(1, -36, 0, 22),
		TextSize = 12,
		TextColor3 = Theme.Muted,
		Text = footerText,
		Parent = card,
	})

	-- Time-left bar along the bottom edge.
	local timer = create("Frame", {
		BackgroundColor3 = best.Color,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 1, -5),
		Size = UDim2.new(1, -20, 0, 2),
		Parent = card,
	}, { corner(1) })

	-- One light sweep across the card for big drops.
	if isBigDrop then
		local sheen = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = card,
		})
		local sheenGradient = create("UIGradient", {
			Rotation = 20,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = sheen,
		})
		task.delay(0.35, function()
			tween(sheenGradient, 1.1, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end)
		edgeGlow(best.Color)
		splash(best)
	end

	trimStack()

	tween(card, 0.55, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
	tween(timer, lifetime, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

	task.delay(lifetime, function()
		if not slot.Parent then
			return
		end
		tween(card, 0.45, { Position = UDim2.fromOffset(CARD_WIDTH + 40, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.45)
		tween(slot, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
		task.wait(0.25)
		slot:Destroy()
	end)
end

-- Boss banners ----------------------------------------------------------------

type AnnouncementPayload = {
	Kind: "Spawned" | "Defeated",
	BossName: string,
	BossTitle: string,
	BossRarity: string,
	TopDamagers: { string }?,
	Helpers: number?,
}

local function showBanner(payload: AnnouncementPayload)
	local rarity = rarityOf(payload.BossRarity)
	local banner = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -20),
		Size = UDim2.fromOffset(560, 96),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = bannerHolder,
	})
	-- Dark band that fades out towards both ends.
	create("Frame", {
		Name = "Background",
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = banner,
	}, {
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0),
				NumberSequenceKeypoint.new(0.82, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local headline: string
	local footer: string
	if payload.Kind == "Spawned" then
		local article = if string.match(rarity.Name, "^[AEIOU]") then "An" else "A"
		headline = `{string.upper(article)} {string.upper(rarity.Name)} FOE AWAKENS`
		footer = escape(payload.BossTitle)
	else
		headline = "VANQUISHED"
		local names: { string } = payload.TopDamagers or {}
		local escaped = {}
		for _, name in names do
			table.insert(escaped, escape(name))
		end
		local extra = (payload.Helpers or #names) - #names
		footer = "Slain by " .. table.concat(escaped, ", ") .. (if extra > 0 then ` and {extra} more` else "")
	end

	label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Theme.HeadingFont,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = rarity.Color,
		Text = `◆  {headline}  ◆`,
		Parent = banner,
	})
	label({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.TitleFont,
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Parchment,
		TextStrokeTransparency = 0.5,
		Text = escape(payload.BossName),
		Parent = banner,
	})
	label({
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.HeadingFont,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = footer,
		Parent = banner,
	})
	ornamentDivider(banner, 88, rarity.Color)

	tween(banner, 0.6, { Position = UDim2.new(0.5, 0, 0, 0), GroupTransparency = 0 })
	task.wait(BANNER_DURATION)
	tween(banner, 0.5, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	task.wait(0.5)
	banner:Destroy()
end

function LootNotifications.ShowAnnouncement(payload: AnnouncementPayload)
	table.insert(bannerQueue, payload)
	if bannerRunning then
		return
	end
	bannerRunning = true
	task.spawn(function()
		while #bannerQueue > 0 do
			local nextPayload = table.remove(bannerQueue, 1)
			local ok, err = pcall(showBanner :: any, nextPayload)
			if not ok then
				warn(`[LootNotifications] Banner failed: {err}`)
			end
		end
		bannerRunning = false
	end)
end

-- Notices ---------------------------------------------------------------------

function LootNotifications.ShowNotice(text: string)
	if currentNotice then
		currentNotice:Destroy()
	end
	local toast = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 20),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = noticeHolder,
	})
	currentNotice = toast
	create("Frame", {
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 0,
		Parent = toast,
	}, {
		corner(6),
		create("UIStroke", { Color = Theme.Gold, Thickness = 1.2, Transparency = 0.2 }),
	})
	label({
		Size = UDim2.fromScale(1, 1),
		Font = Theme.HeadingFont,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Parchment,
		Text = `<font color="{hex(Theme.Gold)}">◆</font>  {escape(text)}`,
		Parent = toast,
	})
	tween(toast, 0.35, { Position = UDim2.new(0.5, 0, 1, 0), GroupTransparency = 0 })
	task.delay(3.2, function()
		if toast.Parent then
			tween(toast, 0.4, { GroupTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Wait()
			toast:Destroy()
		end
	end)
end

-- Setup -----------------------------------------------------------------------

local function buildGui()
	screenGui = create("ScreenGui", {
		Name = "DarkFantasyNotifications",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	splashLayer = create("Frame", {
		Name = "Splash",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})

	bannerHolder = create("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(560, 110),
		Parent = screenGui,
	})

	noticeHolder = create("Frame", {
		Name = "Notices",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(440, 60),
		ClipsDescendants = false,
		Parent = screenGui,
	})

	cardStack = create("Frame", {
		Name = "LootCards",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -20, 0, 72),
		Size = UDim2.new(0, CARD_WIDTH, 1, -92),
		Parent = screenGui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	-- Shrink everything on small (phone) screens.
	local uiScale = create("UIScale", { Parent = cardStack })
	local bannerScale = create("UIScale", { Parent = bannerHolder })
	local function updateScale()
		local camera = Workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 1280
		local scale = math.clamp(width / 1100, 0.6, 1)
		uiScale.Scale = scale
		bannerScale.Scale = scale
	end
	updateScale()
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
end

function LootNotifications.Start()
	buildGui()
	Remotes.Get("LootDropped").OnClientEvent:Connect(function(payload)
		LootNotifications.ShowLoot(payload)
	end)
	Remotes.Get("BossAnnouncement").OnClientEvent:Connect(function(payload)
		LootNotifications.ShowAnnouncement(payload)
	end)
	Remotes.Get("Notice").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Text) == "string" then
			LootNotifications.ShowNotice(payload.Text)
		end
	end)
end

return LootNotifications
