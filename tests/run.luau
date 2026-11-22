-- Test runner: `lune run tests/run` from the repo root. Runs every tests/*.spec.luau.

local fs = require("@lune/fs")
local process = require("@lune/process")

local loader = require("./loader")

local passed, failed = 0, 0

local function makeExpect()
	local function fmt(v)
		return if type(v) == "string" then string.format("%q", v) else tostring(v)
	end
	return function(actual)
		return {
			toBe = function(expected)
				if actual ~= expected then
					error(`expected {fmt(expected)}, got {fmt(actual)}`, 2)
				end
			end,
			toBeNear = function(expected, tolerance)
				if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
					error(`expected {fmt(expected)} ± {tolerance}, got {fmt(actual)}`, 2)
				end
			end,
			toBeTruthy = function()
				if not actual then
					error(`expected truthy, got {fmt(actual)}`, 2)
				end
			end,
			toBeFalsy = function()
				if actual then
					error(`expected falsy, got {fmt(actual)}`, 2)
				end
			end,
			toThrow = function()
				if pcall(actual) then
					error("expected function to throw", 2)
				end
			end,
		}
	end
end

local files = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

for _, name in files do
	print(name)
	local spec = require("./" .. string.gsub(name, "%.luau$", ""))
	local expect = makeExpect()
	for _, case in spec(loader, expect) do
		local ok, err = pcall(case[2])
		if ok then
			passed += 1
			print("  ✓ " .. case[1])
		else
			failed += 1
			print("  ✗ " .. case[1] .. "\n      " .. tostring(err))
		end
	end
end

-- Engine problems the fake Roblox saw (some are caught by pcall in game code and would
-- otherwise go unnoticed).
local fakeOk, Fake = pcall(require, "./FakeRoblox")
if fakeOk and #Fake.problems > 0 then
	local unique, seen = {}, {}
	for _, p in Fake.problems do
		if not seen[p] then
			seen[p] = true
			table.insert(unique, p)
		end
	end
	print("\nengine problems seen during the run:")
	for _, p in unique do
		print("  ! " .. p)
	end
	failed += 1
end
print(`\n{passed} passed, {failed} failed`)
process.exit(if failed == 0 then 0 else 1)
