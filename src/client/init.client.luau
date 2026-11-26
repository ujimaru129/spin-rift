--!strict
-- Client entry point: input, camera, ball drawing and HUD for every mode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Abilities = require(Shared:WaitForChild("Rally"):WaitForChild("Abilities"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Matchmaker = require(Shared:WaitForChild("Rank"):WaitForChild("Matchmaker"))
local S = require(Shared:WaitForChild("Strings"))
local BallView = require(script.BallView)
local Fx = require(script.Fx)
local Audio = require(script.Audio)
local Hud = require(script.Hud)
local ArenaLook = require(script.ArenaLook)
local City = require(script.City)
local Garden = require(script.Garden)
local SeasonFolder = Shared:WaitForChild("Season")
local Arenas = require(SeasonFolder:WaitForChild("Arenas"))
local Cosmetics = require(SeasonFolder:WaitForChild("Cosmetics"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- The player's own language (English if we don't have it); the menu button switches it.
-- In Studio the game always starts in Japanese, whatever language Studio itself uses.
S.setLocale(if RunService:IsStudio() then "ja" else S.fromLocaleId(LocalizationService.RobloxLocaleId))

local requestRemote = Net.get(Net.REQUEST_MATCH)
local leaveRemote = Net.get(Net.LEAVE_MATCH)
local swingRemote = Net.get(Net.SWING)
local helloRemote = Net.get(Net.HELLO)
local leaderboardRemote = Net.get(Net.REQUEST_LEADERBOARD)
local feedbackRemote = Net.get(Net.SEND_FEEDBACK)
local equipRemote = Net.get(Net.EQUIP)
local premiumRemote = Net.get(Net.BUY_PREMIUM)
local matchEvent = Net.get(Net.MATCH_EVENT)

local ball = BallView.new()
local origin: Vector3? = nil
local me = 1 -- our player index in the current match (1 stands on side -1)
local mySide = -1
local currentMode = "Wall"
local opponentMode: string? = nil -- the Bot level of this match's opponent
local stickAim = 0
-- direction keys held right now (on screen): arrows move us ourselves, A/D move through Roblox
local arrowLeft, arrowRight, keyA, keyD = false, false, false, false
-- mouse aim only counts while the mouse is being used (a trackpad user never has to touch it)
local MOUSE_AIM_FOR = 1.5
local lastMouseMove = -math.huge
local shake = 0
local cameraZ = 0
-- Match camera: how far behind the paddle line it sits, how high, and its field of view.
-- Close and narrow enough that the table fills the middle of a phone screen.
local MATCH_FOV = 40
local CAMERA_BACK = 12
local CAMERA_HEIGHT = 11
local CAMERA_FOCUS = 1 -- how far past the net it aims
local lastSwingSent = 0
local selectedArena = Arenas.DEFAULT
local bestRating = 1000
local MENU_CITY = Vector3.new(0, 6, 0) -- the city behind the menu, round the spawn
local windActive = false

-- what the ability slots show
local myLoadout: { string } = {}
local myGauge = 0
local usedThisRally = false
local nextSlot = 1 -- the ability that fires next
local inRally = false
local barrierWalls: { [number]: Part } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function them(): number
	return if me == 1 then 2 else 1
end

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Aim across the table as a world Z direction, -1..1. In order:
--   1. a direction key held as you hit (← → or A D): that side, as seen on screen
--   2. the mouse, if it moved in the last moments: left/right of the screen
--   3. the right stick
--   4. the way you are moving (phones: the move stick)
-- The screen's right is +Z or -Z depending on which side of the table we are on.
local function screenFlip(): number
	return if camera.CFrame.RightVector:Dot(Vector3.zAxis) >= 0 then 1 else -1
end

local function heldDirection(): number
	return ((if arrowRight or keyD then 1 else 0) - (if arrowLeft or keyA then 1 else 0))
end

local function currentAim(): number
	local flip = screenFlip()
	local keys = heldDirection()
	if keys ~= 0 then
		return keys * flip
	end
	if UserInputService.MouseEnabled and os.clock() - lastMouseMove < MOUSE_AIM_FOR then
		local m = UserInputService:GetMouseLocation()
		local w = camera.ViewportSize.X
		return math.clamp(((m.X / w) * 2 - 1) * 1.4, -1, 1) * flip
	end
	if math.abs(stickAim) > 0.15 then
		return stickAim * flip
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.clamp(humanoid.MoveDirection.Z * 1.5, -1, 1)
	end
	return 0
end

-- screenAim: from the touch HIT button (-1 left, 0 straight, 1 right on screen); otherwise the
-- aim comes from keys, mouse or sticks (currentAim).
local function swing(screenAim: number?)
	local o = origin
	if not o then
		return
	end
	local t = now()
	if t - lastSwingSent < 0.12 then
		return
	end
	lastSwingSent = t
	local root = myRoot()
	local z = if root then root.Position.Z - o.Z else 0
	local aim = if screenAim ~= nil then screenAim * screenFlip() else currentAim()
	swingRemote:FireServer(t, math.clamp(aim, -1, 1), z)
end

local function arenaButtonText(): string
	local a = Arenas.get(selectedArena) or Arenas.List[1]
	local text = S.t("menu.arena", { name = S.t("arena." .. a.id) })
	if bestRating < a.unlockRating then
		text ..= "  (" .. S.t("arena.locked", { rank = S.rank(a.unlockRank) }) .. ")"
	elseif a.wind then
		text ..= "\n" .. S.t("arena.windNote")
	end
	return text
end

local hud
local function refreshSoundButtons()
	local music, sfx = Audio.isOn()
	hud:setSoundButtons(music, sfx)
end
hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
	onMode = function(mode: string)
		currentMode = mode
		requestRemote:FireServer(mode, hud:getLoadout(), selectedArena)
	end,
	onLeave = function()
		leaveRemote:FireServer()
	end,
	onRetry = function()
		requestRemote:FireServer(currentMode, hud:getLoadout(), selectedArena)
	end,
	onSwingButton = swing,
	onLeaderboard = function(scope: string)
		leaderboardRemote:FireServer(scope)
	end,
	onLanguage = function()
		S.setLocale(S.nextLocale())
		hud:relabel()
		hud:setArenaButton(arenaButtonText())
		refreshSoundButtons()
	end,
	onMusic = function()
		Audio.toggleMusic()
		refreshSoundButtons()
	end,
	onSfx = function()
		Audio.toggleSfx()
		refreshSoundButtons()
	end,
	onArena = function()
		local i = 1
		for n, a in Arenas.List do
			if a.id == selectedArena then
				i = n
			end
		end
		selectedArena = Arenas.List[(i % #Arenas.List) + 1].id
		hud:setArenaButton(arenaButtonText())
	end,
	onBuyPremium = function()
		premiumRemote:FireServer()
	end,
	onEquip = function(kind: string, id: string)
		equipRemote:FireServer(kind, id)
	end,
	onFeedback = function(category: string, text: string)
		feedbackRemote:FireServer(category, text, S.locale())
	end,
})
hud:showMenu()
hud:setArenaButton(arenaButtonText())
refreshSoundButtons()
Audio.preload()
ArenaLook.apply(nil)
City.show(MENU_CITY)
Audio.music("menu")

-- Left/Right arrow keys move across the table. Roblox's own controls give these keys to the
-- camera, which our match camera does not use, so we steer the character while they are held.
-- A and D are only noted (Roblox moves us with them) because a held direction also aims.
local function trackArrow(input: InputObject, down: boolean): boolean
	local key = input.KeyCode
	if key == Enum.KeyCode.Left then
		arrowLeft = down
		return true
	elseif key == Enum.KeyCode.Right then
		arrowRight = down
		return true
	elseif key == Enum.KeyCode.A then
		keyA = down
	elseif key == Enum.KeyCode.D then
		keyD = down
	end
	return false
end
UserInputService.InputEnded:Connect(function(input)
	trackArrow(input, false)
end)

-- Which keys to show in the how-to-play box.
local function controlsText(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return S.t("controls.touch")
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return S.t("controls.gamepad")
	end
	return S.t("controls.keyboard")
end

UserInputService.InputBegan:Connect(function(input, processed)
	-- arrows count even when Roblox's camera claimed them (that is what "processed" means here),
	-- but not while typing in a text box
	if UserInputService:GetFocusedTextBox() == nil and trackArrow(input, true) then
		return
	end
	if processed then
		return
	end
	local t = input.UserInputType
	local key = input.KeyCode
	-- Space hits (left hand), or J (right hand, for A/D players)
	if
		t == Enum.UserInputType.MouseButton1
		or key == Enum.KeyCode.Space
		or key == Enum.KeyCode.J
		or key == Enum.KeyCode.ButtonR2
	then
		swing()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		lastMouseMove = os.clock()
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stickAim = input.Position.X
	end
end)

-- Space is our swing key during a match, so stop it from jumping.
local function setJump(enabled: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = if enabled then 50 else 0
	end
end

local function flashFov(amount: number)
	camera.FieldOfView = MATCH_FOV + amount
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { FieldOfView = MATCH_FOV }):Play()
end

local function serveHint(server: number)
	if server == me then
		hud:setHint(S.t(if UserInputService.TouchEnabled then "hint.serveTouch" else "hint.serve"))
	else
		hud:setHint(S.t("hint.theirServe"))
	end
end

-- "23s  rating ±150, your region"
local function searchText(waited: number): string
	local w = Matchmaker.window(waited)
	local diff = if w.maxDiff == math.huge then S.t("search.anyDiff") else S.t("search.diff", { n = w.maxDiff })
	return S.t(
		"wait.rankedStatus",
		{ seconds = math.floor(waited), search = diff .. " / " .. S.t("search." .. w.regions) }
	)
end

local function opponentLabel(e: { [string]: any }): string
	local mode = e.opponentMode
	if mode == "Wall" then
		return S.t("opponent.wall")
	elseif mode then
		return S.t("opponent.bot", { level = S.t("level." .. mode) })
	end
	return e.opponent
end

local tutorialStep: string? = nil
local function showTutorial(step: string, left: number)
	tutorialStep = step
	local key = if step == "hit"
		then "tut.hit"
		elseif step == "perfect" then "tut.perfect"
		elseif step == "ability" then "tut.ability"
		else "tut.done"
	hud:setTutorial(S.t(key, { n = left }))
end

local function refreshSlots()
	local states = {}
	for i, id in myLoadout do
		local def = Abilities.get(id)
		local enough = def ~= nil and myGauge >= def.cost
		states[i] = if i ~= nextSlot or usedThisRally then "waiting" elseif enough then "ready" else "next"
	end
	hud:setSlotStates(states)
end

local function clearBarrier(index: number)
	local wall = barrierWalls[index]
	if wall then
		wall:Destroy()
		barrierWalls[index] = nil
	end
end

local function abilityName(id: string): string
	return S.abilityName(id)
end

-- The big moment of a special move: cut-in with its name, a light tint, a small camera punch,
-- and its own effect in the arena (bolts, a black hole, a pillar of light ...).
local function specialFx(e: { [string]: any }, color: Color3, title: string)
	local o = origin
	if not o then
		return
	end
	hud:cutIn(title, color)
	Audio.sfx(e.id, e.player ~= me)
	ball:reveal(now() + 1.2)
	shake = 0.2
	flashFov(4)
	local side = if e.player == 1 then -1 else 1
	local ballPos = ball.ball.Position
	local paddle = o + Vector3.new(side * Config.HitX, Config.HitY, 0)
	local at = if e.state == "fired" then ballPos else paddle
	local towards = o + Vector3.new(-side * Config.HitX, Config.HitY, ballPos.Z - o.Z)
	local seconds: number? = nil
	if e.id == "TimeSlow" then
		at = ballPos
		seconds = Abilities.Tuning.TimeSlow.length
	elseif e.id == "GravityWell" then
		local targetSide = if e.target == 1 then -1 else 1
		at = o + Vector3.new(targetSide * 14, 0.1, 0)
		Fx.vortex(ball.folder, at, color, math.max((e.untilTime or now()) - now(), 0.5))
	elseif e.id == "Blink" then
		local root = if e.player == me then myRoot() else nil
		at = if root then Vector3.new(root.Position.X, o.Y + 0.2, root.Position.Z) else paddle
	elseif e.id == "EMP" and e.target == me then
		-- we are the one being jammed: static on screen and a flickering ball
		local left = math.max((e.untilTime or now()) - now(), 0.5)
		hud:glitch(left)
		ball:flicker(now() + left)
	end
	Fx.special(ball.folder, camera, e.id, color, at, towards, seconds)
end

local function onAbilityEvent(e: { [string]: any })
	local mine = e.player == me
	local color = Hud.abilityColor(e.id)
	local who = if mine then "" else S.t("ability.them")
	if e.state == "fired" or e.state == "used" then
		-- one line only: the cut-in band says who used what (no separate announcement)
		specialFx(e, color, S.t("ability.used", { who = who, ability = abilityName(e.id) }))
		if mine then
			usedThisRally = true
			myGauge = e.gauge or myGauge
			nextSlot = e.nextSlot or nextSlot
			hud:setGauge(myGauge)
		end
		local o = origin
		if e.state == "used" and o then
			local side = if e.player == 1 then -1 else 1
			if e.id == "Barrier" then
				clearBarrier(e.player)
				barrierWalls[e.player] = ball:barrierWall(side, color)
			elseif e.id == "GravityWell" then
				local targetSide = if e.target == 1 then -1 else 1
				ball:floorRing(targetSide, color, math.max(e.untilTime - now(), 0.5))
			elseif e.id == "Blink" then
				local root = if mine then myRoot() else nil
				local at = if root then root.Position else o + Vector3.new(side * 14, 0.2, 0)
				ball:flashAt(Vector3.new(at.X, o.Y + 0.2, at.Z), color)
			end
		end
	elseif e.state == "triggered" then
		Audio.sfx("BarrierHit", not mine)
		hud:announceAbility(S.t("ability.barrierFired", { who = who }), color)
		clearBarrier(e.player)
	elseif e.state == "expired" then
		clearBarrier(e.player)
	end
	refreshSlots()
end

local resultToken = 0
local function endMatchView()
	resultToken += 1
	Audio.music("menu")
	origin = nil
	windActive = false
	hud:setWind(nil)
	ArenaLook.apply(nil)
	Garden.show(nil)
	City.show(MENU_CITY)
	ball:hide()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	setJump(true)
end

local function onEvent(e: { [string]: any })
	local kind = e.kind
	if kind == "Queued" then
		hud:setMenuNote("")
		if e.ranked then
			hud:showWaiting({ title = S.t("wait.ranked"), sub = S.t("wait.rankedSub") })
		else
			hud:showWaiting()
		end
	elseif kind == "RankQueue" then
		hud:showWaiting({ title = S.t("wait.ranked"), sub = searchText(e.waited), bot = e.botOffer })
	elseif kind == "Teleporting" then
		hud:showWaiting({ title = S.t("wait.teleporting"), cancel = false })
	elseif kind == "RoomWaiting" then
		hud:showWaiting({ title = S.t("wait.room"), sub = S.t("wait.roomSub"), cancel = false })
	elseif kind == "RankDenied" then
		hud:showMenu()
		hud:setMenuNote(S.t(if e.reason == "banned" then "menu.banned" else "menu.rankedUnavailable"))
	elseif kind == "RankCancelled" then
		endMatchView()
		hud:showMenu()
		hud:setMenuNote(S.t(if e.reason == "noshow" then "menu.noShow" else "menu.teleportFailed"))
	elseif kind == "Profile" then
		hud:setProfile(e)
		bestRating = e.best or bestRating
		if e.arena and Arenas.get(e.arena) then
			selectedArena = e.arena
		end
		hud:setArenaButton(arenaButtonText())
		if e.pass then
			hud:setPassState(e.pass)
		end
		if not e.tutorialDone and hud.menuNote.Text == "" then
			hud:setMenuNote(S.t("menu.tryTutorial"), true)
		end
	elseif kind == "PassUpdate" then
		hud:setPassState(e.state)
		if e.gained and e.gained > 0 then
			local text = S.t("pass.xpGain", { xp = e.gained })
			if e.daily then
				text = S.t("pass.dailyBonus") .. "  " .. text
			end
			hud:announceAbility(text, Palette.Grade.Perfect)
		end
		if e.levelAfter and e.levelBefore and e.levelAfter > e.levelBefore then
			hud:popupText(S.t("pass.levelUp", { n = e.levelAfter }), Palette.Grade.Perfect)
		end
		local newItems = e.newItems or {}
		if #newItems > 0 then
			hud:setMenuNote(S.t("pass.newItem", { item = S.item(newItems[#newItems]) }), true)
		end
	elseif kind == "FeedbackResult" then
		hud:feedbackResult(e.status)
	elseif kind == "Tutorial" then
		showTutorial(e.step, e.left)
	elseif kind == "Leaderboard" then
		hud:showLeaderboard(e.scope, e.rows)
	elseif kind == "RankResult" then
		hud:setRankResult(e)
	elseif kind == "Start" then
		me = e.you
		mySide = e.side
		origin = e.origin
		cameraZ = 0
		myLoadout = e.loadout or {}
		myGauge, usedThisRally, nextSlot, inRally = 0, false, 1, false
		clearBarrier(1)
		clearBarrier(2)
		ball:setOrigin(e.origin)
		ball:hide()
		tutorialStep = nil
		opponentMode = e.opponentMode
		resultToken += 1
		Audio.music(Audio.matchTrack(e.arena, e.ranked))
		hud:showMatch(opponentLabel(e))
		hud:setControls(controlsText())
		-- arena look, wind, and both players' cosmetics
		ArenaLook.apply(e.arena)
		if e.arena == "Sakura" then
			City.show(nil)
			Garden.show(e.origin, e.side)
		else
			Garden.show(nil)
			City.show(e.origin, e.side)
		end
		windActive = e.wind == true
		local looks = e.looks or {}
		local function trailOf(look: any): Color3?
			local item = if look and look.trail ~= "" then Cosmetics.get(look.trail) else nil
			return if item and item.rgb then Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3]) else nil
		end
		ball:setTrails(trailOf(looks[1]), trailOf(looks[2]))
		local myLook, theirLook = looks[me], looks[them()]
		hud:setTitles(if myLook then myLook.title else "", if theirLook then theirLook.title else "", opponentLabel(e))
		hud:setSlots(myLoadout)
		refreshSlots()
		local theirs = e.opponentLoadout or {}
		if #theirs > 0 then
			local names = {}
			for _, id in theirs do
				table.insert(names, abilityName(id))
			end
			hud:announceAbility(S.t("ability.theirLoadout", { list = table.concat(names, " / ") }), Palette.TeamB)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = MATCH_FOV
		setJump(false)
	elseif kind == "Score" then
		hud:setScore(e, me)
		if origin and opponentMode ~= "Wall" and Audio.current() ~= nil and Audio.matchPoint(e.points) then
			Audio.music("final") -- stays on through a deuce
		end
		myGauge = e.gauge[me]
		nextSlot = if e.nextSlot then e.nextSlot[me] else nextSlot
		refreshSlots()
	elseif kind == "ServeWait" then
		serveHint(e.server)
	elseif kind == "Shot" then
		if e.update then
			ball:updateShot(e.shot)
		else
			ball:setShot(e.shot, now())
			hud:setHint("")
		end
		inRally = true
		refreshSlots()
	elseif kind == "Ability" then
		onAbilityEvent(e)
	elseif kind == "Swing" then
		if e.player == me then
			hud:popupGrade(e.grade, e.offset)
			if e.protected then
				hud:setHint(S.t("hint.protected"))
			end
			if e.grade ~= "Miss" then
				ball:hitEffect(e.grade)
				myGauge = e.gauge
				hud:setGauge(e.gauge)
				refreshSlots()
			end
		elseif e.grade ~= "Miss" then
			ball:hitEffect(e.grade)
		end
		if e.grade == "Perfect" then
			Fx.perfect(ball.folder, ball.ball.Position, Palette.Grade.Perfect)
		end
		if e.rally then
			hud:setRally(e.rally)
		end
	elseif kind == "Point" then
		ball:lose(now())
		inRally, usedThisRally = false, false
		clearBarrier(1)
		clearBarrier(2)
		refreshSlots()
		local mine = e.winner == me
		local reasonKey = "point." .. tostring(e.reason)
		hud:popupText(
			S.t(if mine then "point.you" elseif S.has(reasonKey) then reasonKey else "point.lost"),
			if mine then Palette.TeamA else Palette.Grade.Miss
		)
		hud:setRally(0)
	elseif kind == "Game" then
		hud:popupText(S.t(if e.winner == me then "game.won" else "game.lost"), Palette.Grade.Perfect)
	elseif kind == "MatchOver" then
		local note = if e.reason == "forfeit" and e.winner == me
			then S.t("result.forfeit")
			elseif e.reason == "idle" then S.t(if e.winner == me then "result.idleWin" else "result.idleLose")
			else nil
		ball:hide()
		local final = if e.points and Config.Score.gamesToWinMatch <= 1 then e.points else e.games
		-- the result jingle plays alone; the menu music comes back a little later
		Audio.music(nil)
		Audio.sfx(if e.winner == me then "Win" else "Lose")
		resultToken += 1
		local token = resultToken
		task.delay(4, function()
			if token == resultToken then
				Audio.music("menu")
			end
		end)
		hud:showResult(e.winner == me, final[me], final[them()], note)
	elseif kind == "Left" then
		clearBarrier(1)
		clearBarrier(2)
		tutorialStep = nil
		endMatchView()
		hud:showMenu()
	end
end
matchEvent.OnClientEvent:Connect(onEvent)

player.CharacterAdded:Connect(function()
	if origin then
		task.defer(setJump, false)
	end
end)

-- Round-trip time shown in the corner, including any debug delay set in Studio.
local pingClock = 0
RunService.Heartbeat:Connect(function(dt)
	pingClock += dt
	if pingClock < 1 or not origin then
		return
	end
	pingClock = 0
	local debugMs = ReplicatedStorage:GetAttribute(Net.DEBUG_LAG_ATTRIBUTE)
	local extra = if type(debugMs) == "number" then debugMs else 0
	hud:setPing(player:GetNetworkPing() * 1000 + extra)
end)

-- Aim marker: shows which way the next return will go while the ball is in play.
RunService.RenderStepped:Connect(function()
	-- phones aim with the parts of the HIT button, which show ◀ ▶ themselves
	if not origin or not inRally or UserInputService.TouchEnabled then
		hud:setAim(nil)
		return
	end
	hud:setAim(currentAim() * screenFlip())
end)

-- Roblox's own controls (WASD, the phone stick, the gamepad stick), looked up once. nil when the
-- player module is not there (tests).
local controls: any = nil
local function playerControls(): any
	if controls == nil then
		controls = false
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module and module:IsA("ModuleScript") then
			local ok, pm = pcall(require, module)
			if ok and type(pm) == "table" and pm.GetControls then
				controls = pm:GetControls()
			end
		end
	end
	return if controls then controls else nil
end

-- During a match the player only moves across the table (left/right on screen), never towards
-- or away from the net. Runs after Roblox's controls have set this frame's move, and replaces
-- it: the arrow keys, or the left/right part of whatever Roblox's controls asked for.
RunService:BindToRenderStep("SpinRiftArrowMove", Enum.RenderPriority.Input.Value + 1, function()
	if not origin then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local x = (if arrowRight then 1 else 0) - (if arrowLeft then 1 else 0) -- right on screen
	if x == 0 then
		local c = playerControls()
		if not c then
			return
		end
		local ok, v = pcall(function()
			return c:GetMoveVector() -- relative to the camera: X is right on screen
		end)
		x = if ok and v then v.X else 0
	end
	-- straight across the table (world Z); the camera may look a little diagonally, so its right
	-- vector is not used directly
	humanoid:Move(Vector3.new(0, 0, x * screenFlip()), false)
end)

-- Broadcast-style camera behind our own side, following us a little across the table.
RunService.RenderStepped:Connect(function(dt)
	ball:update(now(), dt)
	local o = origin
	if not o then
		return
	end
	local root = myRoot()
	local z = if root then root.Position.Z - o.Z else 0
	cameraZ += (z - cameraZ) * math.min(dt * 4, 1)
	local eye = o + Vector3.new(mySide * (Config.HitX + CAMERA_BACK), CAMERA_HEIGHT, cameraZ * 0.55)
	local focus = o + Vector3.new(-mySide * CAMERA_FOCUS, Config.Table.surfaceY, cameraZ * 0.25)
	local cf = CFrame.lookAt(eye, focus)
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local k = shake * 0.6
		cf *= CFrame.new(math.random() * k - k / 2, math.random() * k - k / 2, 0)
	end
	camera.CFrame = cf
	if windActive then
		-- arrows in the direction the wind pushes, as seen on screen
		local w = Arenas.windAt(now())
		local onScreen = w * (if camera.CFrame.RightVector:Dot(Vector3.zAxis) >= 0 then 1 else -1)
		local n = math.clamp(math.ceil(math.abs(w) / 0.3), 1, 3)
		local arrow = string.rep(if onScreen >= 0 then "▶" else "◀", n)
		hud:setWind(S.t("hud.wind", { arrow = if math.abs(w) < 0.08 then "・" else arrow }))
	end
end)

-- Ready: ask the server for our rank and anything else it needs to tell us.
helloRemote:FireServer()
