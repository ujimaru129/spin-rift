--!strict
-- Screen UI: mode menu, scoreboard, gauge, hit-timing popups, result panel and the touch button.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Palette"))

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local FONT_REGULAR = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local PANEL = Color3.fromRGB(8, 11, 22)
local INK = Color3.fromRGB(238, 243, 255)
local INK_DIM = Color3.fromRGB(154, 166, 196)
local GAUGE_MAX = 10

export type Callbacks = {
	onMode: (mode: string) -> (),
	onLeave: () -> (),
	onRetry: () -> (),
	onSwingButton: () -> (),
}

local Hud = {}
Hud.__index = Hud

export type Hud = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		menu: Frame,
		match: Frame,
		result: Frame,
		waiting: Frame,
		ping: TextLabel,
		resultNote: TextLabel,
		myPoints: TextLabel,
		theirPoints: TextLabel,
		theirName: TextLabel,
		myGames: TextLabel,
		theirGames: TextLabel,
		myServe: Frame,
		theirServe: Frame,
		rally: TextLabel,
		gaugeCells: { Frame },
		popup: TextLabel,
		popupSub: TextLabel,
		hint: TextLabel,
		resultTitle: TextLabel,
		resultScore: TextLabel,
		touchButton: TextButton?,
	},
	Hud
))

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
	return l
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
	b.BackgroundColor3 = Color3.fromRGB(16, 22, 40)
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
	return b
end

local function vlist(parent: Instance, padding: number)
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
end

function Hud.new(playerGui: PlayerGui, callbacks: Callbacks): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinRiftHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- menu
	local menu = panel(gui, "Menu")
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.new(0, 340, 0, 0)
	menu.AutomaticSize = Enum.AutomaticSize.Y
	vlist(menu, 10)
	local title = label(menu, "SPIN RIFT", 40, Palette.TeamA)
	title.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	label(menu, "試作版（フェーズ2）", 14, INK_DIM, FONT_REGULAR)
	button(menu, "オンライン対戦（このサーバーの人と）", Palette.Grade.Perfect, function()
		callbacks.onMode("Online")
	end)
	button(menu, "壁打ち", Palette.TeamA, function()
		callbacks.onMode("Wall")
	end)
	button(menu, "Bot と対戦：やさしい", Palette.Grade.Good, function()
		callbacks.onMode("Easy")
	end)
	button(menu, "Bot と対戦：ふつう", Palette.TeamB, function()
		callbacks.onMode("Normal")
	end)
	button(menu, "Bot と対戦：つよい", Palette.Grade.Perfect, function()
		callbacks.onMode("Hard")
	end)
	local help = label(
		menu,
		"移動：WASD・左スティック\n打つ：クリック・スペース・R2・画面の「打つ」\nコース：マウスの左右・右スティック・移動の向き\nボールが自分のラケットに来た瞬間に打つと PERFECT",
		13,
		INK_DIM,
		FONT_REGULAR
	)
	help.Size = UDim2.new(1, 0, 0, 84)
	help.TextXAlignment = Enum.TextXAlignment.Left

	-- waiting for an opponent
	local waiting = panel(gui, "Waiting")
	waiting.AnchorPoint = Vector2.new(0.5, 0.5)
	waiting.Position = UDim2.fromScale(0.5, 0.5)
	waiting.Size = UDim2.new(0, 320, 0, 0)
	waiting.AutomaticSize = Enum.AutomaticSize.Y
	waiting.Visible = false
	vlist(waiting, 10)
	label(waiting, "相手を待っています…", 22, INK)
	label(
		waiting,
		"このサーバーで、もう1人が「オンライン対戦」を押すと始まります",
		13,
		INK_DIM,
		FONT_REGULAR
	).Size =
		UDim2.new(1, 0, 0, 36)
	button(waiting, "キャンセル", Palette.TeamB, callbacks.onLeave)

	-- match HUD
	local match = Instance.new("Frame")
	match.Name = "Match"
	match.BackgroundTransparency = 1
	match.Size = UDim2.fromScale(1, 1)
	match.Visible = false
	match.Parent = gui

	local board = panel(match, "Scoreboard")
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0, 14)
	board.Size = UDim2.new(0, 360, 0, 66)

	local function side(xScale: number, name: string, color: Color3, align: Enum.TextXAlignment)
		local n = label(board, name, 14, color)
		n.Position = UDim2.new(xScale, 0, 0, 8)
		n.Size = UDim2.new(0.5, -60, 0, 18)
		n.TextXAlignment = align
		local games = label(board, "", 13, INK_DIM, FONT_REGULAR)
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
		serve.Parent = board
		corner(serve, 4)
		return n, games, serve
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = board
	local _, myGames, myServe = side(0, "あなた", Palette.TeamA, Enum.TextXAlignment.Left)
	local theirName, theirGames, theirServe = side(0.5, "BOT", Palette.TeamB, Enum.TextXAlignment.Right)
	theirName.Position += UDim2.fromOffset(60, 0)
	theirGames.Position += UDim2.fromOffset(60, 0)

	local score = label(board, "", 34, INK)
	score.AnchorPoint = Vector2.new(0.5, 0.5)
	score.Position = UDim2.fromScale(0.5, 0.5)
	score.Size = UDim2.fromOffset(120, 40)
	score.Text = ""
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

	local leave = Instance.new("TextButton")
	leave.Text = "メニュー"
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
	leave.Activated:Connect(callbacks.onLeave)

	local ping = label(match, "", 12, INK_DIM, FONT_REGULAR)
	ping.AnchorPoint = Vector2.new(1, 0)
	ping.Position = UDim2.new(1, -14, 0, 56)
	ping.Size = UDim2.fromOffset(140, 16)
	ping.TextXAlignment = Enum.TextXAlignment.Right

	-- gauge
	local gauge = panel(match, "Gauge")
	gauge.AnchorPoint = Vector2.new(0, 1)
	gauge.Position = UDim2.new(0, 14, 1, -14)
	gauge.Size = UDim2.fromOffset(250, 54)
	local gl = label(gauge, "リフトゲージ", 12, INK_DIM, FONT_REGULAR)
	gl.Position = UDim2.fromOffset(12, 6)
	gl.Size = UDim2.new(1, -24, 0, 16)
	gl.TextXAlignment = Enum.TextXAlignment.Left
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

	-- popup
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
	hint.Size = UDim2.fromOffset(520, 26)

	-- result
	local result = panel(gui, "Result")
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = UDim2.fromScale(0.5, 0.5)
	result.Size = UDim2.new(0, 320, 0, 0)
	result.AutomaticSize = Enum.AutomaticSize.Y
	result.Visible = false
	vlist(result, 10)
	local resultTitle = label(result, "", 40, Palette.Grade.Perfect)
	local resultScore = label(result, "", 18, INK_DIM, FONT_REGULAR)
	local resultNote = label(result, "", 14, INK_DIM, FONT_REGULAR)
	button(result, "もう一度", Palette.TeamA, callbacks.onRetry)
	button(result, "メニューへ", Palette.TeamB, callbacks.onLeave)

	-- touch swing button
	local touchButton: TextButton? = nil
	if UserInputService.TouchEnabled then
		local t = Instance.new("TextButton")
		t.Name = "SwingButton"
		t.Text = "打つ"
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
		t.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				callbacks.onSwingButton()
			end
		end)
		touchButton = t
	end

	gui.Parent = playerGui

	return setmetatable({
		gui = gui,
		menu = menu,
		match = match,
		result = result,
		waiting = waiting,
		ping = ping,
		resultNote = resultNote,
		myPoints = myPoints,
		theirPoints = theirPoints,
		theirName = theirName,
		myGames = myGames,
		theirGames = theirGames,
		myServe = myServe,
		theirServe = theirServe,
		rally = rally,
		gaugeCells = cells,
		popup = popup,
		popupSub = popupSub,
		hint = hint,
		resultTitle = resultTitle,
		resultScore = resultScore,
		touchButton = touchButton,
	}, Hud)
end

function Hud.showMenu(self: Hud)
	self.menu.Visible = true
	self.match.Visible = false
	self.result.Visible = false
	self.waiting.Visible = false
end

function Hud.showWaiting(self: Hud)
	self.menu.Visible = false
	self.match.Visible = false
	self.result.Visible = false
	self.waiting.Visible = true
end

function Hud.showMatch(self: Hud, opponentName: string)
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
	self.myGames.Text = "ゲーム " .. dots(snap.games[me])
	self.theirGames.Text = dots(snap.games[them]) .. " ゲーム"
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
	self.rally.Text = if n >= 2 then `ラリー {n}` else ""
end

function Hud.setHint(self: Hud, text: string)
	self.hint.Text = text
end

local GRADE_TEXT = { Perfect = "PERFECT!!", Good = "GOOD", Weak = "あまい…", Miss = "MISS" }

-- Shows the timing grade. offset = seconds early (negative) or late (positive).
function Hud.popupGrade(self: Hud, grade: string, offset: number?)
	local color = Palette.Grade[grade] or INK
	self.popup.Text = GRADE_TEXT[grade] or grade
	self.popup.TextColor3 = color
	self.popup.TextTransparency = 0
	self.popup.Size = UDim2.fromOffset(600, if grade == "Perfect" then 96 else 72)
	self.popup.TextSize = if grade == "Perfect" then 72 else 54
	local sub = ""
	if offset and grade ~= "Perfect" then
		local ms = math.round(math.abs(offset) * 1000)
		sub = if offset < 0 then `{ms}ms 早い` else `{ms}ms 遅い`
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
	self.ping.Text = `通信 {math.round(ms)}ms`
	self.ping.TextColor3 = if ms > 250 then Palette.Grade.Miss elseif ms > 150 then Palette.Grade.Perfect else INK_DIM
end

function Hud.showResult(self: Hud, won: boolean, myGames: number, theirGames: number, note: string?)
	self.result.Visible = true
	self.resultNote.Text = note or ""
	self.resultNote.Visible = note ~= nil
	self.resultTitle.Text = if won then "WIN!" else "LOSE"
	self.resultTitle.TextColor3 = if won then Palette.Grade.Perfect else Palette.Grade.Miss
	self.resultScore.Text = `ゲーム {myGames} - {theirGames}`
	self.hint.Text = ""
end

return Hud
