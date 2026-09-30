--!strict
-- Floating damage numbers for your own hits on bosses, colored by the weapon's
-- rarity. Big hits (Reaper's Mythic Blade…) get bigger numbers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)

local DamageNumbers = {}

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function DamageNumbers.Show(position: Vector3, amount: number, rarityName: string?)
	local color = if rarityName and Rarities.IsValid(rarityName) then Rarities.Get(rarityName).Color else Theme.Parchment
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position + Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	anchor.Parent = Workspace.Terrain

	local size = math.clamp(18 + math.log10(math.max(amount, 1)) * 8, 18, 46)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.TitleFont
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.Text = formatNumber(amount)
	label.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 1.5
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

function DamageNumbers.Start()
	Remotes.Get("DamageDealt").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and typeof(payload.Position) == "Vector3" and type(payload.Amount) == "number" then
			DamageNumbers.Show(payload.Position, payload.Amount, payload.Rarity)
		end
	end)
end

return DamageNumbers
