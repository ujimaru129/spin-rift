--!strict
-- The scenery round Aquarium Dome: a glass dome on the sea floor. Coral reefs, kelp, rock arches
-- and a sunken lighthouse outside; schools of fish, jellyfish and a whale swimming past; light
-- falling from the surface and bubbles rising. Built once on each player's own screen (it is
-- only scenery), like City and Garden. The camera of the player on side -1 looks along +X; for
-- the other side it is turned round.

local RunService = game:GetService("RunService")

local Aquarium = {}

local FLOOR_Y = -30
local SAND = { Color3.fromRGB(196, 178, 140), Color3.fromRGB(176, 160, 128), Color3.fromRGB(210, 192, 150) }
local ROCK = { Color3.fromRGB(70, 84, 104), Color3.fromRGB(58, 70, 92), Color3.fromRGB(84, 96, 112) }
local CORAL = {
	Color3.fromRGB(255, 110, 130),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 220, 110),
	Color3.fromRGB(90, 230, 210),
}
local KELP = { Color3.fromRGB(60, 140, 90), Color3.fromRGB(80, 160, 90), Color3.fromRGB(50, 120, 100) }
local FISH = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 120, 90),
	Color3.fromRGB(240, 240, 255),
	Color3.fromRGB(150, 255, 170),
}
local DOME = Color3.fromRGB(120, 220, 255)
local JELLY = { Color3.fromRGB(255, 140, 230), Color3.fromRGB(150, 170, 255), Color3.fromRGB(120, 255, 230) }
local WHALE = Color3.fromRGB(64, 86, 120)
local WHALE_BELLY = Color3.fromRGB(170, 190, 210)
local RAY = Color3.fromRGB(170, 230, 255)

local model: Model? = nil
local rng = Random.new(41)

-- Things that move: each turns round a centre (fish schools, the whale) or bobs (jellyfish).
type Swimmer = {
	part: BasePart,
	centre: Vector3,
	radius: number,
	height: number,
	speed: number, -- radians per second (negative = the other way round)
	phase: number,
	bob: number, -- up-and-down amount
	offset: CFrame, -- the part's place inside its school
}
local swimmers: { Swimmer } = {}
local clock = 0

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

local function ball(parent: Instance, at: Vector3, size: Vector3, color: Color3, material: Enum.Material?): Part
	return part(parent, CFrame.new(at), size, color, material, Enum.PartType.Ball)
end

local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, color: Color3, material: Enum.Material?): Part
	return part(parent, CFrame.lookAt((a + b) / 2, b), v(w, w, (b - a).Magnitude), color, material)
end

local function glow(p: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = p
end

-- Keeps the view down the table clear: the opponent and the ball are seen against open water.
local function inView(x: number, z: number): boolean
	return x > 8 and math.abs(z) < 18 + x * 0.32
end

-- A coral head: a few round and branching pieces in bright colours.
local function coral(parent: Instance, at: Vector3, s: number)
	local c = pick(CORAL)
	for _ = 1, 3 do
		ball(parent, at + v(r(-2, 2), r(0, 2), r(-2, 2)) * s, v(r(3, 5), r(2, 4), r(3, 5)) * s, c)
	end
	for _ = 1, 4 do
		local base = at + v(r(-2, 2), 0, r(-2, 2)) * s
		local top = base + v(r(-2, 2), r(4, 8), r(-2, 2)) * s
		beam(parent, base, top, 0.9 * s, pick(CORAL), Enum.Material.Neon)
		ball(parent, top, v(1.6, 1.6, 1.6) * s, c, Enum.Material.Neon)
	end
end

-- A strand of kelp: a slightly bending column of leaves.
local function kelp(parent: Instance, at: Vector3, h: number)
	local color = pick(KELP)
	local last = at
	local bend = v(r(-1, 1), 0, r(-1, 1))
	for i = 1, 5 do
		local nxt = at + v(0, h * i / 5, 0) + bend * math.sin(i * 0.8) * 2
		beam(parent, last, nxt, 1.2, color)
		last = nxt
	end
end

local function rock(parent: Instance, at: Vector3, s: number): Vector3
	for _ = 1, 4 do
		ball(parent, at + v(r(-1, 1), r(0, 0.6), r(-1, 1)) * s, v(r(1.2, 2), r(0.8, 1.4), r(1.2, 2)) * s, pick(ROCK))
	end
	return at + v(0, s * 0.7, 0)
end

-- A school of small fish going round a centre.
local function school(parent: Instance, centre: Vector3, radius: number, count: number, speed: number)
	local color = pick(FISH)
	local phase = r(0, math.pi * 2)
	for _ = 1, count do
		local body = part(parent, CFrame.new(), v(0.9, 0.9, 2.2), color, Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(swimmers, {
			part = body,
			centre = centre,
			radius = radius,
			height = centre.Y,
			speed = speed,
			phase = phase,
			bob = 1.5,
			offset = CFrame.new(r(-5, 5), r(-3, 3), r(-5, 5)),
		})
	end
end

local function jellyfish(parent: Instance, at: Vector3, s: number)
	local color = pick(JELLY)
	local bell = part(parent, CFrame.new(), v(4, 3, 4) * s, color, Enum.Material.Neon, Enum.PartType.Ball)
	bell.Transparency = 0.35
	glow(bell, color, 14, 0.8)
	table.insert(swimmers, {
		part = bell,
		centre = at,
		radius = r(1, 3),
		height = at.Y,
		speed = r(0.1, 0.25),
		phase = r(0, math.pi * 2),
		bob = 3,
		offset = CFrame.new(),
	})
	for k = 1, 4 do
		local tentacle = part(parent, CFrame.new(), v(0.25, 4.5, 0.25) * s, color, Enum.Material.Neon)
		tentacle.Transparency = 0.5
		table.insert(swimmers, {
			part = tentacle,
			centre = at,
			radius = r(1, 3),
			height = at.Y,
			speed = 0,
			phase = 0,
			bob = 3,
			offset = CFrame.new(math.cos(k * 1.57) * 1.2 * s, -3.2 * s, math.sin(k * 1.57) * 1.2 * s),
		})
	end
	-- tentacles follow their bell: they share its centre and motion
	local n = #swimmers
	for k = n - 3, n do
		swimmers[k].speed = swimmers[n - 4].speed
		swimmers[k].phase = swimmers[n - 4].phase
		swimmers[k].radius = swimmers[n - 4].radius
	end
end

local function whale(parent: Instance, centre: Vector3, radius: number)
	local phase = r(0, math.pi * 2)
	local function piece(offset: CFrame, size: Vector3, color: Color3)
		local p = part(parent, CFrame.new(), size, color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		table.insert(swimmers, {
			part = p,
			centre = centre,
			radius = radius,
			height = centre.Y,
			speed = 0.035,
			phase = phase,
			bob = 4,
			offset = offset,
		})
	end
	piece(CFrame.new(), v(18, 14, 46), WHALE)
	piece(CFrame.new(0, -3, -4), v(15, 9, 34), WHALE_BELLY)
	piece(CFrame.new(0, 0, 26), v(8, 5, 16), WHALE) -- tail stock
	piece(CFrame.new(0, 0, 34) * CFrame.Angles(0, 0, math.pi / 2), v(2, 22, 7), WHALE) -- flukes
	piece(CFrame.new(9, -4, -6) * CFrame.Angles(0, 0, -0.6), v(2, 12, 6), WHALE) -- fins
	piece(CFrame.new(-9, -4, -6) * CFrame.Angles(0, 0, 0.6), v(2, 12, 6), WHALE)
end

-- Where a swimmer is at time t, inside the model.
local function place(s: Swimmer, t: number): CFrame
	local a = s.phase + s.speed * t
	local pos = s.centre
		+ Vector3.new(math.cos(a) * s.radius, math.sin(t * 0.7 + s.phase) * s.bob, math.sin(a) * s.radius)
	local heading = if s.speed >= 0 then a + math.pi / 2 else a - math.pi / 2
	local ahead = pos + Vector3.new(math.cos(heading), 0, math.sin(heading))
	return CFrame.lookAt(pos, ahead) * s.offset
end

local function build(): Model
	local m = Instance.new("Model")
	m.Name = "AquariumDome"
	local pivot = part(m, CFrame.new(0, 0, 0), Vector3.one, ROCK[1])
	pivot.Transparency = 1
	m.PrimaryPart = pivot
	table.clear(swimmers)

	-- the sea floor, dunes and the glow of the surface far above
	part(m, CFrame.new(0, FLOOR_Y - 2, 0), v(1400, 4, 1400), SAND[1])
	for _ = 1, 40 do
		local a, d = r(0, math.pi * 2), r(60, 600)
		ball(m, v(math.cos(a) * d, FLOOR_Y - 4, math.sin(a) * d), v(r(40, 90), r(6, 14), r(40, 90)), pick(SAND))
	end
	local surface = part(m, CFrame.new(0, 260, 0), v(1600, 2, 1600), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	surface.Transparency = 0.55

	-- the dome: glowing ribs high over the arena (wide enough that none cross the view of the
	-- opponent) and a ring round its foot
	local DOME_R = 110
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local last = v(math.cos(a) * DOME_R, FLOOR_Y, math.sin(a) * DOME_R)
		for k = 1, 8 do
			local up = k / 8 * math.pi / 2
			local nxt = v(
				math.cos(a) * math.cos(up) * DOME_R,
				FLOOR_Y + math.sin(up) * DOME_R,
				math.sin(a) * math.cos(up) * DOME_R
			)
			beam(m, last, nxt, 0.5, DOME, Enum.Material.Neon).Transparency = 0.35
			last = nxt
		end
	end
	for _, h in { 0.25, 0.55 } do
		local y = FLOOR_Y + math.sin(h * math.pi / 2) * DOME_R
		local rad = math.cos(h * math.pi / 2) * DOME_R
		local last: Vector3? = nil
		for i = 0, 32 do
			local a = i / 32 * math.pi * 2
			local p = v(math.cos(a) * rad, y, math.sin(a) * rad)
			if last then
				beam(m, last, p, 0.35, DOME, Enum.Material.Neon).Transparency = 0.5
			end
			last = p
		end
	end
	local foot = part(
		m,
		CFrame.new(0, FLOOR_Y + 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		v(1.5, DOME_R * 2 + 4, DOME_R * 2 + 4),
		ROCK[2],
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	foot.Transparency = 0
	-- the arena stands on a coral-crusted column
	part(
		m,
		CFrame.new(0, (FLOOR_Y - 1) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		v(-FLOOR_Y, 22, 22),
		ROCK[3],
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)

	-- light falling from the surface
	for _ = 1, 18 do
		local x, z = r(-300, 400), r(-300, 300)
		if math.abs(z) > 70 or x > 250 then
			local top = v(x, 250, z)
			local bottom = v(x + r(20, 50), FLOOR_Y, z + r(-20, 20))
			local ray = beam(m, top, bottom, r(10, 24), RAY, Enum.Material.Neon)
			ray.Transparency = 0.9
		end
	end

	-- reefs, kelp and rocks outside the dome (never in the view down the table)
	local placed = 0
	while placed < 70 do
		local a, d = r(0, math.pi * 2), r(DOME_R + 8, 420)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if not inView(x, z) or d > 260 then
			placed += 1
			local s = 0.8 + d / 260
			local top = rock(m, v(x, FLOOR_Y, z), r(4, 9) * s)
			if r(0, 1) < 0.7 then
				coral(m, top, s)
			end
			for _ = 1, math.floor(r(0, 4)) do
				kelp(m, v(x + r(-12, 12), FLOOR_Y, z + r(-12, 12)), r(20, 50) * s)
			end
		end
	end
	-- a kelp forest along both sides of the view
	for _ = 1, 60 do
		local x = r(20, 380)
		local z = (18 + x * 0.32 + r(6, 50)) * (if r(0, 1) < 0.5 then -1 else 1)
		kelp(m, v(x, FLOOR_Y, z), r(30, 70))
	end
	-- two rock arches framing the far end of the view
	for _, sz in { -1, 1 } do
		local base = v(220, FLOOR_Y, sz * 120)
		local top = base + v(30, 90, -sz * 40)
		beam(m, base, top, 16, ROCK[1])
		beam(m, top, base + v(80, 0, -sz * 30), 14, ROCK[3])
		coral(m, top, 2)
	end
	-- a sunken lighthouse, its lamp still lit, behind the opponent on the left
	local tower = v(300, FLOOR_Y, -150)
	for i = 0, 5 do
		local band = part(
			m,
			CFrame.new(tower + v(0, 6 + i * 12, 0)) * CFrame.Angles(0.06 * i, 0, 0.1),
			v(12 - i, 12, 12 - i),
			if i % 2 == 0 then Color3.fromRGB(230, 230, 235) else Color3.fromRGB(210, 70, 70)
		)
		band.Shape = Enum.PartType.Block
	end
	local lamp = ball(m, tower + v(8, 80, 0), v(7, 7, 7), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	glow(lamp, Color3.fromRGB(255, 230, 160), 60, 2)
	beam(m, lamp.Position, lamp.Position + v(-60, -20, 140), 6, Color3.fromRGB(255, 240, 190), Enum.Material.Neon).Transparency =
		0.85

	-- life: schools of fish, jellyfish near the dome, a whale far out
	for _ = 1, 9 do
		local a, d = r(0, math.pi * 2), r(DOME_R + 20, 220)
		school(m, v(math.cos(a) * d, r(-10, 60), math.sin(a) * d), r(20, 50), 12, r(0.15, 0.35) * pick({ -1, 1 }))
	end
	for _ = 1, 10 do
		local a, d = r(0, math.pi * 2), r(DOME_R + 6, DOME_R + 60)
		local x, z = math.cos(a) * d, math.sin(a) * d
		if not inView(x, z) then
			jellyfish(m, v(x, r(10, 50), z), r(0.8, 1.6))
		end
	end
	whale(m, v(330, 90, 0), 170)

	-- bubbles rising round the arena
	local floorArea = part(m, CFrame.new(40, FLOOR_Y, 0), v(260, 1, 220), ROCK[1])
	floorArea.Transparency = 1
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.LightEmission = 0.4
	bubbles.Transparency = NumberSequence.new(0.3)
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.6) })
	bubbles.Rate = 40
	bubbles.Lifetime = NumberRange.new(8, 12)
	bubbles.Speed = NumberRange.new(5, 9)
	bubbles.SpreadAngle = Vector2.new(10, 10)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Parent = floorArea
	-- everything that swims starts where it belongs (not at the centre until the first frame)
	for _, s in swimmers do
		s.part.CFrame = place(s, 0)
	end
	return m
end

-- Shows the dome around `origin` (nil hides it). side: which end of the table the player stands at.
function Aquarium.show(origin: Vector3?, side: number?)
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
	clock += dt
	local base = m.PrimaryPart.CFrame
	for _, s in swimmers do
		s.part.CFrame = base * place(s, clock)
	end
end)

-- For tests: how many parts swim.
function Aquarium.swimmerCount(): number
	return #swimmers
end

return Aquarium
