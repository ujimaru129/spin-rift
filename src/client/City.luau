--!strict
-- The cyberpunk city around the Neon Rooftop: towers, signs, elevated roads with traffic, embers.
-- Built once on each player's own screen (it is only scenery), then moved to wherever they play.
-- The open canyon of the city is along +X, where the player on side -1 looks; for the other side
-- the whole city is turned round. The same layout as the concept mock (tools/mock/city.py).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CityIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CityIds"))

local City = {}

local GROUND = -110
local CYAN = Color3.fromRGB(0, 200, 235)
local MAGENTA = Color3.fromRGB(235, 20, 165)
local PINK = Color3.fromRGB(240, 60, 115)
local BLUE = Color3.fromRGB(40, 90, 240)
local VIOLET = Color3.fromRGB(130, 50, 235)
local ORANGE = Color3.fromRGB(255, 130, 40)
local RED = Color3.fromRGB(255, 40, 50)
local WHITE = Color3.fromRGB(225, 235, 255)
local DARK = Color3.fromRGB(15, 16, 26)
local NEON = { CYAN, MAGENTA, BLUE, VIOLET, PINK }
local SIGNS = { "RIFT", "NOVA-9", "AFTERBURN", "PULSE", "HYPER", "ZERO-G", "ORBITAL", "ARC LIGHT", "VOLT", "QUANTUM" }
local WALLS = { Color3.fromRGB(17, 16, 25), Color3.fromRGB(12, 14, 28), Color3.fromRGB(10, 17, 27) }
local WINDOW_GLOW = 9 -- textures are lit like the wall they are on; this makes them shine at night
local SIGN_FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

local model: Model? = nil
local rng = Random.new(11)

local function r(lo: number, hi: number): number
	return rng:NextNumber(lo, hi)
end

local function pick<T>(list: { T }): T
	return list[math.floor(r(1, #list + 0.999))]
end

local function box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, color: Color3, neon: boolean?): Part
	return box(parent, CFrame.lookAt((a + b) / 2, b), Vector3.new(w, h, (b - a).Magnitude), color, neon)
end

-- Stands at (x, y, z) with its front towards the middle of the city.
local function facing(x: number, y: number, z: number): CFrame
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(0, y, 0))
end

-- A tower body with lit windows on the three faces that can be seen.
local function tower(parent: Instance, cf: CFrame, w: number, h: number, d: number)
	local kind = math.floor(r(1, 3.999))
	local body = box(parent, cf, Vector3.new(w, h, d), WALLS[kind])
	local id = CityIds.Windows[kind]
	if id == "" then
		for _ = 1, 8 do
			local at = cf * CFrame.new(r(-0.1, 0.1) * w, r(-0.45, 0.48) * h, -d / 2 - 0.1)
			box(parent, at, Vector3.new(w * r(0.3, 0.8), 0.5, 0.2), if kind == 1 then ORANGE else BLUE, true)
		end
		return
	end
	local tile = r(16, 22)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right } do
		local t = Instance.new("Texture")
		t.Texture = id
		t.Face = face
		t.StudsPerTileU = tile
		t.StudsPerTileV = tile * 1.5
		t.OffsetStudsU = r(0, tile)
		t.OffsetStudsV = r(0, tile)
		t.Color3 = Color3.new(WINDOW_GLOW, WINDOW_GLOW, WINDOW_GLOW)
		t.Parent = body
	end
end

local function sign(parent: Instance, cf: CFrame, w: number, h: number, color: Color3, label: string)
	local front = box(parent, cf, Vector3.new(w + 0.8, h + 0.8, 0.6), DARK)
	local edge = cf * CFrame.new(0, 0, -0.4)
	for _, s in { -1, 1 } do
		box(parent, edge * CFrame.new(0, s * h / 2, 0), Vector3.new(w, 0.35, 0.3), color, true)
		box(parent, edge * CFrame.new(s * w / 2, 0, 0), Vector3.new(0.35, h, 0.3), color, true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.86)
	text.BorderSizePixel = 0
	text.FontFace = SIGN_FONT
	text.TextColor3 = color:Lerp(WHITE, 0.45)
	text.TextScaled = true
	if h > w then
		-- one letter a line
		text.Text = table.concat(string.split(label, ""), "\n")
	else
		text.Text = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.08, 0)
		pad.PaddingRight = UDim.new(0.08, 0)
		pad.PaddingTop = UDim.new(0.14, 0)
		pad.PaddingBottom = UDim.new(0.14, 0)
		pad.Parent = text
	end
	text.Parent = gui
	gui.Parent = front
end

local function building(parent: Instance, x: number, z: number, w: number, d: number, top: number, near: boolean)
	local h = top - GROUND
	local mid = facing(x, (top + GROUND) / 2, z)
	local front = -d / 2
	tower(parent, mid, w, h, d)
	local function at(dx: number, y: number, dz: number): CFrame
		return mid * CFrame.new(dx, y - (top + GROUND) / 2, dz)
	end
	local color = pick(NEON)
	local roof = top
	if r(0, 1) < 0.55 then -- a narrower crown
		local h2 = h * r(0.12, 0.28)
		tower(parent, at(0, top + h2 / 2, 0), w * 0.66, h2, d * 0.66)
		box(parent, at(0, top + 0.3, front), Vector3.new(w + 0.6, 0.7, 0.6), color, true)
		roof += h2
	end
	if r(0, 1) < 0.45 then -- an antenna with a red lamp
		local ah = r(8, 28)
		box(parent, at(0, roof + ah / 2, 0), Vector3.new(0.6, ah, 0.6), DARK)
		box(parent, at(0, roof + ah, 0), Vector3.one, RED, true)
	end
	if r(0, 1) < 0.5 then -- a strip of light up one edge
		local lo = GROUND + h * r(0.3, 0.6)
		local s = if r(0, 1) < 0.5 then -1 else 1
		box(parent, at(s * w / 2, (lo + top) / 2, front), Vector3.new(0.6, top - lo, 0.6), color, true)
	end
	if r(0, 1) < 0.5 then
		local y = r(GROUND + h * 0.5, top - 4)
		box(parent, at(0, y, front), Vector3.new(w + 0.4, 0.45, 0.4), pick(NEON), true)
	end
	if near then
		for _ = 1, 3 do -- things on the roof
			local hh = r(1, 5)
			local size = Vector3.new(r(1.5, 5), hh, r(1.5, 5))
			box(parent, at(r(-0.4, 0.4) * w, roof + hh / 2, r(-0.3, 0.3) * d), size, DARK)
		end
		for _ = 1, 3 do -- lit ledges
			local y = r(top - h * 0.5, top - 3)
			box(parent, at(r(-0.4, 0.4) * w, y, front - 0.5), Vector3.new(r(1.5, 5), 0.3, 0.6), pick(NEON), true)
		end
		if r(0, 1) < 0.35 then
			local y = r(math.max(top - 40, -20), top - 10)
			if r(0, 1) < 0.5 then
				sign(parent, at(0, y, front - 0.5), w * 0.7, w * 0.32, pick(NEON), pick(SIGNS))
			else
				sign(parent, at(0, y - 6, front - 0.5), 5, 22, pick(NEON), pick({ "RIFT", "PULSE", "HYPER", "VOLT" }))
			end
		end
	end
end

type Path = { Vector3 }
local paths: { Path } = {}

local function spline(points: { Vector3 }, steps: number): Path
	local out: Path = {}
	local n = #points
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = points[math.max(i - 1, 1)], points[i], points[i + 1], points[math.min(i + 2, n)]
		for s = 0, steps - 1 do
			local t = s / steps
			local a = p1 * 2
			local b = (p2 - p0) * t
			local c = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (t * t)
			local d = (p1 * 3 - p0 - p2 * 3 + p3) * (t * t * t)
			table.insert(out, (a + b + c + d) * 0.5)
		end
	end
	table.insert(out, points[n])
	return out
end

-- An elevated road with glowing rails.
local function road(parent: Instance, points: { Vector3 }, w: number, color: Color3)
	local path = spline(points, 7)
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dir = (b - a).Unit
		local e = dir * 0.4
		local side = Vector3.new(-dir.Z, 0, dir.X).Unit * (w / 2)
		beam(parent, a - e, b + e, w, 1.2, Color3.fromRGB(16, 17, 27)).Reflectance = 0.12
		for _, s in { -1, 1 } do
			local o = side * s + Vector3.new(0, 1, 0)
			beam(parent, a + o - e, b + o + e, 0.4, 0.4, color, true)
		end
		if i % 4 == 0 then
			local h = a.Y - GROUND
			box(parent, CFrame.new(a - Vector3.new(0, h / 2, 0)), Vector3.new(2.4, h, 2.4), DARK)
		end
	end
	table.insert(paths, path)
end

-- A point `t` (0 to 1) of the way along a path, and the direction there.
local function along(path: Path, t: number): CFrame
	local f = t * (#path - 1)
	local i = math.min(math.floor(f) + 1, #path - 1)
	local a, b = path[i], path[i + 1]
	return CFrame.lookAt(a:Lerp(b, f - (i - 1)), b)
end

type Car = { part: Part, path: Path, t: number, speed: number, offset: Vector3 }
local cars: { Car } = {}

local function traffic(parent: Instance)
	for i = 1, 44 do
		local path = paths[(i % #paths) + 1]
		local onward = i % 2 == 0
		local color = if onward then pick({ RED, ORANGE }) else pick({ WHITE, CYAN })
		local lane = if onward then -2.4 else 2.4
		table.insert(cars, {
			part = box(parent, CFrame.new(0, GROUND, 0), Vector3.new(0.9, 0.5, r(3, 6)), color, true),
			path = path,
			t = r(0, 1),
			speed = (if onward then 1 else -1) * r(0.03, 0.06),
			offset = Vector3.new(lane, 1.1, 0),
		})
	end
	for i = 1, 14 do -- flying cars, high over the streets
		local x, y = r(90, 340), r(-20, 60)
		local z = r(120, 260)
		table.insert(cars, {
			part = box(
				parent,
				CFrame.new(0, GROUND, 0),
				Vector3.new(0.7, 0.5, 3),
				pick({ RED, WHITE, CYAN, ORANGE }),
				true
			),
			path = { Vector3.new(x, y, -z), Vector3.new(x + r(-40, 40), y, z) },
			t = r(0, 1),
			speed = (if i % 2 == 0 then 1 else -1) * r(0.03, 0.07),
			offset = Vector3.zero,
		})
	end
end

-- The signs that frame the table, and the sight lines to them that other towers must not block.
local BIG_SIGNS = {
	{ x = 112, y = 12, z = -70, w = 30, h = 14, color = MAGENTA, label = "RIFT CITY" },
	{ x = 120, y = 4, z = 78, w = 28, h = 12, color = CYAN, label = "SPIN DRIVE" },
	{ x = 84, y = 16, z = -88, w = 8, h = 38, color = CYAN, label = "PULSE" },
	{ x = 80, y = 14, z = 92, w = 8, h = 36, color = PINK, label = "SMASH" },
}
local EYE = Vector3.new(-28, 0, 0)

local function blocksSign(x: number, z: number): boolean
	local p = Vector3.new(x, 0, z)
	for _, s in BIG_SIGNS do
		local to = Vector3.new(s.x, 0, s.z)
		local line = to - EYE
		local t = math.clamp((p - EYE):Dot(line) / line:Dot(line), 0, 1.15)
		if (p - (EYE + line * t)).Magnitude < 30 then
			return true
		end
	end
	return false
end

local LAYERS = {
	{ n = 13, r0 = 105, r1 = 150, t0 = -34, t1 = 2, w0 = 16, w1 = 26 },
	{ n = 28, r0 = 165, r1 = 240, t0 = -22, t1 = 34, w0 = 18, w1 = 32 },
	{ n = 46, r0 = 260, r1 = 400, t0 = -5, t1 = 78, w0 = 24, w1 = 44 },
	{ n = 46, r0 = 430, r1 = 640, t0 = 10, t1 = 130, w0 = 36, w1 = 64 },
}

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "SpinRiftCity"
	local pivot = box(m, CFrame.new(0, 0, 0), Vector3.one, DARK)
	pivot.Transparency = 1
	m.PrimaryPart = pivot

	for layer, l in LAYERS do
		for i = 1, l.n do
			local a = (i + r(-0.35, 0.35)) / l.n * math.pi * 2
			local dist = r(l.r0, l.r1)
			local x, z = math.cos(a) * dist, math.sin(a) * dist
			local top = l.t0 + (l.t1 - l.t0) * r(0, 1) ^ 1.5
			if r(0, 1) < 0.12 then
				top = math.max(top, top * 1.5)
			end
			-- the canyon the camera looks down stays open, with taller blocks framing it
			local open = x > 0 and math.abs(z) < 40 and layer <= 2
			if x > 0 and math.abs(z) > dist * 0.62 and layer <= 2 then
				top += 26
			end
			if not open and not (layer <= 2 and blocksSign(x, z)) then
				building(m, x, z, r(l.w0, l.w1), r(l.w0, l.w1), top, layer <= 2)
			end
		end
	end

	-- two landmarks: a cross-braced tower and a spire with rings of light
	for _, k in
		{
			{ x = 235, z = 92, w = 46, top = 130, color = PINK },
			{ x = 500, z = -92, w = 46, top = 190, color = CYAN },
		}
	do
		tower(m, facing(k.x, (k.top + GROUND) / 2, k.z), k.w, k.top - GROUND, k.w)
		local f = facing(k.x, 0, k.z)
		local face = -k.w / 2 - 0.8
		for y = -60, k.top - 48, 48 do
			for _, s in { -1, 1 } do
				local p = (f * CFrame.new(-s * k.w / 2, y, face)).Position
				local q = (f * CFrame.new(s * k.w / 2, y + 48, face)).Position
				beam(m, p, q, 1.3, 1.3, k.color, true)
			end
		end
		for _, s in { -1, 1 } do
			box(
				m,
				f * CFrame.new(s * k.w / 2, (k.top - 60) / 2, face),
				Vector3.new(1.3, k.top + 60, 1.3),
				k.color,
				true
			)
			box(m, f * CFrame.new(s * k.w / 4, k.top + 28, 0), Vector3.new(1, 56, 1), DARK)
			box(m, f * CFrame.new(s * k.w / 4, k.top + 57, 0), Vector3.new(2, 2, 2), RED, true)
		end
		box(m, f * CFrame.new(0, k.top + 1, 0), Vector3.new(k.w + 2, 2, k.w + 2), k.color, true)
	end
	for i, y in { 80, 112, 144 } do
		local radius = 68 - i * 10
		for s = 1, 28 do
			local a0, a1 = s / 28 * math.pi * 2, (s + 1) / 28 * math.pi * 2
			local function on(a: number): Vector3
				return Vector3.new(500 + math.cos(a) * radius, y + math.sin(a) * 6, -92 + math.sin(a) * radius)
			end
			beam(m, on(a0), on(a1), 1.4, 1.4, if i == 2 then MAGENTA else CYAN, true)
		end
	end

	-- the big signs that frame the table
	for _, s in BIG_SIGNS do
		local cf = facing(s.x, s.y, s.z)
		local top = s.y + s.h / 2 + 6
		tower(m, facing(s.x, (top + GROUND) / 2, s.z) * CFrame.new(0, 0, 9), s.w + 8, top - GROUND, 16)
		box(m, facing(s.x, top, s.z) * CFrame.new(0, 0, 1), Vector3.new(s.w + 8.5, 0.5, 0.5), s.color, true)
		sign(m, cf, s.w, s.h, s.color, s.label)
	end

	local v = Vector3.new
	paths = {}
	cars = {}
	road(m, {
		v(560, -6, -20),
		v(420, -10, 0),
		v(250, -12, 14),
		v(150, -15, 6),
		v(95, -18, -26),
		v(60, -22, -62),
		v(0, -26, -86),
		v(-90, -30, -90),
	}, 15, CYAN)
	road(m, {
		v(420, -22, 150),
		v(260, -22, 96),
		v(150, -24, 40),
		v(92, -30, 16),
		v(62, -34, 34),
		v(44, -38, 70),
		v(0, -42, 104),
		v(-100, -46, 120),
	}, 13, ORANGE)
	road(
		m,
		{ v(220, 24, -260), v(190, 16, -140), v(176, 8, -60), v(190, 2, 20), v(230, 0, 110), v(300, 6, 260) },
		12,
		BLUE
	)
	road(m, { v(120, -48, -220), v(120, -48, -60), v(125, -48, 60), v(130, -48, 220) }, 16, MAGENTA)
	traffic(m)

	-- the night sky: a ring of tall panels, glowing purple near the skyline
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local at = Vector3.new(math.cos(a) * 700, 100, math.sin(a) * 700)
		local panel = box(m, CFrame.lookAt(at, Vector3.new(0, 100, 0)), v(190, 520, 1), Color3.new(0, 0, 0))
		panel.Name = "Sky"
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
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 7, 22)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(20, 16, 56)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(78, 30, 118)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 20, 80)),
		})
		gradient.Parent = fill
		fill.Parent = gui
		gui.Parent = panel
	end

	-- streets far below
	box(m, CFrame.new(150, GROUND - 1, 0), Vector3.new(1400, 1, 1400), Color3.fromRGB(8, 8, 18)).Reflectance = 0.1
	for i = 1, 60 do
		local long = r(30, 200)
		local size = if i % 2 == 0 then v(long, 0.4, 0.8) else v(0.8, 0.4, long)
		box(m, CFrame.new(r(-100, 560), GROUND, r(-400, 400)), size, if r(0, 1) < 0.3 then ORANGE else pick(NEON), true)
	end

	-- embers drifting up past the arena
	local air = box(m, CFrame.new(70, -20, 0), v(160, 1, 160), DARK)
	air.Transparency = 1
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(ORANGE)
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Size = NumberSequence.new(0.35)
	embers.Rate = 30
	embers.Lifetime = NumberRange.new(7, 12)
	embers.Speed = NumberRange.new(3, 7)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, 0.3, 0.6)
	embers.Parent = air
	return m
end

-- Shows the city around `origin` (nil hides it). side: which end of the table the player stands at.
function City.show(origin: Vector3?, side: number?)
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
	for _, c in cars do
		c.t = (c.t + c.speed * dt) % 1
		c.part.CFrame = base * along(c.path, c.t) * CFrame.new(c.offset)
	end
end)

return City
