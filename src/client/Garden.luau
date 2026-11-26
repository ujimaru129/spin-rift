--!strict
-- The scenery round Sakura Float: floating garden islands over a sea of clouds at dusk, a giant
-- cherry tree, torii gates, a pagoda, strings of lanterns, waterfalls, sky lanterns rising and
-- petals in the air. Built once on each player's own screen (it is only scenery), like City.
-- The camera of the player on side -1 looks along +X; for the other side it is turned round.

local RunService = game:GetService("RunService")

local Garden = {}

local CLOUD_Y = -75
local BLOSSOM = { Color3.fromRGB(255, 183, 213), Color3.fromRGB(255, 160, 200), Color3.fromRGB(250, 205, 226) }
local BLOSSOM_DEEP = Color3.fromRGB(236, 112, 168)
local BLOSSOM_GLOW = Color3.fromRGB(255, 120, 190)
local BARK = Color3.fromRGB(58, 38, 48)
local GRASS = Color3.fromRGB(96, 122, 104)
local MOSS = Color3.fromRGB(122, 140, 112)
local ROCK = { Color3.fromRGB(86, 72, 98), Color3.fromRGB(70, 60, 86), Color3.fromRGB(98, 82, 104) }
local VERMILION = Color3.fromRGB(214, 58, 46)
local TORII_TOP = Color3.fromRGB(34, 24, 30)
local LANTERN = Color3.fromRGB(255, 170, 90)
local LANTERN_RED = Color3.fromRGB(255, 86, 70)
local STONE = Color3.fromRGB(150, 142, 150)
local WATER = Color3.fromRGB(190, 225, 255)
local SUN = Color3.fromRGB(255, 196, 160)
local CLOUD = { Color3.fromRGB(246, 196, 214), Color3.fromRGB(226, 182, 222), Color3.fromRGB(255, 214, 200) }

local model: Model? = nil
local rng = Random.new(23)

type Floater = { part: BasePart, base: CFrame, speed: number, height: number, t: number, sway: number }
local floaters: { Floater } = {}

local function r(lo: number, hi: number): number
	return rng:NextNumber(lo, hi)
end

local function pick<T>(list: { T }): T
	return list[math.floor(r(1, #list + 0.999))]
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function part(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function ball(parent: Instance, at: Vector3, size: number, color: Color3, neon: boolean?): Part
	return part(
		parent,
		CFrame.new(at),
		Vector3.one * size,
		color,
		if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
end

-- A flat disc (cylinder standing up), radius rad, thickness h, centred at `at`.
local function disc(
	parent: Instance,
	at: Vector3,
	rad: number,
	h: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(
		parent,
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		v(h, rad * 2, rad * 2),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, color: Color3, neon: boolean?): Part
	return part(
		parent,
		CFrame.lookAt((a + b) / 2, b),
		v(w, w, (b - a).Magnitude),
		color,
		if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
end

local function glow(p: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = p
end

-- A cherry tree: a leaning trunk with a few branches, under a cloud of blossom.
local function tree(parent: Instance, at: Vector3, s: number, glowing: boolean?)
	local lean = v(r(-0.25, 0.25), 1, r(-0.25, 0.25)).Unit
	local top = at + lean * 9 * s
	beam(parent, at - v(0, 1, 0), top, 1.4 * s, BARK)
	local crowns: { Vector3 } = { top + v(0, 2.5 * s, 0) }
	for _ = 1, 3 do
		local dir = v(r(-1, 1), r(0.35, 0.8), r(-1, 1)).Unit
		local tip = top + dir * r(5, 7.5) * s
		beam(parent, top, tip, 0.7 * s, BARK)
		table.insert(crowns, tip)
	end
	for _, c in crowns do
		for _ = 1, 3 do
			local at2 = c + v(r(-2.5, 2.5), r(-1, 2), r(-2.5, 2.5)) * s
			ball(parent, at2, r(4.5, 7) * s, pick(BLOSSOM))
		end
		-- a darker heart and a few glowing clusters give the crown some depth at dusk
		ball(parent, c - v(0, 1.2 * s, 0), 4.5 * s, BLOSSOM_DEEP)
		if glowing or r(0, 1) < 0.35 then
			ball(parent, c + v(r(-2, 2), r(-1, 1.5), r(-2, 2)) * s, 2.2 * s, BLOSSOM_GLOW, true)
		end
	end
end

-- A stone lantern (tōrō) with a warm light.
local function stoneLantern(parent: Instance, at: Vector3, s: number)
	part(parent, CFrame.new(at + v(0, 0.6, 0) * s), v(1.6, 1.2, 1.6) * s, STONE, Enum.Material.Slate)
	part(parent, CFrame.new(at + v(0, 2.2, 0) * s), v(0.7, 2, 0.7) * s, STONE, Enum.Material.Slate)
	local light = part(parent, CFrame.new(at + v(0, 3.8, 0) * s), v(1.3, 1.2, 1.3) * s, LANTERN, Enum.Material.Neon)
	glow(light, LANTERN, 10 * s, 1.5)
	part(parent, CFrame.new(at + v(0, 4.8, 0) * s), v(2.4, 0.6, 2.4) * s, STONE, Enum.Material.Slate)
end

-- A torii gate facing along `facingDir`, standing at `at`, `h` tall.
local function torii(parent: Instance, at: Vector3, facingDir: Vector3, h: number)
	local cf = CFrame.lookAt(at, at + facingDir)
	local w = h * 1.1
	for _, side in { -1, 1 } do
		part(parent, cf * CFrame.new(side * w / 2, h / 2, 0), v(h * 0.09, h, h * 0.09), VERMILION)
		part(parent, cf * CFrame.new(side * w / 2, h * 0.04, 0), v(h * 0.13, h * 0.08, h * 0.13), TORII_TOP)
	end
	part(parent, cf * CFrame.new(0, h * 0.78, 0), v(w * 1.05, h * 0.07, h * 0.07), VERMILION) -- nuki
	part(parent, cf * CFrame.new(0, h * 0.95, 0), v(w * 1.35, h * 0.08, h * 0.12), VERMILION) -- kasagi
	part(parent, cf * CFrame.new(0, h * 1.02, 0), v(w * 1.45, h * 0.06, h * 0.14), TORII_TOP)
	part(parent, cf * CFrame.new(0, h * 0.86, 0), v(h * 0.06, h * 0.16, h * 0.06), VERMILION) -- gakuzuka
	-- a thin glowing edge under the top beam
	part(parent, cf * CFrame.new(0, h * 0.905, 0), v(w * 1.3, h * 0.012, h * 0.13), BLOSSOM_GLOW, Enum.Material.Neon)
end

-- A five-storey pagoda with lit windows.
local function pagoda(parent: Instance, at: Vector3, s: number)
	local y = 0
	for tier = 1, 5 do
		local w = (9 - tier * 1.1) * s
		local h = 4.2 * s
		part(parent, CFrame.new(at + v(0, y + h / 2, 0)), v(w, h, w), Color3.fromRGB(120, 40, 44))
		for _, f in { 1, -1 } do
			part(
				parent,
				CFrame.new(at + v(f * (w / 2 + 0.05), y + h * 0.5, 0)),
				v(0.1, h * 0.35, w * 0.6),
				LANTERN,
				Enum.Material.Neon
			)
		end
		part(parent, CFrame.new(at + v(0, y + h + 0.4 * s, 0)), v(w * 1.55, 0.8 * s, w * 1.55), TORII_TOP)
		part(parent, CFrame.new(at + v(0, y + h + 1 * s, 0)), v(w * 1.1, 0.6 * s, w * 1.1), TORII_TOP)
		y += h + 1.3 * s
	end
	part(
		parent,
		CFrame.new(at + v(0, y + 4 * s, 0)),
		v(0.5, 8, 0.5) * s,
		Color3.fromRGB(190, 150, 90),
		Enum.Material.Metal
	)
end

-- A floating island: a grassy top over a rocky underside that narrows to a point.
local function island(parent: Instance, at: Vector3, rad: number): Vector3
	disc(parent, at, rad, 1.6, GRASS, Enum.Material.Grass)
	disc(parent, at + v(0, 0.3, 0), rad * 0.75, 1.4, MOSS, Enum.Material.Grass)
	local y = -1.5
	local width = rad * 0.98
	for i = 1, 4 do
		local h = rad * (0.45 + i * 0.12)
		local rock = part(
			parent,
			CFrame.new(at + v(r(-0.1, 0.1) * rad, y - h / 2, r(-0.1, 0.1) * rad)) * CFrame.Angles(0, r(0, 6), 0),
			v(width * 1.6, h, width * 1.6),
			pick(ROCK),
			Enum.Material.Rock
		)
		rock.Shape = if i == 4 then Enum.PartType.Ball else Enum.PartType.Block
		if i == 4 then
			rock.Size = Vector3.one * width * 1.5
		end
		y -= h * 0.8
		width *= 0.62
	end
	return at + v(0, 0.9, 0)
end

local function waterfall(parent: Instance, from: Vector3, length: number)
	local fall = part(parent, CFrame.new(from - v(0, length / 2, 0)), v(2.4, length, 0.6), WATER, Enum.Material.Neon)
	fall.Transparency = 0.45
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(WATER)
	mist.LightEmission = 0.5
	mist.Size = NumberSequence.new(2, 5)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Rate = 6
	mist.Lifetime = NumberRange.new(2, 4)
	mist.Speed = NumberRange.new(1, 2)
	mist.EmissionDirection = Enum.NormalId.Bottom
	mist.Parent = fall
end

-- A string of paper lanterns sagging between two points.
local function lanternString(parent: Instance, a: Vector3, b: Vector3, count: number)
	local sag = (b - a).Magnitude * 0.12
	local last = a
	for i = 1, count do
		local t = i / (count + 1)
		local p = a:Lerp(b, t) - v(0, math.sin(t * math.pi) * sag, 0)
		beam(parent, last, p, 0.12, TORII_TOP)
		local lamp = part(
			parent,
			CFrame.new(p - v(0, 0.9, 0)),
			v(1.4, 1.1, 1.4),
			if i % 3 == 0 then LANTERN_RED else LANTERN,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		lamp.CFrame = CFrame.new(p - v(0, 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		if i % 3 == 1 then
			glow(lamp, LANTERN, 9, 1)
		end
		last = p
	end
	beam(parent, last, b, 0.12, TORII_TOP)
end

-- Keeps the view down the table clear: the opponent and the ball are seen against open sky.
local function inView(x: number, z: number): boolean
	return x > 8 and math.abs(z) < 18 + x * 0.32
end

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "SakuraGarden"
	local pivot = part(m, CFrame.new(0, 0, 0), Vector3.one, BARK)
	pivot.Transparency = 1
	m.PrimaryPart = pivot

	-- the sunset sky: a ring of tall panels, glowing peach towards the sun (+X) and violet behind
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local at = v(math.cos(a) * 700, 100, math.sin(a) * 700)
		local panel = part(m, CFrame.lookAt(at, v(0, 100, 0)), v(190, 520, 1), Color3.new(0, 0, 0))
		panel.Name = "Sky"
		local warm = (math.cos(a) + 1) / 2 -- 1 facing the sun, 0 behind us
		local function mix(cool: Color3, hot: Color3): Color3
			return cool:Lerp(hot, warm)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.MaxDistance = 0
		gui.CanvasSize = Vector2.new(64, 256)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		-- the horizon is about 0.69 down the panel (eye height); the view spans roughly 0.2 to 1
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, mix(Color3.fromRGB(30, 22, 70), Color3.fromRGB(50, 34, 100))),
			ColorSequenceKeypoint.new(0.4, mix(Color3.fromRGB(90, 48, 130), Color3.fromRGB(140, 60, 150))),
			ColorSequenceKeypoint.new(0.56, mix(Color3.fromRGB(170, 80, 160), Color3.fromRGB(235, 100, 155))),
			ColorSequenceKeypoint.new(0.66, mix(Color3.fromRGB(230, 130, 170), Color3.fromRGB(255, 165, 140))),
			ColorSequenceKeypoint.new(0.7, mix(Color3.fromRGB(245, 170, 180), Color3.fromRGB(255, 210, 160))),
			ColorSequenceKeypoint.new(0.76, mix(Color3.fromRGB(210, 130, 170), Color3.fromRGB(240, 150, 165))),
			ColorSequenceKeypoint.new(1, mix(Color3.fromRGB(120, 80, 140), Color3.fromRGB(170, 100, 150))),
		})
		gradient.Parent = fill
		fill.Parent = gui
		gui.Parent = panel
	end

	-- the low sun and its halo, far beyond the opponent
	local sun = ball(m, v(620, 95, 110), 70, SUN, true)
	glow(sun, SUN, 60, 1)
	ball(m, v(630, 95, 112), 120, Color3.fromRGB(255, 170, 170), true).Transparency = 0.75
	ball(m, v(640, 95, 114), 190, Color3.fromRGB(255, 150, 190), true).Transparency = 0.88

	-- a sea of clouds below, warmer towards the sun
	for _ = 1, 70 do
		local x, z = r(-350, 700), r(-600, 600)
		local c = part(
			m,
			CFrame.new(x, CLOUD_Y + r(-8, 6), z) * CFrame.Angles(0, r(0, 6), 0),
			v(r(70, 150), r(10, 20), r(50, 110)),
			if x > 250 then CLOUD[3] else pick(CLOUD),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		c.Transparency = r(0.05, 0.3)
	end
	-- a few tall clouds on the horizon
	for _ = 1, 10 do
		local z = r(-450, 450)
		local c = ball(m, v(r(450, 650), CLOUD_Y + r(20, 50), z), r(80, 140), CLOUD[3])
		c.Size = v(r(120, 200), r(60, 110), r(90, 150))
		c.Transparency = 0.35
	end

	-- the giant tree, on its own island behind and left of the opponent
	local hero = island(m, v(165, -22, -70), 34)
	beam(m, hero - v(0, 2, 0), hero + v(4, 34, 6), 9, BARK)
	local crownAt = hero + v(4, 38, 6)
	for _ = 1, 4 do
		local dir = v(r(-1, 1), r(0.2, 0.6), r(-1, 1)).Unit
		beam(m, hero + v(4, 26, 6), hero + v(4, 26, 6) + dir * r(18, 26), 3.5, BARK)
	end
	for _ = 1, 34 do
		local off = v(r(-30, 30), r(-10, 16), r(-30, 30))
		ball(m, crownAt + off, r(14, 22), pick(BLOSSOM))
	end
	for _ = 1, 8 do
		ball(m, crownAt + v(r(-24, 24), r(-12, 6), r(-24, 24)), r(6, 10), BLOSSOM_GLOW, true)
	end
	ball(m, crownAt - v(0, 4, 0), 30, BLOSSOM_DEEP)
	for _ = 1, 4 do
		stoneLantern(m, hero + v(r(-24, 24), 0, r(-24, 24)), 2)
	end
	waterfall(m, hero + v(-30, -1, 10), 70)

	-- a pagoda on a high island to the right
	local high = island(m, v(240, 6, 120), 22)
	pagoda(m, high, 1.6)
	tree(m, high + v(-12, 0, -10), 1.3)
	stoneLantern(m, high + v(10, 0, -12), 1.5)
	waterfall(m, high + v(18, -1, -8), 60)

	-- a big torii on a near island to the left, framing the view
	local gate = island(m, v(48, -6, -58), 16)
	torii(m, gate, v(-1, 0, 0.25), 22)
	tree(m, gate + v(8, 0, -8), 1.1)
	stoneLantern(m, gate + v(-6, 0, 8), 1.2)

	-- a smaller torii on the right
	local gate2 = island(m, v(70, -14, 66), 13)
	torii(m, gate2, v(-1, 0, -0.4), 15)
	tree(m, gate2 + v(6, 0, 6), 0.9, true)

	-- more islands in rings round the arena, with trees and lanterns
	local placed: { Vector3 } = { hero, high, gate, gate2 }
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2 + r(-0.12, 0.12)
		local dist = r(55, 240)
		local x, z = math.cos(a) * dist, math.sin(a) * dist
		local rad = r(7, 16) * (0.6 + dist / 300)
		local y = r(-34, 14)
		local ok = not inView(x, z)
		for _, p in placed do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(x, 0, z)).Magnitude < rad + 24 then
				ok = false
			end
		end
		if ok then
			local top = island(m, v(x, y, z), rad)
			table.insert(placed, top)
			for _ = 1, math.floor(r(1, 3.4)) do
				tree(m, top + v(r(-0.5, 0.5) * rad, 0, r(-0.5, 0.5) * rad), r(0.8, 1.4) * (0.7 + dist / 400))
			end
			if r(0, 1) < 0.5 then
				stoneLantern(m, top + v(r(-0.5, 0.5) * rad, 0, r(-0.5, 0.5) * rad), 1)
			end
			if r(0, 1) < 0.2 then
				waterfall(m, top + v(rad * 0.8, -1, 0), r(30, 60))
			end
		end
	end

	-- strings of lanterns between neighbouring islands
	local strung = 0
	for i = 1, #placed do
		for j = i + 1, #placed do
			local a, b = placed[i], placed[j]
			local d = (a - b).Magnitude
			if strung < 9 and d > 30 and d < 90 then
				lanternString(m, a + v(0, 7, 0), b + v(0, 7, 0), math.floor(d / 6))
				strung += 1
			end
		end
	end

	-- sky lanterns rising slowly all round (moved each frame, see Heartbeat below)
	for _ = 1, 36 do
		local x, z = r(-160, 320), r(-260, 260)
		if not inView(x, z) then
			local lamp = part(m, CFrame.new(x, 0, z), v(1.6, 2, 1.6), LANTERN, Enum.Material.Neon)
			table.insert(floaters, {
				part = lamp,
				base = CFrame.new(x, CLOUD_Y + 10, z),
				speed = r(1.2, 2.6),
				height = r(120, 170),
				t = r(0, 1),
				sway = r(0, 6),
			})
		end
	end

	-- petals drifting over the table and fireflies of light
	local air = part(m, CFrame.new(40, 34, 0), v(140, 1, 120), BARK)
	air.Transparency = 1
	local petals = Instance.new("ParticleEmitter")
	petals.Color = ColorSequence.new(BLOSSOM[1], BLOSSOM[3])
	petals.LightEmission = 0.25
	petals.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.25) })
	petals.Rate = 45
	petals.Lifetime = NumberRange.new(9, 13)
	petals.Speed = NumberRange.new(2, 4)
	petals.SpreadAngle = Vector2.new(40, 40)
	petals.Acceleration = Vector3.new(1.4, -1.3, 0.4)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-120, 120)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Parent = air
	local motes = part(m, CFrame.new(60, -10, 0), v(200, 1, 200), BARK)
	motes.Transparency = 1
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fireflies.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150))
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Size = NumberSequence.new(0.4)
	fireflies.Rate = 14
	fireflies.Lifetime = NumberRange.new(8, 12)
	fireflies.Speed = NumberRange.new(1, 3)
	fireflies.Acceleration = Vector3.new(0, 0.4, 0)
	fireflies.Parent = motes
	return m
end

-- Shows the garden around `origin` (nil hides it). side: which end of the table the player stands at.
function Garden.show(origin: Vector3?, side: number?)
	local m = model
	if not origin then
		if m then
			m.Parent = nil
		end
		return
	end
	if not m then
		m = build()
		model = m
	end
	local turn = if side == 1 then math.pi else 0
	(m :: Model):PivotTo(CFrame.new(origin) * CFrame.Angles(0, turn, 0));
	(m :: Model).Parent = workspace
end

RunService.Heartbeat:Connect(function(dt: number)
	local m = model
	if not m or not m.Parent or not m.PrimaryPart then
		return
	end
	local base = m.PrimaryPart.CFrame
	for _, f in floaters do
		f.t = (f.t + f.speed * dt / f.height) % 1
		local y = f.t * f.height
		local x = math.sin(f.t * 6 + f.sway) * 2
		f.part.CFrame = base * f.base * CFrame.new(x, y, 0) * CFrame.Angles(0, f.t * 4, 0)
	end
end)

return Garden
