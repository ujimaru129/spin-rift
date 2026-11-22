--!strict
-- Screen UI: menu (modes, ability picker, rank, leaderboard, feedback, language), waiting screens,
-- the match HUD (scoreboard, gauge, ability slots, timing popups, tutorial line) and results.
-- Every word comes from Strings, so the whole UI can switch between Japanese and English.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared:WaitForChild("Palette"))
local Abilities = require(Shared:WaitForChild("Rally"):WaitForChild("Abilities"))
local Rating = require(Shared:WaitForChild("Rank"):WaitForChild("Rating"))
local S = require(Shared:WaitForChild("Strings"))
local SeasonFolder = Shared:WaitForChild("Season")
local BattlePass = require(SeasonFolder:WaitForChild("BattlePass"))
local Cosmetics = require(SeasonFolder:WaitForChild("Cosmetics"))

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local FONT_REGULAR = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local PANEL = Color3.fromRGB(8, 11, 22)
local FIELD = Color3.fromRGB(16, 22, 40)
local INK = Color3.fromRGB(238, 243, 255)
local INK_DIM = Color3.fromRGB(154, 166, 196)
local GAUGE_MAX = 10
local FEEDBACK_CATEGORIES = { "fun", "bug", "balance", "other" }

export type Callbacks = {
	onMode: (mode: string) -> (),
	onLeave: () -> (),
	onRetry: () -> (),
	onSwingButton: () -> (),
	onAbility: (slot: number) -> (),
	onLeaderboard: (scope: string) -> (),
	onLanguage: () -> (),
	onFeedback: (category: string, text: string) -> (),
	onArena: () -> (),
	onBuyPremium: () -> (),
	onEquip: (kind: string, id: string) -> (),
}

export type Slot = { frame: TextButton, name: TextLabel, cost: TextLabel, key: TextLabel, stroke: UIStroke }
type Bound = { inst: any, key: string, prop: string }

local function abilityColor(id: string): Color3
	local def = Abilities.get(id)
	return if def then Color3.fromRGB(def.rgb[1], def.rgb[2], def.rgb[3]) else INK
end

local Hud = {}
Hud.__index = Hud
Hud.abilityColor = abilityColor

export type Hud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		bound: { Bound },
		menu: ScrollingFrame,
		profile: TextLabel,
		menuNote: TextLabel,
		pickChips: { [string]: TextButton },
		pickInfo: TextLabel,
		pickFocus: string?,
		loadout: { string },
		lastProfile: { [string]: any }?,
		leaderboard: Frame,
		boardTitle: TextLabel,
		boardRows: { TextLabel },
		boardTabs: { TextButton },
		boardRegion: string,
		lastBoard: { scope: string, rows: { { [string]: any } } }?,
		feedback: Frame,
		fbCategory: string,
		fbCats: { [string]: TextButton },
		fbBox: TextBox,
		fbStatus: TextLabel,
		waiting: Frame,
		waitTitle: TextLabel,
		waitSub: TextLabel,
		waitBot: TextButton,
		waitCancel: TextButton,
		match: Frame,
		scoreboard: Frame,
		myPoints: TextLabel,
		theirPoints: TextLabel,
		theirName: TextLabel,
		myGames: TextLabel,
		theirGames: TextLabel,
		myServe: Frame,
		theirServe: Frame,
		rally: TextLabel,
		ping: TextLabel,
		gaugeCells: { Frame },
		popup: TextLabel,
		popupSub: TextLabel,
		hint: TextLabel,
		controls: TextLabel,
		aim: TextLabel,
		tutorial: TextLabel,
		announce: TextLabel,
		slots: { Slot },
		slotIds: { string },
		touchButton: TextButton?,
		result: Frame,
		resultTitle: TextLabel,
		resultScore: TextLabel,
		resultNote: TextLabel,
		rankLine: TextLabel,
		arenaButton: TextButton,
		wind: TextLabel,
		myName: TextLabel,
		pass: Frame,
		passLevel: TextLabel,
		passXp: TextLabel,
		passBuy: TextButton,
		passRows: ScrollingFrame,
		customize: Frame,
		cosGrids: { [string]: Frame },
		passState: { [string]: any }?,
		titles: { string },
	},
	Hud
))

-- Elements in a vertical list are ordered by creation.
local nextOrder = 0
local function ordered<T>(x: T): T
	nextOrder += 1
	(x :: any).LayoutOrder = nextOrder
	return x
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font or FONT
	l.TextColor3 = color or INK
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.TextWrapped = true
	l.Parent = parent
	return ordered(l)
end

local function panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.2
	f.BorderSizePixel = 0
	f.Parent = parent
	corner(f, 8)
	stroke(f, Palette.TeamA, 0.6)
	return f
end

local function button(parent: Instance, text: string, accent: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = FIELD
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = 18
	b.FontFace = FONT
	b.TextColor3 = INK
	b.Size = UDim2.new(1, 0, 0, 46)
	b.Parent = parent
	corner(b, 6)
	stroke(b, accent, 0.25)
	b.Activated:Connect(onClick)
	return ordered(b)
end

-- Size a ScrollingFrame's canvas from its list's real content height. AutomaticCanvasSize
-- comes out short in Studio (it misses the padding and the last rows), so on a short screen
-- the bottom of the menu could not be scrolled into view.
local function fitCanvas(frame: ScrollingFrame, layout: UIListLayout, extra: number)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	local function fit()
		local content = layout.AbsoluteContentSize
		if content then
			frame.CanvasSize = UDim2.fromOffset(0, content.Y + extra)
		end
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	fit()
end

local function vlist(parent: Instance, padding: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding)
	l.Parent = parent
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, 18)
	p.PaddingBottom = UDim.new(0, 18)
	p.PaddingLeft = UDim.new(0, 18)
	p.PaddingRight = UDim.new(0, 18)
	p.Parent = parent
	return l
end

local function row(parent: Instance, height: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	return ordered(f)
end

local function grid(parent: Instance, rows: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, rows * 36 + (rows - 1) * 6)
	f.Parent = parent
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -3, 0, 36)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return ordered(f)
end

local function centered(f: GuiObject, width: number)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.new(0, width, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
end

function Hud.new(playerGui: PlayerGui, callbacks: Callbacks): Hud
	local bound: { Bound } = {}
	-- fixed text, redrawn when the language changes
	local function bind<T>(inst: T, key: string, prop: string?): T
		local p = prop or "Text"
		(inst :: any)[p] = S.t(key)
		table.insert(bound, { inst = inst, key = key, prop = p })
		return inst
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SuperBattlePingPongHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- menu: scrolls when the screen is short
	local menu = Instance.new("ScrollingFrame")
	menu.Name = "Menu"
	menu.BackgroundColor3 = PANEL
	menu.BackgroundTransparency = 0.2
	menu.BorderSizePixel = 0
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.fromScale(0.94, 0.92)
	menu.CanvasSize = UDim2.new()
	menu.ScrollBarThickness = 4
	menu.Parent = gui
	corner(menu, 8)
	stroke(menu, Palette.TeamA, 0.6)
	local menuMax = Instance.new("UISizeConstraint")
	menuMax.MaxSize = Vector2.new(400, 860)
	menuMax.Parent = menu
	fitCanvas(menu, vlist(menu, 10), 36) -- 36 = UIPadding top + bottom

	local title = label(menu, "SUPER BATTLE\nPING-PONG!!", 30, Palette.TeamA)
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	title.Size = UDim2.new(1, 0, 0, 68)
	title.TextScaled = true
	bind(label(menu, "", 12, INK_DIM, FONT_REGULAR), "menu.subtitle")
	local profile = bind(label(menu, "", 14, INK, FONT_REGULAR), "menu.loadingRank")
	profile.Size = UDim2.new(1, 0, 0, 36)
	local menuNote = label(menu, "", 13, Palette.Grade.Miss, FONT_REGULAR)
	menuNote.Size = UDim2.new(1, 0, 0, 36)
	menuNote.Visible = false

	bind(
		button(menu, "", Palette.Grade.Good, function()
			callbacks.onMode("Tutorial")
		end),
		"menu.tutorial"
	)
	bind(
		button(menu, "", Palette.Grade.Perfect, function()
			callbacks.onMode("Ranked")
		end),
		"menu.ranked"
	)
	bind(
		button(menu, "", Palette.TeamB, function()
			callbacks.onMode("Online")
		end),
		"menu.casual"
	)
	local arenaButton = button(menu, "", Palette.Grade.Good, callbacks.onArena)
	arenaButton.TextSize = 15
	arenaButton.Size = UDim2.new(1, 0, 0, 40)
	bind(label(menu, "", 13, INK_DIM, FONT), "menu.practice").TextXAlignment = Enum.TextXAlignment.Left
	local practice = grid(menu, 2)
	for _, m in
		{
			{ "Wall", "menu.wall" },
			{ "Easy", "menu.botEasy" },
			{ "Normal", "menu.botNormal" },
			{ "Hard", "menu.botHard" },
		}
	do
		local b = bind(
			button(practice, "", Palette.TeamA, function()
				callbacks.onMode(m[1])
			end),
			m[2]
		)
		b.TextSize = 15
	end

	bind(label(menu, "", 14, INK, FONT), "menu.pick").TextXAlignment = Enum.TextXAlignment.Left
	local picks = grid(menu, 4)
	local pickInfo = label(menu, "", 12, INK_DIM, FONT_REGULAR)
	pickInfo.Size = UDim2.new(1, 0, 0, 34)
	pickInfo.TextXAlignment = Enum.TextXAlignment.Left
	local pickChips: { [string]: TextButton } = {}

	local help = bind(label(menu, "", 13, INK_DIM, FONT_REGULAR), "menu.help")
	help.Size = UDim2.new(1, 0, 0, 104)
	help.TextXAlignment = Enum.TextXAlignment.Left

	local extras = row(menu, 36)
	local seasonRow = row(menu, 36)

	-- leaderboard
	local leaderboard = panel(gui, "Leaderboard")
	centered(leaderboard, 340)
	leaderboard.Visible = false
	vlist(leaderboard, 6)
	local boardTitle = bind(label(leaderboard, "", 20, Palette.Grade.Perfect), "board.title")
	local tabs = row(leaderboard, 32)
	local boardTabs: { TextButton } = {}
	for i, key in { "board.world", "board.region" } do
		local t = bind(button(tabs, "", Palette.TeamA, function() end), key)
		t.Size = UDim2.new(0.5, -3, 1, 0)
		t.TextSize = 14
		boardTabs[i] = t
	end
	local boardRows: { TextLabel } = {}
	for i = 1, 10 do
		local r = label(leaderboard, "", 14, INK, FONT_REGULAR)
		r.TextXAlignment = Enum.TextXAlignment.Left
		boardRows[i] = r
	end
	local closeBoard = bind(
		button(leaderboard, "", Palette.TeamB, function()
			leaderboard.Visible = false
		end),
		"common.close"
	)
	closeBoard.Size = UDim2.new(1, 0, 0, 36)

	-- feedback form
	local feedback = panel(gui, "Feedback")
	centered(feedback, 340)
	feedback.Visible = false
	vlist(feedback, 8)
	bind(label(feedback, "", 20, INK), "fb.title")
	local cats = row(feedback, 30)
	local fbCats: { [string]: TextButton } = {}
	local fbBox = Instance.new("TextBox")
	fbBox.ClearTextOnFocus = false
	fbBox.MultiLine = true
	fbBox.TextWrapped = true
	fbBox.Text = ""
	fbBox.TextSize = 14
	fbBox.FontFace = FONT_REGULAR
	fbBox.TextColor3 = INK
	fbBox.PlaceholderColor3 = INK_DIM
	fbBox.BackgroundColor3 = FIELD
	fbBox.TextXAlignment = Enum.TextXAlignment.Left
	fbBox.TextYAlignment = Enum.TextYAlignment.Top
	fbBox.Size = UDim2.new(1, 0, 0, 96)
	fbBox.Parent = feedback
	ordered(fbBox)
	corner(fbBox, 6)
	bind(fbBox, "fb.placeholder", "PlaceholderText")
	local fbStatus = label(feedback, "", 13, INK_DIM, FONT_REGULAR)
	local fbSend = bind(button(feedback, "", Palette.Grade.Good, function() end), "fb.send")
	local fbClose = bind(
		button(feedback, "", Palette.TeamB, function()
			feedback.Visible = false
		end),
		"common.close"
	)
	fbClose.Size = UDim2.new(1, 0, 0, 36)

	-- battle pass
	local pass = panel(gui, "BattlePass")
	centered(pass, 360)
	pass.Visible = false
	vlist(pass, 6)
	bind(label(pass, "", 20, Palette.Grade.Perfect), "pass.title")
	local passLevel = label(pass, "", 16, INK)
	local passXp = label(pass, "", 13, INK_DIM, FONT_REGULAR)
	bind(label(pass, "", 12, INK_DIM, FONT_REGULAR), "pass.howXp").Size = UDim2.new(1, 0, 0, 32)
	local passBuy = button(pass, "", Palette.Grade.Perfect, callbacks.onBuyPremium)
	passBuy.TextSize = 15
	local passRows = Instance.new("ScrollingFrame")
	passRows.BackgroundTransparency = 1
	passRows.BorderSizePixel = 0
	passRows.Size = UDim2.new(1, 0, 0, 220)
	passRows.CanvasSize = UDim2.new()
	passRows.ScrollBarThickness = 4
	passRows.Parent = pass
	ordered(passRows)
	local prl = Instance.new("UIListLayout")
	prl.SortOrder = Enum.SortOrder.LayoutOrder
	prl.Padding = UDim.new(0, 2)
	prl.Parent = passRows
	fitCanvas(passRows, prl, 0)
	bind(
		button(pass, "", Palette.TeamB, function()
			pass.Visible = false
		end),
		"common.close"
	).Size =
		UDim2.new(1, 0, 0, 36)

	-- customize
	local customize = panel(gui, "Customize")
	centered(customize, 360)
	customize.Visible = false
	vlist(customize, 6)
	bind(label(customize, "", 20, Palette.TeamA), "cos.title")
	-- the item lists scroll, so the panel (and its Close button) fits on a short screen
	local cosList = Instance.new("ScrollingFrame")
	cosList.BackgroundTransparency = 1
	cosList.BorderSizePixel = 0
	cosList.Size = UDim2.new(1, 0, 0, 260)
	cosList.CanvasSize = UDim2.new()
	cosList.ScrollBarThickness = 4
	cosList.Parent = customize
	ordered(cosList)
	local cll = Instance.new("UIListLayout")
	cll.SortOrder = Enum.SortOrder.LayoutOrder
	cll.Padding = UDim.new(0, 6)
	cll.Parent = cosList
	fitCanvas(cosList, cll, 0)
	local cosGrids: { [string]: Frame } = {}
	for _, kind in Cosmetics.KINDS do
		local key = if kind == "paddle" then "cos.paddle" elseif kind == "trail" then "cos.trail" else "cos.titleSlot"
		bind(label(cosList, "", 14, INK, FONT), key).TextXAlignment = Enum.TextXAlignment.Left
		local count = #Cosmetics.ofKind(kind) + (if kind == "paddle" then 0 else 1)
		cosGrids[kind] = grid(cosList, math.ceil(count / 2))
	end
	bind(
		button(customize, "", Palette.TeamB, function()
			customize.Visible = false
		end),
		"common.close"
	).Size =
		UDim2.new(1, 0, 0, 36)

	-- waiting for an opponent
	local waiting = panel(gui, "Waiting")
	centered(waiting, 340)
	waiting.Visible = false
	vlist(waiting, 10)
	local waitTitle = label(waiting, "", 22, INK)
	local waitSub = label(waiting, "", 13, INK_DIM, FONT_REGULAR)
	waitSub.Size = UDim2.new(1, 0, 0, 36)
	local waitBot = bind(
		button(waiting, "", Palette.Grade.Good, function()
			callbacks.onMode("Normal")
		end),
		"wait.bot"
	)
	waitBot.TextSize = 15
	waitBot.Visible = false
	local waitCancel = bind(button(waiting, "", Palette.TeamB, callbacks.onLeave), "common.cancel")

	-- match HUD
	local match = Instance.new("Frame")
	match.Name = "Match"
	match.BackgroundTransparency = 1
	match.Size = UDim2.fromScale(1, 1)
	match.Visible = false
	match.Parent = gui

	local scoreboard = panel(match, "Scoreboard")
	scoreboard.AnchorPoint = Vector2.new(0.5, 0)
	scoreboard.Position = UDim2.new(0.5, 0, 0, 14)
	scoreboard.Size = UDim2.new(0, 360, 0, 66)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = scoreboard

	local function side(xScale: number, color: Color3, align: Enum.TextXAlignment)
		local n = label(scoreboard, "", 14, color)
		n.Position = UDim2.new(xScale, 0, 0, 8)
		n.Size = UDim2.new(0.5, -60, 0, 18)
		n.TextXAlignment = align
		local games = label(scoreboard, "", 13, INK_DIM, FONT_REGULAR)
		games.Position = UDim2.new(xScale, 0, 0, 38)
		games.Size = UDim2.new(0.5, -60, 0, 18)
		games.TextXAlignment = align
		local serve = Instance.new("Frame")
		serve.Size = UDim2.fromOffset(8, 8)
		serve.BackgroundColor3 = Palette.Grade.Perfect
		serve.BorderSizePixel = 0
		serve.Position = if align == Enum.TextXAlignment.Left
			then UDim2.new(xScale, 0, 0, 30)
			else UDim2.new(xScale, 0, 0, 30) + UDim2.new(0.5, -68, 0, 0)
		serve.Parent = scoreboard
		corner(serve, 4)
		return n, games, serve
	end
	local myName, myGames, myServe = side(0, Palette.TeamA, Enum.TextXAlignment.Left)
	local theirName, theirGames, theirServe = side(0.5, Palette.TeamB, Enum.TextXAlignment.Right)
	theirName.Position += UDim2.fromOffset(60, 0)
	theirGames.Position += UDim2.fromOffset(60, 0)

	local score = label(scoreboard, "", 34, INK)
	score.AnchorPoint = Vector2.new(0.5, 0.5)
	score.Position = UDim2.fromScale(0.5, 0.5)
	score.Size = UDim2.fromOffset(120, 40)
	local myPoints = label(score, "0", 34, INK)
	myPoints.Size = UDim2.new(0.5, -8, 1, 0)
	myPoints.TextXAlignment = Enum.TextXAlignment.Right
	local dash = label(score, "-", 28, INK_DIM)
	dash.AnchorPoint = Vector2.new(0.5, 0)
	dash.Position = UDim2.fromScale(0.5, 0)
	dash.Size = UDim2.new(0, 16, 1, 0)
	local theirPoints = label(score, "0", 34, INK)
	theirPoints.AnchorPoint = Vector2.new(1, 0)
	theirPoints.Position = UDim2.fromScale(1, 0)
	theirPoints.Size = UDim2.new(0.5, -8, 1, 0)
	theirPoints.TextXAlignment = Enum.TextXAlignment.Left

	local rally = label(match, "", 16, INK_DIM)
	rally.AnchorPoint = Vector2.new(0.5, 0)
	rally.Position = UDim2.new(0.5, 0, 0, 88)
	rally.Size = UDim2.fromOffset(240, 22)

	local wind = label(match, "", 16, Color3.fromRGB(255, 200, 225))
	wind.AnchorPoint = Vector2.new(0, 0)
	wind.Position = UDim2.new(0, 14, 0, 14)
	wind.Size = UDim2.fromOffset(200, 22)
	wind.TextXAlignment = Enum.TextXAlignment.Left
	wind.Visible = false

	local tutorial = label(match, "", 18, Palette.Grade.Good)
	tutorial.AnchorPoint = Vector2.new(0.5, 0)
	tutorial.Position = UDim2.new(0.5, 0, 0, 112)
	tutorial.Size = UDim2.new(0.8, 0, 0, 48)
	tutorial.BackgroundColor3 = PANEL
	tutorial.BackgroundTransparency = 0.25
	tutorial.Visible = false
	corner(tutorial, 8)

	local leave = Instance.new("TextButton")
	leave.TextSize = 14
	leave.FontFace = FONT
	leave.TextColor3 = INK
	leave.BackgroundColor3 = PANEL
	leave.BackgroundTransparency = 0.2
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -14, 0, 14)
	leave.Size = UDim2.fromOffset(96, 36)
	leave.Parent = match
	corner(leave, 6)
	stroke(leave, Palette.TeamA, 0.6)
	bind(leave, "hud.menu")
	leave.Activated:Connect(callbacks.onLeave)

	local ping = label(match, "", 12, INK_DIM, FONT_REGULAR)
	ping.AnchorPoint = Vector2.new(1, 0)
	ping.Position = UDim2.new(1, -14, 0, 56)
	ping.Size = UDim2.fromOffset(140, 16)
	ping.TextXAlignment = Enum.TextXAlignment.Right

	local gauge = panel(match, "Gauge")
	gauge.AnchorPoint = Vector2.new(0, 1)
	gauge.Position = UDim2.new(0, 14, 1, -14)
	gauge.Size = UDim2.fromOffset(250, 54)
	local gaugeLabel = bind(label(gauge, "", 12, INK_DIM, FONT_REGULAR), "hud.gauge")
	gaugeLabel.Position = UDim2.fromOffset(12, 6)
	gaugeLabel.Size = UDim2.new(1, -24, 0, 16)
	gaugeLabel.TextXAlignment = Enum.TextXAlignment.Left
	local cells: { Frame } = {}
	for i = 1, GAUGE_MAX do
		local c = Instance.new("Frame")
		c.BorderSizePixel = 0
		c.BackgroundColor3 = Color3.fromRGB(30, 38, 60)
		c.Position = UDim2.fromOffset(12 + (i - 1) * 23, 28)
		c.Size = UDim2.fromOffset(19, 14)
		c.Parent = gauge
		corner(c, 3)
		cells[i] = c
	end

	-- how to play, always on screen during a match (text depends on the device; see setControls)
	local controls = label(match, "", 13, INK, FONT_REGULAR)
	controls.Name = "Controls"
	-- bottom left on computers; top left on phones, where the bottom left is the move stick
	controls.AnchorPoint = Vector2.new(0, if UserInputService.TouchEnabled then 0 else 1)
	controls.Position = if UserInputService.TouchEnabled then UDim2.new(0, 14, 0, 44) else UDim2.new(0, 14, 1, -76)
	controls.Size = UDim2.fromOffset(270, 102)
	controls.TextXAlignment = Enum.TextXAlignment.Left
	controls.TextYAlignment = Enum.TextYAlignment.Top
	controls.TextWrapped = true
	controls.BackgroundColor3 = PANEL
	controls.BackgroundTransparency = 0.35
	corner(controls, 8)
	local controlsPad = Instance.new("UIPadding")
	controlsPad.PaddingLeft = UDim.new(0, 10)
	controlsPad.PaddingTop = UDim.new(0, 6)
	controlsPad.Parent = controls

	local popup = label(match, "", 64, INK)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.36)
	popup.Size = UDim2.fromOffset(600, 80)
	popup.TextTransparency = 1
	local popupStroke = Instance.new("UIStroke")
	popupStroke.Thickness = 3
	popupStroke.Color = Color3.new(0, 0, 0)
	popupStroke.Transparency = 0.4
	popupStroke.Parent = popup
	local popupSub = label(match, "", 18, INK, FONT_REGULAR)
	popupSub.AnchorPoint = Vector2.new(0.5, 0)
	popupSub.Position = UDim2.fromScale(0.5, 0.42)
	popupSub.Size = UDim2.fromOffset(400, 24)
	popupSub.TextTransparency = 1

	local hint = label(match, "", 18, INK)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -24)
	hint.Size = UDim2.fromOffset(560, 26)

	-- result
	local result = panel(gui, "Result")
	centered(result, 320)
	result.Visible = false
	vlist(result, 10)
	local resultTitle = label(result, "", 40, Palette.Grade.Perfect)
	local resultScore = label(result, "", 18, INK_DIM, FONT_REGULAR)
	local resultNote = label(result, "", 14, INK_DIM, FONT_REGULAR)
	local rankLine = label(result, "", 18, INK)
	rankLine.Size = UDim2.new(1, 0, 0, 48)
	rankLine.Visible = false
	bind(button(result, "", Palette.TeamA, callbacks.onRetry), "result.again")
	bind(button(result, "", Palette.TeamB, callbacks.onLeave), "result.menu")

	-- touch swing button
	local touchButton: TextButton? = nil
	if UserInputService.TouchEnabled then
		local t = Instance.new("TextButton")
		t.Name = "SwingButton"
		t.TextSize = 26
		t.FontFace = FONT
		t.TextColor3 = INK
		t.BackgroundColor3 = Palette.TeamA
		t.BackgroundTransparency = 0.35
		t.AnchorPoint = Vector2.new(1, 1)
		t.Position = UDim2.new(1, -36, 1, -150)
		t.Size = UDim2.fromOffset(112, 112)
		t.Parent = match
		corner(t, 56)
		stroke(t, INK, 0.3)
		bind(t, "hud.hit")
		t.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				callbacks.onSwingButton()
			end
		end)
		touchButton = t
	end

	-- ability slots and the announcement line
	local slotBar = Instance.new("Frame")
	slotBar.Name = "AbilitySlots"
	slotBar.BackgroundTransparency = 1
	slotBar.AnchorPoint = Vector2.new(0.5, 1)
	slotBar.Position = UDim2.new(0.5, 0, 1, -58)
	slotBar.Size = UDim2.fromOffset(2 * 170 + 10, 56)
	slotBar.Parent = match
	local slots: { Slot } = {}
	for i = 1, Abilities.SLOTS do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = true
		b.BackgroundColor3 = PANEL
		b.BackgroundTransparency = 0.15
		b.Position = UDim2.fromOffset((i - 1) * 180, 0)
		b.Size = UDim2.fromOffset(170, 56)
		b.Parent = slotBar
		corner(b, 8)
		local st = Instance.new("UIStroke")
		st.Thickness = 1.5
		st.Color = INK
		st.Transparency = 0.6
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = b
		local key = label(b, if i == 1 then "Q" else "E", 12, INK_DIM, FONT)
		key.Position = UDim2.fromOffset(10, 6)
		key.Size = UDim2.fromOffset(40, 14)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local cost = label(b, "", 12, INK_DIM, FONT)
		cost.AnchorPoint = Vector2.new(1, 0)
		cost.Position = UDim2.new(1, -10, 0, 6)
		cost.Size = UDim2.fromOffset(110, 14)
		cost.TextXAlignment = Enum.TextXAlignment.Right
		local name = label(b, "", 15, INK, FONT)
		name.Position = UDim2.fromOffset(10, 24)
		name.Size = UDim2.new(1, -20, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		b.Activated:Connect(function()
			callbacks.onAbility(i)
		end)
		slots[i] = { frame = b, name = name, cost = cost, key = key, stroke = st }
	end
	if UserInputService.TouchEnabled then
		-- around the swing button on phones, so the right thumb reaches all three:
		-- ability 1 to its left, ability 2 just above it
		slotBar.AnchorPoint = Vector2.new(1, 1)
		slotBar.Position = UDim2.new(1, 0, 1, 0)
		slotBar.Size = UDim2.fromOffset(300, 400)
		-- inside this 300x400 box the swing button covers x 152..264, y 138..250
		local places = { UDim2.fromOffset(20, 166), UDim2.fromOffset(152, 70) }
		for i, s in slots do
			s.frame.Position = places[i] or s.frame.Position
			s.frame.Size = UDim2.fromOffset(if i == 1 then 120 else 112, 56)
			s.key.Text = ""
		end
	end

	-- which way the next return will go: ◀ ● ▶ (left, straight, right on screen)
	local aim = label(match, "", 16, INK)
	aim.Name = "Aim"
	aim.AnchorPoint = Vector2.new(0.5, 1)
	aim.Position = UDim2.new(0.5, 0, 1, if UserInputService.TouchEnabled then -60 else -120)
	aim.Size = UDim2.fromOffset(220, 24)
	aim.Visible = false

	local announce = label(match, "", 26, INK)
	announce.AnchorPoint = Vector2.new(0.5, 0.5)
	announce.Position = UDim2.fromScale(0.5, 0.24)
	announce.Size = UDim2.fromOffset(600, 34)
	announce.TextTransparency = 1
	local announceStroke = Instance.new("UIStroke")
	announceStroke.Thickness = 2
	announceStroke.Color = Color3.new(0, 0, 0)
	announceStroke.Transparency = 0.4
	announceStroke.Parent = announce

	gui.Parent = playerGui

	local self = setmetatable({
		gui = gui,
		bound = bound,
		menu = menu,
		profile = profile,
		menuNote = menuNote,
		pickChips = pickChips,
		pickInfo = pickInfo,
		pickFocus = nil :: string?,
		loadout = table.clone(Abilities.DefaultLoadout),
		lastProfile = nil :: { [string]: any }?,
		leaderboard = leaderboard,
		boardTitle = boardTitle,
		boardRows = boardRows,
		boardTabs = boardTabs,
		boardRegion = "ASIA",
		lastBoard = nil :: { scope: string, rows: { { [string]: any } } }?,
		feedback = feedback,
		fbCategory = "fun",
		fbCats = fbCats,
		fbBox = fbBox,
		fbStatus = fbStatus,
		waiting = waiting,
		waitTitle = waitTitle,
		waitSub = waitSub,
		waitBot = waitBot,
		waitCancel = waitCancel,
		match = match,
		scoreboard = scoreboard,
		myPoints = myPoints,
		theirPoints = theirPoints,
		theirName = theirName,
		myGames = myGames,
		theirGames = theirGames,
		myServe = myServe,
		theirServe = theirServe,
		rally = rally,
		ping = ping,
		gaugeCells = cells,
		popup = popup,
		popupSub = popupSub,
		hint = hint,
		controls = controls,
		aim = aim,
		tutorial = tutorial,
		announce = announce,
		slots = slots,
		slotIds = {},
		touchButton = touchButton,
		result = result,
		resultTitle = resultTitle,
		resultScore = resultScore,
		resultNote = resultNote,
		rankLine = rankLine,
		arenaButton = arenaButton,
		wind = wind,
		myName = myName,
		pass = pass,
		passLevel = passLevel,
		passXp = passXp,
		passBuy = passBuy,
		passRows = passRows,
		customize = customize,
		cosGrids = cosGrids,
		passState = nil :: { [string]: any }?,
		titles = { "", "" },
	}, Hud)

	-- menu extras: leaderboard, feedback, language
	local function extra(key: string, width: number, onClick: () -> ())
		local b = bind(button(extras, "", Palette.TeamA, onClick), key)
		b.Size = UDim2.new(width, -4, 1, 0)
		b.TextSize = 14
		-- "Idioma: Português" and the like are wider than the button: shrink to fit
		b.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 14
		cap.Parent = b
	end
	extra("menu.leaderboard", 0.36, function()
		callbacks.onLeaderboard("GLOBAL")
	end)
	extra("menu.feedback", 0.4, function()
		self:showFeedback()
	end)
	extra("menu.language", 0.24, callbacks.onLanguage)
	for _, entry in
		{
			{
				"menu.pass",
				function()
					self:showPass()
				end,
			},
			{
				"menu.customize",
				function()
					self:showCustomize()
				end,
			},
		}
	do
		local b = bind(button(seasonRow, "", Palette.Grade.Perfect, entry[2]), entry[1])
		b.Size = UDim2.new(0.5, -3, 1, 0)
		b.TextSize = 14
	end

	for _, cat in FEEDBACK_CATEGORIES do
		local b = bind(
			button(cats, "", Palette.TeamA, function()
				self.fbCategory = cat
				self:refreshFeedback()
			end),
			"fb." .. cat
		)
		b.Size = UDim2.new(0.25, -5, 1, 0)
		b.TextSize = 13
		fbCats[cat] = b
	end
	fbSend.Activated:Connect(function()
		local text = string.sub(fbBox.Text, 1, 200)
		if #text > 0 then
			callbacks.onFeedback(self.fbCategory, text)
		end
	end)

	for _, def in Abilities.List do
		local chip = ordered(Instance.new("TextButton"))
		chip.TextSize = 13
		chip.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 14
		limit.Parent = chip
		local cpad = Instance.new("UIPadding")
		cpad.PaddingLeft = UDim.new(0, 6)
		cpad.PaddingRight = UDim.new(0, 6)
		cpad.Parent = chip
		chip.FontFace = FONT
		chip.TextColor3 = INK
		chip.BackgroundColor3 = FIELD
		chip.Parent = picks
		corner(chip, 6)
		local st = Instance.new("UIStroke")
		st.Color = abilityColor(def.id)
		st.Transparency = 0.6
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = chip
		chip.Activated:Connect(function()
			self:togglePick(def.id)
		end)
		pickChips[def.id] = chip
	end
	boardTabs[1].Activated:Connect(function()
		callbacks.onLeaderboard("GLOBAL")
	end)
	boardTabs[2].Activated:Connect(function()
		callbacks.onLeaderboard(self.boardRegion)
	end);
	(self :: any).onEquip = callbacks.onEquip
	self:relabel()
	return self
end

-- Redraws every piece of text in the current language.
function Hud.relabel(self: Hud)
	for _, b in self.bound do
		b.inst[b.prop] = S.t(b.key)
	end
	for id, chip in self.pickChips do
		local def = Abilities.get(id)
		chip.Text = `{S.abilityName(id)}  {if def then def.cost else ""}`
	end
	self:refreshPicks(self.pickFocus or self.loadout[1])
	self:setSlots(self.slotIds)
	self:refreshFeedback()
	if self.lastProfile then
		self:setProfile(self.lastProfile)
	end
	self.boardTabs[2].Text = S.region(self.boardRegion)
	if self.lastBoard then
		self:showLeaderboard(self.lastBoard.scope, self.lastBoard.rows, self.leaderboard.Visible)
	end
	self.myName.Text = S.t("hud.you") .. self.titleSuffix(self.titles[1])
	if self.passState then
		self:setPassState(self.passState)
	end
end

-- " · <title>" for a title id, "" for none.
function Hud.titleSuffix(id: string?): string
	return if id and id ~= "" then " · " .. S.item(id) else ""
end

function Hud.setArenaButton(self: Hud, text: string)
	self.arenaButton.Text = text
end

-- The wind indicator (Sakura Float); nil hides it.
function Hud.setWind(self: Hud, text: string?)
	self.wind.Visible = text ~= nil
	self.wind.Text = text or ""
end

-- Titles shown next to the names in a match: { mine, theirs } as item ids ("" for none).
function Hud.setTitles(self: Hud, mine: string, theirs: string, opponentName: string)
	self.titles = { mine, theirs }
	self.myName.Text = S.t("hud.you") .. Hud.titleSuffix(mine)
	self.theirName.Text = opponentName .. Hud.titleSuffix(theirs)
end

local function itemColor(id: string): Color3
	local item = Cosmetics.get(id)
	if item and item.rgb then
		return Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3])
	end
	return Palette.Grade.Perfect
end

-- Pass and inventory as sent by the server (Profile.pass or PassUpdate.state).
function Hud.setPassState(self: Hud, state: { [string]: any })
	self.passState = state
	local xp = state.passXp
	local level = BattlePass.level(xp)
	local into, need = BattlePass.progress(xp)
	self.passLevel.Text = S.t("pass.level", { n = level, max = BattlePass.MAX_LEVEL })
	self.passXp.Text = if need > 0 then S.t("pass.xp", { xp = into, need = need }) else ""
	self.passBuy.Text = if state.premium then S.t("pass.owned") else S.t("pass.buy", { price = BattlePass.PRICE })
	self.passBuy.Active = not state.premium
	self.passBuy.AutoButtonColor = not state.premium
	local owned: { [string]: boolean } = {}
	for _, id in state.items do
		owned[id] = true
	end
	-- pass rows
	for _, c in self.passRows:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for lv = 1, BattlePass.MAX_LEVEL do
		local free, premium = BattlePass.Free[lv], BattlePass.Premium[lv]
		if free or premium then
			local function cell(id: string?, track: string): string
				if not id then
					return ""
				end
				local mark = if owned[id] then " ✓" else ""
				return `{S.t(track)}: {S.item(id)}{mark}`
			end
			local parts = {}
			if free then
				table.insert(parts, cell(free, "pass.free"))
			end
			if premium then
				table.insert(parts, cell(premium, "pass.premium"))
			end
			local r = label(
				self.passRows,
				`{S.t("pass.row", { n = lv })}   {table.concat(parts, "   ")}`,
				13,
				if lv <= level then INK else INK_DIM,
				FONT_REGULAR
			)
			r.TextXAlignment = Enum.TextXAlignment.Left
			r.LayoutOrder = lv
		end
	end
	-- customize grids
	for kind, g in self.cosGrids do
		for _, c in g:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local choices: { string } = {}
		if kind ~= "paddle" then
			table.insert(choices, "")
		end
		for _, item in Cosmetics.ofKind(kind :: any) do
			table.insert(choices, item.id)
		end
		for i, id in choices do
			local has = id == "" or owned[id] == true
			local on = (state.equipped :: any)[kind] == id
			local text = if id == ""
				then S.t("cos.none")
				elseif has then S.item(id)
				else S.item(id) .. " (" .. S.t("cos.locked") .. ")"
			local b = button(g, text, if id == "" then INK_DIM else itemColor(id), function()
				if has then
					self:equipLocal(kind, id)
				end
			end)
			b.LayoutOrder = i
			b.TextSize = 13
			b.TextTransparency = if has then 0 else 0.55
			b.BackgroundColor3 = if on then itemColor(id):Lerp(PANEL, 0.55) else FIELD
			b:SetAttribute("ItemId", id)
		end
	end
end

-- Set by the client script: sends an equip request.
function Hud.equipLocal(self: Hud, kind: string, id: string)
	local cb = (self :: any).onEquip
	if cb then
		cb(kind, id)
	end
end

function Hud.showPass(self: Hud)
	self.leaderboard.Visible = false
	self.feedback.Visible = false
	self.customize.Visible = false
	self.pass.Visible = true
end

function Hud.showCustomize(self: Hud)
	self.leaderboard.Visible = false
	self.feedback.Visible = false
	self.pass.Visible = false
	self.customize.Visible = true
end

function Hud.setProfile(self: Hud, p: { [string]: any })
	self.lastProfile = p
	local tier = if p.tierId == "Legend"
		then S.rank("Legend")
		else S.rank(Rating.tier(p.rating).id, Rating.tier(p.rating).division)
	self.profile.Text = S.t("menu.profile", {
		tier = tier,
		rating = p.rating,
		wins = p.wins,
		losses = p.losses,
		region = S.region(p.region),
		extra = if p.placement > 0 then S.t("menu.placement", { n = p.placement }) else "",
	})
	self.boardRegion = p.region
	self.boardTabs[2].Text = S.region(p.region)
end

-- A short message on the menu (e.g. why ranked play was refused). Empty hides it.
-- Problems are red; pass good = true for a friendly tip.
function Hud.setMenuNote(self: Hud, text: string, good: boolean?)
	self.menuNote.Text = text
	self.menuNote.TextColor3 = if good then Palette.Grade.Good else Palette.Grade.Miss
	self.menuNote.Visible = text ~= ""
end

export type WaitOptions = { title: string, sub: string?, cancel: boolean?, bot: boolean? }

function Hud.showWaiting(self: Hud, opts: WaitOptions?)
	local o: WaitOptions = opts or { title = S.t("wait.casual"), sub = S.t("wait.casualSub") }
	self.menu.Visible = false
	self.match.Visible = false
	self.result.Visible = false
	self.leaderboard.Visible = false
	self.feedback.Visible = false
	self.waiting.Visible = true
	self.waitTitle.Text = o.title
	self.waitSub.Text = o.sub or ""
	self.waitCancel.Visible = o.cancel ~= false
	self.waitBot.Visible = o.bot == true
end

function Hud.showLeaderboard(self: Hud, scope: string, rows: { { [string]: any } }, show: boolean?)
	self.lastBoard = { scope = scope, rows = rows }
	if show ~= false then
		self.leaderboard.Visible = true
		self.feedback.Visible = false
	end
	self.boardTitle.Text = S.t("board.titleScope", {
		scope = if scope == "GLOBAL" then S.t("board.world") else S.region(scope),
	})
	for i, r in self.boardRows do
		local entry = rows[i]
		r.Text = if entry
			then `{entry.rank}.  {entry.name}   {entry.rating}`
			elseif i == 1 then S.t("board.empty")
			else ""
	end
end

function Hud.showFeedback(self: Hud)
	self.leaderboard.Visible = false
	self.feedback.Visible = true
	self.fbStatus.Text = ""
	self:refreshFeedback()
end

function Hud.refreshFeedback(self: Hud)
	for cat, b in self.fbCats do
		b.BackgroundColor3 = if cat == self.fbCategory then Palette.TeamA:Lerp(PANEL, 0.55) else FIELD
	end
end

-- Result of sending feedback: "ok" | "tooSoon" | "failed".
function Hud.feedbackResult(self: Hud, status: string)
	if status == "ok" then
		self.fbStatus.Text = S.t("fb.thanks")
		self.fbBox.Text = ""
	elseif status == "tooSoon" then
		self.fbStatus.Text = S.t("fb.tooSoon")
	else
		self.fbStatus.Text = S.t("fb.failed")
	end
end

-- After a ranked match: how the rating and rank moved.
function Hud.setRankResult(self: Hud, e: { [string]: any })
	local before, after = Rating.tier(e.before), Rating.tier(e.after)
	local beforeText, afterText = S.rank(before.id, before.division), S.rank(after.id, after.division)
	local sign = if e.delta >= 0 then "+" else ""
	local tierText = if beforeText ~= afterText then `{beforeText} → {afterText}` else afterText
	self.rankLine.Text = S.t("result.rating", { before = e.before, after = e.after, delta = sign .. e.delta })
		.. "\n"
		.. tierText
	self.rankLine.TextColor3 = if e.delta >= 0 then Palette.Grade.Good else Palette.Grade.Miss
	self.rankLine.Visible = true
	if e.rankUp then
		self:popupText(S.t("result.rankUp", { tier = afterText }), Palette.Grade.Perfect)
	end
end

-- Picking a third ability drops the oldest pick.
function Hud.togglePick(self: Hud, id: string)
	local i = table.find(self.loadout, id)
	if i then
		if #self.loadout > 1 then
			table.remove(self.loadout, i)
		end
	else
		table.insert(self.loadout, id)
		if #self.loadout > Abilities.SLOTS then
			table.remove(self.loadout, 1)
		end
	end
	self:refreshPicks(id)
end

function Hud.refreshPicks(self: Hud, focus: string?)
	self.pickFocus = focus
	for id, chip in self.pickChips do
		local on = table.find(self.loadout, id) ~= nil
		local color = abilityColor(id)
		chip.BackgroundColor3 = if on then color:Lerp(PANEL, 0.55) else FIELD
		local st = chip:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = if on then 0 else 0.6
		end
	end
	if focus then
		self.pickInfo.Text = S.abilityInfo(focus)
	end
end

function Hud.getLoadout(self: Hud): { string }
	return table.clone(self.loadout)
end

-- Shows the abilities brought into this match.
function Hud.setSlots(self: Hud, loadout: { string })
	for i, s in self.slots do
		local id = loadout[i]
		local def = if id then Abilities.get(id) else nil
		s.frame.Visible = def ~= nil
		self.slotIds[i] = id
		if def then
			s.name.Text = S.abilityName(def.id)
			s.cost.Text = S.t("hud.cost", { n = def.cost })
			s.stroke.Color = abilityColor(def.id)
		end
	end
end

-- state per slot: "ready" | "armed" | "waiting" (not enough gauge / used / between points)
function Hud.setSlotStates(self: Hud, states: { string })
	for i, s in self.slots do
		local state = states[i] or "waiting"
		s.frame.BackgroundTransparency = if state == "waiting" then 0.55 else 0.15
		s.name.TextTransparency = if state == "waiting" then 0.5 else 0
		s.stroke.Thickness = if state == "armed" then 3 else 1.5
		s.stroke.Transparency = if state == "waiting" then 0.7 elseif state == "armed" then 0 else 0.2
		local id = self.slotIds[i]
		local def = if id then Abilities.get(id) else nil
		s.cost.Text = if state == "armed"
			then S.t("hud.armedSlot")
			elseif def then S.t("hud.cost", { n = def.cost })
			else ""
	end
end

-- A big coloured line telling both players which ability was just used.
function Hud.announceAbility(self: Hud, text: string, color: Color3)
	self.announce.Text = text
	self.announce.TextColor3 = color
	self.announce.TextTransparency = 0
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.7)
	TweenService:Create(self.announce, info, { TextTransparency = 1 }):Play()
end

-- The tutorial's current instruction, or nil to hide it.
function Hud.setTutorial(self: Hud, text: string?)
	self.tutorial.Visible = text ~= nil
	self.tutorial.Text = text or ""
end

function Hud.showMenu(self: Hud)
	self:setWind(nil)
	self.menu.Visible = true
	self.match.Visible = false
	self.result.Visible = false
	self.waiting.Visible = false
	self:setTutorial(nil)
end

function Hud.showMatch(self: Hud, opponentName: string)
	self.pass.Visible = false
	self.customize.Visible = false
	self.rankLine.Visible = false
	self.leaderboard.Visible = false
	self.feedback.Visible = false
	self.menu.Visible = false
	self.result.Visible = false
	self.waiting.Visible = false
	self.match.Visible = true
	self.theirName.Text = opponentName
	self.rally.Text = ""
	self.hint.Text = ""
	self:setGauge(0)
end

local function dots(n: number): string
	return string.rep("●", n) .. string.rep("○", 2 - n)
end

function Hud.setScore(self: Hud, snap: { [string]: any }, me: number)
	local them = if me == 1 then 2 else 1
	self.myPoints.Text = tostring(snap.points[me])
	self.theirPoints.Text = tostring(snap.points[them])
	self.myGames.Text = S.t("hud.games") .. " " .. dots(snap.games[me])
	self.theirGames.Text = dots(snap.games[them]) .. " " .. S.t("hud.games")
	self.myServe.Visible = snap.server == me
	self.theirServe.Visible = snap.server == them
	self:setGauge(snap.gauge[me])
end

function Hud.setGauge(self: Hud, value: number)
	for i, c in self.gaugeCells do
		c.BackgroundColor3 = if i <= value then Palette.TeamA else Color3.fromRGB(30, 38, 60)
	end
end

function Hud.setRally(self: Hud, n: number)
	self.rally.Text = if n >= 2 then S.t("hud.rally", { n = n }) else ""
end

function Hud.setHint(self: Hud, text: string)
	self.hint.Text = text
end

-- The aim marker: nil hides it, otherwise -1 (left on screen) .. 1 (right on screen).
function Hud.setAim(self: Hud, screenAim: number?)
	if screenAim == nil then
		self.aim.Visible = false
		return
	end
	self.aim.Visible = true
	local mark = if screenAim < -0.33
		then "◀◀  ·  ·"
		elseif screenAim > 0.33 then "·  ·  ▶▶"
		else "·  ●  ·"
	self.aim.Text = S.t("hud.aim", { mark = mark })
end

-- The how-to-play box shown during a match.
function Hud.setControls(self: Hud, text: string)
	self.controls.Text = text
end

-- Shows the timing grade. offset = seconds early (negative) or late (positive).
function Hud.popupGrade(self: Hud, grade: string, offset: number?)
	local color = if grade == "Barrier" then abilityColor("Barrier") else (Palette.Grade[grade] or INK)
	self.popup.Text = if S.has("grade." .. grade) then S.t("grade." .. grade) else grade
	self.popup.TextColor3 = color
	self.popup.TextTransparency = 0
	self.popup.Size = UDim2.fromOffset(600, if grade == "Perfect" then 96 else 72)
	self.popup.TextSize = if grade == "Perfect" then 72 else 54
	local sub = ""
	if offset and grade ~= "Perfect" and grade ~= "Barrier" then
		local ms = math.round(math.abs(offset) * 1000)
		sub = S.t(if offset < 0 then "hud.early" else "hud.late", { ms = ms })
	end
	self.popupSub.Text = sub
	self.popupSub.TextTransparency = 0
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25)
	TweenService:Create(self.popup, info, { TextTransparency = 1 }):Play()
	TweenService:Create(self.popupSub, info, { TextTransparency = 1 }):Play()
end

function Hud.popupText(self: Hud, text: string, color: Color3)
	self.popup.Text = text
	self.popup.TextColor3 = color
	self.popup.TextSize = 54
	self.popup.TextTransparency = 0
	self.popupSub.Text = ""
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(self.popup, info, { TextTransparency = 1 }):Play()
end

-- Round-trip time to the server, in milliseconds.
function Hud.setPing(self: Hud, ms: number)
	self.ping.Text = S.t("hud.ping", { ms = math.round(ms) })
	self.ping.TextColor3 = if ms > 250 then Palette.Grade.Miss elseif ms > 150 then Palette.Grade.Perfect else INK_DIM
end

function Hud.showResult(self: Hud, won: boolean, myGames: number, theirGames: number, note: string?)
	self.result.Visible = true
	self.resultNote.Text = note or ""
	self.resultNote.Visible = note ~= nil
	self.resultTitle.Text = S.t(if won then "result.win" else "result.lose")
	self.resultTitle.TextColor3 = if won then Palette.Grade.Perfect else Palette.Grade.Miss
	self.resultScore.Text = S.t("result.games", { a = myGames, b = theirGames })
	self.hint.Text = ""
	self:setTutorial(nil)
end

return Hud
