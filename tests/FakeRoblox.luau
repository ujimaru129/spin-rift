-- A small stand-in for the Roblox engine so client and server modules can be run in Lune.
-- Datatypes (Vector3, CFrame, Color3, UDim2, Enum, ...) are Lune's real ones; Instances are
-- plain tables that store properties, keep a child list and fire events on request.
-- It only checks that the code runs without errors; it does not draw or simulate anything.

local roblox = require("@lune/roblox")

local Fake = {}

-- The fake server clock. Tests move it forward.
Fake.clock = { now = 0 }
Fake.studio = true

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

-- Roblox's own class definitions: every property the game code reads or writes is checked against
-- them, the way Studio would ("X is not a valid member of Y", read-only properties, wrong types).
local db = roblox.getReflectionDatabase()
Fake.problems = {} :: { string }

local function findProperty(className: string, key: string): any
	local class = db:GetClass(className)
	while class do
		local p = class.Properties[key]
		if p then
			return p
		end
		class = if class.Superclass then db:GetClass(class.Superclass) else nil
	end
	return nil
end

local NUMBER_TYPES = { Float32 = true, Float64 = true, Int32 = true, Int64 = true }
local DATATYPES = {
	Bool = "boolean",
	String = "string",
	Content = "string",
	ContentId = "string",
	Color3 = "Color3",
	UDim = "UDim",
	UDim2 = "UDim2",
	Vector2 = "Vector2",
	Vector3 = "Vector3",
	CFrame = "CFrame",
	NumberSequence = "NumberSequence",
	ColorSequence = "ColorSequence",
	NumberRange = "NumberRange",
	Font = "Font",
	Rect = "Rect",
}

local function problem(message: string)
	table.insert(Fake.problems, message)
	error(message, 3)
end

local function checkWrite(className: string, key: string, value: any)
	if string.sub(key, 1, 2) == "__" or not db:GetClass(className) then
		return
	end
	local p = findProperty(className, key)
	if not p then
		problem(`{key} is not a valid member of {className}`)
	end
	if p.Scriptability ~= "ReadWrite" and p.Scriptability ~= "Write" then
		problem(`Unable to assign property {key}. Property is read only ({className})`)
	end
	local dt = p.Datatype
	local t = typeof(value)
	if NUMBER_TYPES[dt] then
		if t ~= "number" then
			problem(`{className}.{key} expects a number, got {t}`)
		end
	elseif DATATYPES[dt] then
		if t ~= DATATYPES[dt] then
			problem(`{className}.{key} expects {DATATYPES[dt]}, got {t}`)
		end
	elseif string.sub(dt, 1, 5) == "Enum." then
		local enumName = string.sub(dt, 6)
		if t ~= "EnumItem" or not string.find(tostring(value.EnumType), enumName, 1, true) then
			problem(`{className}.{key} expects {dt}, got {tostring(value)}`)
		end
	end
end
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
	function methods:GetPropertyChangedSignal(name)
		local key = "Changed:" .. name
		signals[key] = signals[key] or Fake.signal()
		return signals[key]
	end
	function methods:Play() end
	function methods:Stop() end
	function methods:Emit(_count) end
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
	function methods:Kick(message)
		props.__kicked = message or ""
	end
	function methods:GetRankInGroup(groupId)
		return (props.__groups or {})[groupId] or 0
	end

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
				-- not a child either: it must be a real property of the class
				if
					type(key) == "string"
					and string.sub(key, 1, 2) ~= "__"
					and db:GetClass(className)
					and not findProperty(className, key)
				then
					problem(`{key} is not a valid member of {className}`)
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
			if not Fake.setting then
				checkWrite(className, key, value)
			end
			props[key] = value
		end,
		__tostring = function()
			return className .. " " .. tostring(props.Name)
		end,
	})
end

-- Test setup only: set properties the game itself may not (read-only ones like UserId) or that
-- stand in for engine methods. Game code goes through the checks above.
function Fake.set(inst: any, values: { [string]: any })
	Fake.setting = true
	for k, v in values do
		inst[k] = v
	end
	Fake.setting = false
end

function Instance.new(className: string, parent: any?): any
	if not db:GetClass(className) then
		problem(`Unable to create an Instance of type "{className}"`)
	end
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

-- DataStores kept in memory. Fake.dataStores[name][key] = value.
Fake.dataStores = {} :: { [string]: { [string]: any } }

local function dataStore(name: string)
	Fake.dataStores[name] = Fake.dataStores[name] or {}
	local data = Fake.dataStores[name]
	return {
		GetAsync = function(_, key)
			return data[key]
		end,
		SetAsync = function(_, key, value)
			data[key] = value
		end,
		UpdateAsync = function(_, key, fn)
			local new = fn(data[key])
			if new ~= nil then
				data[key] = new
			end
			return data[key]
		end,
		GetSortedAsync = function(_, ascending, pageSize)
			local items = {}
			for k, v in data do
				table.insert(items, { key = k, value = v })
			end
			table.sort(items, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #items) do
				page[i] = items[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
			}
		end,
	}
end

-- MemoryStore sorted maps shared by every fake "server" in a test; entries expire on Fake.clock.
Fake.memoryStores = {} :: { [string]: { [string]: { value: any, expires: number, sortKey: any } } }

local function sortedMap(name: string)
	Fake.memoryStores[name] = Fake.memoryStores[name] or {}
	local data = Fake.memoryStores[name]
	local function live(key)
		local e = data[key]
		if e and e.expires <= Fake.clock.now then
			data[key] = nil
			return nil
		end
		return e
	end
	return {
		GetAsync = function(_, key)
			local e = live(key)
			return if e then e.value else nil
		end,
		SetAsync = function(_, key, value, expiration, sortKey)
			data[key] = { value = value, expires = Fake.clock.now + expiration, sortKey = sortKey }
			return true
		end,
		RemoveAsync = function(_, key)
			data[key] = nil
		end,
		UpdateAsync = function(_, key, fn, expiration)
			local e = live(key)
			local new = fn(if e then e.value else nil)
			if new == nil then
				return nil
			end
			data[key] = { value = new, expires = Fake.clock.now + expiration }
			return new
		end,
		GetRangeAsync = function(_, direction, count)
			local items = {}
			for k in data do
				local e = live(k)
				if e then
					table.insert(items, { key = k, value = e.value, sortKey = e.sortKey })
				end
			end
			table.sort(items, function(a, b)
				return (a.sortKey or 0) < (b.sortKey or 0)
			end)
			local out = {}
			for i = 1, math.min(count, #items) do
				out[i] = items[i]
			end
			return out
		end,
	}
end

-- Teleports and reserved servers are only recorded.
Fake.teleports = {} :: { any }
Fake.reserved = 0

-- Builds the globals a Roblox script expects. `shared` is the loader node for src/shared.
function Fake.globals(sharedNode: any)
	local workspace = Instance.new("Workspace")
	local camera = Instance.new("Camera", workspace)
	Fake.set(camera, { ViewportSize = roblox.Vector2.new(1280, 720) })
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
	rawget(players, "__props").GetPlayerByUserId = function(self, userId)
		for _, p in self:GetChildren() do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end
	rawget(players, "__props").GetNameFromUserIdAsync = function(_, userId)
		return "User" .. tostring(userId)
	end
	local runService = Instance.new("RunService")
	rawget(runService, "__props").IsStudio = function()
		return Fake.studio
	end
	rawget(runService, "__props").BindToRenderStep = function(self, _name, _priority, fn)
		self.RenderStepped:Connect(fn)
	end
	local services = {
		ReplicatedStorage = replicated,
		Players = players,
		RunService = runService,
		DataStoreService = {
			GetDataStore = function(_, name)
				return dataStore(name)
			end,
			GetOrderedDataStore = function(_, name)
				return dataStore("ordered:" .. name)
			end,
		},
		MemoryStoreService = {
			GetSortedMap = function(_, name)
				return sortedMap(name)
			end,
		},
		TeleportService = {
			ReserveServer = function()
				Fake.reserved += 1
				return "code" .. Fake.reserved, "private" .. Fake.reserved
			end,
			TeleportAsync = function(_, placeId, list, options)
				table.insert(Fake.teleports, { placeId = placeId, players = list, options = options })
			end,
		},
		LocalizationService = {
			RobloxLocaleId = "ja-jp",
			GetCountryRegionForPlayerAsync = function(_, player)
				return rawget(player, "__props").Country or "JP"
			end,
		},
		MarketplaceService = {
			PromptGamePassPurchaseFinished = Fake.signal(),
			UserOwnsGamePassAsync = function()
				return false
			end,
			PromptGamePassPurchase = function() end,
		},
		AnalyticsService = {
			LogOnboardingFunnelStepEvent = function() end,
			LogCustomEvent = function() end,
		},
		TweenService = {
			Create = function()
				return { Play = function() end, Completed = Fake.signal() }
			end,
		},
		UserInputService = {
			TouchEnabled = false,
			MouseEnabled = true,
			InputBegan = Fake.signal(),
			InputEnded = Fake.signal(),
			InputChanged = Fake.signal(),
			GetFocusedTextBox = function()
				return nil
			end,
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
		PlaceId = 0,
		PlaceVersion = 1,
		JobId = "job-local",
		PrivateServerId = "",
		PrivateServerOwnerId = 0,
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
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		ColorSequence = roblox.ColorSequence,
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		task = {
			delay = function() end,
			defer = function(fn, ...)
				fn(...)
			end,
			spawn = function(fn, ...)
				fn(...)
			end,
			wait = function() end,
		},
		warn = function() end,
	}
end

Fake.Instance = Instance
return Fake
