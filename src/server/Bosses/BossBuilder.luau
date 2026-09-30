--!strict
-- Builds a boss model ready to spawn.
--
--   * If ServerStorage.BossModels has a Model named after the boss id (e.g.
--     "pumpkin_lord"), that model is cloned and scaled with Model:ScaleTo().
--     It needs a Humanoid and a PrimaryPart (HumanoidRootPart). If it uses the
--     same joint names as the built-in rigs (Root, Waist, Neck, LeftShoulder…)
--     it gets the procedural animations too.
--   * Otherwise the boss's design module (Models/Designs/<id>) builds the
--     detailed procedural model.
-- Either way the model is sized by the boss's Scale, so rarer bosses are bigger.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BossRoster = require(ReplicatedStorage.Shared.Config.BossRoster)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local BossSettings = require(script.Parent.BossSettings)
local ModelKit = require(script.Parent.Models.ModelKit)

type BossDef = BossRoster.BossDef
type BossStats = BossRoster.BossStats

local BossBuilder = {}

BossBuilder.Tag = "Boss"

local Designs = script.Parent.Models.Designs
for _, def in BossRoster.List do
	assert(Designs:FindFirstChild(def.Id), `Boss "{def.Id}" has no design module in Bosses/Models/Designs`)
end

local function findCustomModel(def: BossDef): Model?
	local folder = ServerStorage:FindFirstChild(BossSettings.CustomModelFolderName)
	local template = folder and folder:FindFirstChild(def.Id)
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template.PrimaryPart then
		return template
	end
	return nil
end

local function buildProcedural(def: BossDef, stats: BossStats): Model
	local kit = ModelKit.new(def, stats.Scale)
	local design = require(Designs:FindFirstChild(def.Id) :: ModuleScript) :: (ModelKit.Kit, BossDef) -> ()
	design(kit, def)
	return kit:Finish()
end

local function buildCustom(template: Model, def: BossDef, stats: BossStats): Model
	local model = template:Clone()
	model:ScaleTo(stats.Scale)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hasRig = false
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == "Waist" then
			hasRig = true
			break
		end
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("ProceduralRig", hasRig)
	model:SetAttribute("AnimStyle", model:GetAttribute("AnimStyle") or def.AnimStyle)
	model:SetAttribute("BossScale", stats.Scale)
	model:SetAttribute("LegLength", humanoid.HipHeight / stats.Scale)
	return model
end

local function addHealthBar(model: Model, def: BossDef)
	local rarity = Rarities.Get(def.Rarity)
	local root = model.PrimaryPart :: BasePart
	local height = model:GetExtentsSize().Y

	local gui = Instance.new("BillboardGui")
	gui.Name = "BossHealthBar"
	gui.Size = UDim2.fromOffset(300, 66)
	-- Just above the top of the model, measured from the root at rest.
	gui.StudsOffsetWorldSpace = Vector3.new(0, height - root.CFrame.Position.Y + 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220 + height * 4
	gui.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "BossName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Font = Enum.Font.GrenzeGotisch
	nameLabel.TextSize = 28
	nameLabel.TextColor3 = rarity.Color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = def.Name
	nameLabel.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(0, 26)
	subtitle.Size = UDim2.new(1, 0, 0, 16)
	subtitle.Font = Enum.Font.Fondamento
	subtitle.TextSize = 14
	subtitle.TextColor3 = Color3.fromRGB(214, 204, 186)
	subtitle.TextStrokeTransparency = 0.4
	subtitle.Text = `{string.upper(def.Rarity)}  ·  {def.Title}`
	subtitle.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(10, 46)
	bar.Size = UDim2.new(1, -20, 0, 14)
	bar.BackgroundColor3 = Color3.fromRGB(18, 12, 16)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = rarity.Color
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.2
	barStroke.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(Color3.fromRGB(120, 14, 24), Color3.fromRGB(214, 40, 48))
	fillGradient.Parent = fill

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.BackgroundTransparency = 1
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.Font = Enum.Font.Merriweather
	healthText.TextSize = 11
	healthText.TextColor3 = Color3.fromRGB(240, 232, 220)
	healthText.TextStrokeTransparency = 0.3
	healthText.ZIndex = 2
	healthText.Parent = bar
end

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function BossBuilder.UpdateHealthBar(model: Model, health: number, maxHealth: number)
	local root = model.PrimaryPart
	local gui = root and root:FindFirstChild("BossHealthBar")
	local bar = gui and gui:FindFirstChild("Bar")
	if not bar then
		return
	end
	local fill = bar:FindFirstChild("Fill") :: Frame?
	local text = bar:FindFirstChild("HealthText") :: TextLabel?
	local ratio = math.clamp(health / maxHealth, 0, 1)
	if fill then
		fill.Size = UDim2.fromScale(ratio, 1)
	end
	if text then
		text.Text = `{formatNumber(health)} / {formatNumber(maxHealth)}`
	end
end

-- Returns a ready-to-parent boss model standing at the world origin (use PivotTo).
function BossBuilder.Build(def: BossDef, stats: BossStats): Model
	local template = findCustomModel(def)
	local model = if template then buildCustom(template, def, stats) else buildProcedural(def, stats)
	model.Name = def.Name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end

	model:SetAttribute("BossId", def.Id)
	model:SetAttribute("Rarity", def.Rarity)
	CollectionService:AddTag(model, BossBuilder.Tag)

	addHealthBar(model, def)
	BossBuilder.UpdateHealthBar(model, stats.MaxHealth, stats.MaxHealth)
	return model
end

return BossBuilder
