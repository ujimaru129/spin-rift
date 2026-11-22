-- A small stand-in for the Roblox engine so client and server modules can be run in Lune.
-- Datatypes (Vector3, CFrame, Color3, UDim2, Enum, ...) are Lune's real ones; Instances are
-- plain tables that store properties, keep a child list and fire events on request.
-- It only checks that the code runs without errors; it does not draw or simulate anything.

local roblox = require("@lune/roblox")

local Fake = {}

-- The fake server clock. Tests move it forward.
Fake.clock = { now = 0 }

export type Signal = {
	handlers: { (...any) -> () },
	Connect: (self: Signal, fn: (...any) -> ()) -> { Disconnect: () -> () },
	Once: (self: Signal, fn: (...any) -> ()) -> { Disconnect: () -> () },
	Fire: (self: Signal, ...any) -> (),
}

function Fake.signal(): Signal
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	return s :: any
end

local PART_CLASSES = { Part = true, SpawnLocation = true }
local EVENTS = {
	Activated = true,
	InputBegan = true,
	Ended = true,
	Completed = true,
	Changed = true,
	OnServerEvent = true,
	OnClientEvent = true,
	CharacterAdded = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	RenderStepped = true,
}

local Instance = {}

local function newInstance(className: string): any
	local props: { [string]: any } = { Name = className, ClassName = className }
	local children: { any } = {}
	local signals: { [string]: Signal } = {}
	local obj = {}
	local methods = {}

	function methods:GetChildren()
		return table.clone(children)
	end
	function methods:FindFirstChild(name)
		local alias = props.__aliases and props.__aliases[name]
		if alias then
			return alias
		end
		for _, c in children do
			if c.Name == name then
				return c
			end
		end
		return nil
	end
	methods.WaitForChild = methods.FindFirstChild
	function methods:FindFirstChildOfClass(class)
		for _, c in children do
			if c.ClassName == class then
				return c
			end
		end
		return nil
	end
	function methods:IsA(class)
		if class == className then
			return true
		end
		return class == "BasePart" and PART_CLASSES[className] == true
	end
	function methods:Destroy()
		obj.Parent = nil
		props.__destroyed = true
	end
	function methods:Clone()
		local copy = newInstance(className)
		for k, v in props do
			if k ~= "Parent" then
				rawget(copy, "__props")[k] = v
			end
		end
		for _, c in children do
			c:Clone().Parent = copy
		end
		return copy
	end
	function methods:Play() end
	function methods:Stop() end
	function methods:GetPivot()
		return props.CFrame or roblox.CFrame.new()
	end
	-- Moving a model moves the parts inside it by the same amount.
	function methods:PivotTo(cf)
		local old = props.CFrame or roblox.CFrame.new()
		local delta = cf.Position - old.Position
		props.CFrame = cf
		if className == "Model" then
			for _, c in children do
				local ccf = rawget(c, "__props").CFrame
				if ccf then
					rawget(c, "__props").CFrame = ccf + delta
				end
			end
		end
	end
	function methods:GetAttribute(name)
		return (props.__attributes or {})[name]
	end
	function methods:SetAttribute(name, value)
		props.__attributes = props.__attributes or {}
		props.__attributes[name] = value
	end
	-- RemoteEvents: FireClient delivers straight to OnClientEvent when the target is the local
	-- player, and FireServer to OnServerEvent, so server and client run against each other.
	function methods:FireClient(player, ...)
		props.__sent = props.__sent or {}
		table.insert(props.__sent, { player = player, args = { ... } })
		if Fake.localPlayer == player then
			obj.OnClientEvent:Fire(...)
		end
	end
	function methods:FireServer(...)
		obj.OnServerEvent:Fire(Fake.localPlayer, ...)
	end
	function methods:GetNetworkPing()
		return 0.05
	end
	function methods:LoadCharacter() end

	rawset(obj, "__props", props)
	rawset(obj, "__children", children)
	return setmetatable(obj, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			if EVENTS[key] then
				signals[key] = signals[key] or Fake.signal()
				return signals[key]
			end
			if key == "Position" and PART_CLASSES[className] and props.CFrame then
				return props.CFrame.Position
			end
			local v = props[key]
			if v == nil then
				for _, c in children do
					if c.Name == key then
						return c
					end
				end
			end
			return v
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local old = props.Parent
				if old then
					local list = rawget(old, "__children")
					local i = table.find(list, obj)
					if i then
						table.remove(list, i)
					end
				end
				if value then
					table.insert(rawget(value, "__children"), obj)
				end
			elseif key == "Position" and PART_CLASSES[className] then
				props.CFrame = roblox.CFrame.new(value)
				return
			end
			props[key] = value
		end,
		__tostring = function()
			return className .. " " .. tostring(props.Name)
		end,
	})
end

function Instance.new(className: string, parent: any?): any
	local x = newInstance(className)
	if parent then
		x.Parent = parent
	end
	return x
end

-- Roblox `Random` with a fixed seed.
local Random = {}
function Random.new(seed: number?)
	local state = ((seed or 1) % 2147483646) + 1
	local r = {}
	function r:NextNumber(lo, hi)
		state = (state * 16807) % 2147483647
		local f = state / 2147483647
		return if lo then lo + (hi - lo) * f else f
	end
	function r:NextInteger(lo, hi)
		return math.floor(self:NextNumber(lo, hi + 1 - 1e-9))
	end
	return r
end

-- Builds the globals a Roblox script expects. `shared` is the loader node for src/shared.
function Fake.globals(sharedNode: any)
	local workspace = Instance.new("Workspace")
	local camera = Instance.new("Camera", workspace)
	camera.ViewportSize = roblox.Vector2.new(1280, 720)
	camera.CFrame = roblox.CFrame.new()
	camera.FieldOfView = 70
	workspace.CurrentCamera = camera
	rawget(workspace, "__props").GetServerTimeNow = function()
		return Fake.clock.now
	end
	local replicated = Instance.new("ReplicatedStorage")
	replicated.__aliases = { Shared = sharedNode }
	local players = Instance.new("Players")
	rawget(players, "__props").GetPlayers = function(self)
		return self:GetChildren()
	end
	local services = {
		ReplicatedStorage = replicated,
		Players = players,
		RunService = Instance.new("RunService"),
		TweenService = {
			Create = function()
				return { Play = function() end, Completed = Fake.signal() }
			end,
		},
		UserInputService = {
			TouchEnabled = false,
			MouseEnabled = true,
			InputBegan = Fake.signal(),
			InputChanged = Fake.signal(),
			GetMouseLocation = function()
				return roblox.Vector2.new(0, 0)
			end,
		},
		Lighting = Instance.new("Lighting"),
	}
	local game = {
		GetService = function(_, name)
			return assert(services[name], "no fake for service " .. tostring(name))
		end,
	}
	return {
		game = game,
		workspace = workspace,
		Instance = Instance,
		Random = Random,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Font = roblox.Font,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		task = {
			delay = function() end,
			defer = function() end,
			spawn = function() end,
			wait = function() end,
		},
	}
end

Fake.Instance = Instance
return Fake
