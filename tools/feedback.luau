-- Reads the in-game feedback saved by the published game, through Roblox Open Cloud.
--
--   ROBLOX_API_KEY=... lune run tools/feedback <universeId> [out.csv]
--
-- The API key needs "DataStore: read entries" (and list) permission for this experience.
-- Create it at https://create.roblox.com/dashboard/credentials. The universe id is shown on the
-- experience's page in the Creator Dashboard.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local STORE = "Feedback_v1"
local HOST = process.env.ROBLOX_API_HOST or "https://apis.roblox.com" -- override only for testing
local BASE = HOST .. "/datastores/v1/universes/%s/standard-datastores/datastore/entries"

local universeId = process.args[1]
local outFile = process.args[2]
local apiKey = process.env.ROBLOX_API_KEY
if not universeId or not apiKey then
	print("usage: ROBLOX_API_KEY=... lune run tools/feedback <universeId> [out.csv]")
	process.exit(1)
end

local function get(url: string): any
	local res = net.request({ url = url, method = "GET", headers = { ["x-api-key"] = apiKey } })
	if not res.ok then
		error(`Open Cloud request failed ({res.statusCode}): {res.body}`)
	end
	return serde.decode("json", res.body)
end

local function encode(s: string): string
	return (string.gsub(s, "[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

-- every key in the store
local keys = {}
local cursor = ""
repeat
	local url = string.format(BASE, universeId) .. `?datastoreName={STORE}&limit=100`
	if cursor ~= "" then
		url ..= "&cursor=" .. encode(cursor)
	end
	local page = get(url)
	for _, k in page.keys or {} do
		table.insert(keys, k.key)
	end
	cursor = page.nextPageCursor or ""
until cursor == ""

local entries = {}
for _, key in keys do
	local url = string.format(BASE, universeId) .. `/entry?datastoreName={STORE}&entryKey={encode(key)}`
	table.insert(entries, get(url))
end
table.sort(entries, function(a, b)
	return (a.time or 0) > (b.time or 0)
end)

local counts = {}
for _, e in entries do
	counts[e.category] = (counts[e.category] or 0) + 1
	local when = os.date("!%Y-%m-%d %H:%M", e.time or 0)
	print(`[{when} UTC] {e.category}  {e.name} (v{e.placeVersion}, {e.locale})\n    {e.text}`)
end
print(`\n{#entries} messages`)
for cat, n in counts do
	print(`  {cat}: {n}`)
end

if outFile then
	local lines = { "time_utc,category,user_id,name,locale,place_version,text" }
	for _, e in entries do
		local text = string.gsub(e.text or "", '"', '""')
		table.insert(
			lines,
			`{os.date("!%Y-%m-%d %H:%M", e.time or 0)},{e.category},{e.userId},{e.name},{e.locale},{e.placeVersion},"{text}"`
		)
	end
	fs.writeFile(outFile, table.concat(lines, "\n") .. "\n")
	print("saved " .. outFile)
end
