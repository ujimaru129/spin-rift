--!strict
-- Builds the Neon Rooftop arena out of Parts, so the prototype runs without any uploaded assets.
-- Everything is placed relative to `origin`, the centre of the table at floor level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Palette = require(Shared:WaitForChild("Palette"))

local Arena = {}

type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?,
	reflectance: number?,
	name: string?,
}

local function part(parent: Instance, p: PartProps): Part
	local x = Instance.new("Part")
	x.Name = p.name or "Part"
	x.Anchored = true
	x.Size = p.size
	x.CFrame = p.cframe
	x.Color = p.color
	x.Material = p.material or Enum.Material.SmoothPlastic
	x.Shape = p.shape or Enum.PartType.Block
	x.Transparency = p.transparency or 0
	x.CanCollide = if p.collide == nil then true else p.collide
	x.Reflectance = p.reflectance or 0
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	x.CastShadow = p.material ~= Enum.Material.Neon
	x.Parent = parent
	return x
end

-- A vertical disc (Roblox cylinders run along X, so turn them on end).
local function disc(
	parent: Instance,
	at: Vector3,
	radius: number,
	height: number,
	color: Color3,
	material: Enum.Material?
)
	return part(parent, {
		size = Vector3.new(height, radius * 2, radius * 2),
		cframe = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		shape = Enum.PartType.Cylinder,
	})
end

local function buildTable(model: Model, o: Vector3)
	local T = Config.Table
	local top = T.surfaceY
	part(model, {
		name = "TableTop",
		size = Vector3.new(T.halfLength * 2, 0.4, T.halfWidth * 2),
		cframe = CFrame.new(o + Vector3.new(0, top - 0.2, 0)),
		color = Palette.TableTop,
		reflectance = 0.12,
	})
	local function line(sx: number, sz: number, x: number, z: number)
		part(model, {
			name = "Line",
			size = Vector3.new(sx, 0.05, sz),
			cframe = CFrame.new(o + Vector3.new(x, top + 0.01, z)),
			color = Palette.Line,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	local L, W = T.halfLength, T.halfWidth
	line(L * 2, 0.15, 0, W - 0.075)
	line(L * 2, 0.15, 0, -W + 0.075)
	line(0.15, W * 2, L - 0.075, 0)
	line(0.15, W * 2, -L + 0.075, 0)
	line(L * 2, 0.08, 0, 0)
	-- glowing rim under the top
	part(model, {
		name = "Rim",
		size = Vector3.new(L * 2 + 0.3, 0.12, W * 2 + 0.3),
		cframe = CFrame.new(o + Vector3.new(0, top - 0.45, 0)),
		color = Palette.TeamA,
		material = Enum.Material.Neon,
		collide = false,
	})
	-- net
	part(model, {
		name = "Net",
		size = Vector3.new(0.08, T.netHeight, W * 2 + 0.8),
		cframe = CFrame.new(o + Vector3.new(0, top + T.netHeight / 2, 0)),
		color = Palette.Line,
		material = Enum.Material.ForceField,
		transparency = 0.2,
		collide = false,
	})
	part(model, {
		name = "NetTop",
		size = Vector3.new(0.1, 0.1, W * 2 + 0.8),
		cframe = CFrame.new(o + Vector3.new(0, top + T.netHeight, 0)),
		color = Palette.Line,
		material = Enum.Material.Neon,
		collide = false,
	})
	for _, x in { -L * 0.55, L * 0.55 } do
		part(model, {
			name = "Pedestal",
			size = Vector3.new(2.2, top - 0.4, 3.2),
			cframe = CFrame.new(o + Vector3.new(x, (top - 0.4) / 2, 0)),
			color = Palette.Metal,
			material = Enum.Material.Metal,
		})
		part(model, {
			name = "PedestalBand",
			size = Vector3.new(2.3, 0.12, 3.3),
			cframe = CFrame.new(o + Vector3.new(x, 1, 0)),
			color = Palette.TeamA,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

local function buildPlatform(model: Model, o: Vector3)
	disc(model, o + Vector3.new(0, -0.5, 0), 22, 1, Palette.Platform).Reflectance = 0.08
	local rim = disc(model, o + Vector3.new(0, -0.55, 0), 22.4, 0.9, Palette.TeamA, Enum.Material.Neon)
	rim.CanCollide = false
	local under = disc(model, o + Vector3.new(0, -3, 0), 16, 4, Palette.Metal, Enum.Material.Metal)
	under.CanCollide = false
	local core = disc(model, o + Vector3.new(0, -5.2, 0), 5, 0.6, Palette.TeamA, Enum.Material.Neon)
	core.CanCollide = false
	-- short marks of light round the edge of the floor
	for k = 0, 15 do
		local a = (k + 0.5) / 16 * math.pi * 2
		part(model, {
			name = "Mark",
			size = Vector3.new(3, 0.06, 0.16),
			cframe = CFrame.new(o) * CFrame.Angles(0, a, 0) * CFrame.new(19, 0.03, 0),
			color = if k % 2 == 0 then Palette.TeamA else Palette.TeamB,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	-- soft team-coloured light over each end, so the players stand out
	for _, side in { -1, 1 } do
		local lamp = part(model, {
			name = "Lamp",
			size = Vector3.one,
			cframe = CFrame.new(o + Vector3.new(side * 17, 11, 0)),
			color = Color3.new(1, 1, 1),
			transparency = 1,
			collide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = (if side == -1 then Palette.TeamA else Palette.TeamB):Lerp(Color3.new(1, 1, 1), 0.55)
		light.Range = 14 -- short of the table: its shine would hide the ball
		light.Brightness = 2
		light.Parent = lamp
	end
	-- floor rings around each player's zone
	for _, side in { -1, 1 } do
		local ring = disc(
			model,
			o + Vector3.new(side * 14, 0.02, 0),
			4.2,
			0.06,
			if side == -1 then Palette.TeamA else Palette.TeamB,
			Enum.Material.Neon
		)
		ring.CanCollide = false
		ring.Transparency = 0.55
	end
end

-- Invisible walls that keep each player in their own half of the floor.
local function buildZone(model: Model, o: Vector3)
	local near, far = Config.HitX - 0.5, 18.5 -- |X| range a player may stand in
	local halfZ = 8.5
	local w = far - near
	local function wall(size: Vector3, at: Vector3)
		part(model, {
			name = "ZoneWall",
			size = size,
			cframe = CFrame.new(o + at),
			color = Color3.new(1, 1, 1),
			transparency = 1,
		})
	end
	for _, side in { -1, 1 } do
		local cx = side * (near + far) / 2
		wall(Vector3.new(1, 20, halfZ * 2 + 2), Vector3.new(side * (far + 0.5), 10, 0))
		wall(Vector3.new(1, 20, halfZ * 2 + 2), Vector3.new(side * (near - 0.5), 10, 0))
		wall(Vector3.new(w, 20, 1), Vector3.new(cx, 10, halfZ + 0.5))
		wall(Vector3.new(w, 20, 1), Vector3.new(cx, 10, -halfZ - 0.5))
	end
end

local SAKURA_GLOW = Color3.fromRGB(255, 111, 174)
local AQUARIUM_GLOW = Color3.fromRGB(90, 150, 255)
local NAMES = { Sakura = "SakuraFloat", Aquarium = "AquariumDome" }

-- Recolours the neon parts shared by every arena (rims, rings, bands) for a theme.
local function tint(model: Model, from: Color3, to: Color3)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.Color == from then
			p.Color = to
		end
	end
end

-- arenaId: "Rooftop" (default), "Sakura" or "Aquarium".
function Arena.build(origin: Vector3, _seed: number, arenaId: string?): Model
	local model = Instance.new("Model")
	model.Name = NAMES[arenaId or ""] or "NeonRooftop"
	buildPlatform(model, origin)
	buildTable(model, origin)
	if arenaId == "Sakura" then
		tint(model, Palette.TeamA, SAKURA_GLOW)
	elseif arenaId == "Aquarium" then
		tint(model, Palette.TeamA, AQUARIUM_GLOW)
	end -- the scenery round each arena is drawn on each client (City, Garden, Aquarium)
	buildZone(model, origin)
	model.Parent = workspace
	return model
end

-- Where a player on `side` (-1 or 1) stands at the start, facing the table.
function Arena.playerSpawn(origin: Vector3, side: number): CFrame
	local at = origin + Vector3.new(side * 14, 3.5, 0)
	return CFrame.lookAt(at, at - Vector3.xAxis * side)
end

-- The opponent avatar: a shell-and-neon athlete built from Parts, facing the table.
function Arena.buildOpponent(origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "RiftBot"
	local root = part(model, {
		name = "Root",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(origin),
		color = Palette.Metal,
		transparency = 1,
		collide = false,
	})
	model.PrimaryPart = root
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	)
		part(model, {
			name = name,
			size = size,
			cframe = root.CFrame * offset,
			color = color,
			material = material,
			shape = shape,
			collide = false,
		})
	end
	-- the avatar faces -X (toward the table) when the root is unrotated
	piece("LegL", Vector3.new(0.7, 2.4, 0.7), CFrame.new(0, 1.2, -0.6), Palette.Metal, Enum.Material.Metal)
	piece("LegR", Vector3.new(0.7, 2.4, 0.7), CFrame.new(0, 1.2, 0.6), Palette.Metal, Enum.Material.Metal)
	piece("Torso", Vector3.new(1.3, 2, 2.2), CFrame.new(0, 3.3, 0), Palette.Metal, Enum.Material.Metal)
	piece("Chest", Vector3.new(0.6, 1.5, 1.9), CFrame.new(-0.5, 3.5, 0), Palette.Shell)
	piece("Core", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.85, 3.6, 0), Palette.TeamB, Enum.Material.Neon)
	piece("Belt", Vector3.new(1.4, 0.18, 2.3), CFrame.new(0, 2.35, 0), Palette.TeamB, Enum.Material.Neon)
	piece("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.95, 0), Palette.Shell, nil, Enum.PartType.Ball)
	piece("Visor", Vector3.new(0.3, 0.35, 1.1), CFrame.new(-0.55, 5.0, 0), Palette.TeamB, Enum.Material.Neon)
	piece(
		"ArmL",
		Vector3.new(0.5, 1.8, 0.5),
		CFrame.new(-0.2, 3.3, -1.35) * CFrame.Angles(math.rad(-15), 0, 0),
		Palette.Metal,
		Enum.Material.Metal
	)
	piece("ArmR", Vector3.new(1.8, 0.5, 0.5), CFrame.new(-1.0, 4.2, 1.3), Palette.Metal, Enum.Material.Metal)
	piece(
		"Paddle",
		Vector3.new(0.15, 1.6, 1.6),
		CFrame.new(-2.2, 4.4, 1.3) * CFrame.Angles(math.rad(90), 0, 0),
		Palette.TeamB,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	model.Parent = workspace
	return model
end

-- Gives a character a glowing paddle in the right hand.
function Arena.attachPaddle(character: Model, color: Color3, material: Enum.Material?)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("SpinRiftPaddle")
	if old then
		old:Destroy()
	end
	local paddle = Instance.new("Part")
	paddle.Name = "SpinRiftPaddle"
	paddle.Shape = Enum.PartType.Cylinder
	paddle.Size = Vector3.new(0.15, 1.7, 1.7)
	paddle.Color = color
	paddle.Material = material or Enum.Material.Neon
	paddle.CanCollide = false
	paddle.CanQuery = false
	paddle.Massless = true
	paddle.CFrame = hand.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, math.rad(90), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = paddle
	weld.Parent = paddle
	paddle.Parent = character
end

return Arena
