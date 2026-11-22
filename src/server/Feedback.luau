--!strict
-- In-game feedback. Each message is saved in a DataStore for the developers to read with
-- tools/feedback.luau. Messages are never shown to other players.

local DataStoreService = game:GetService("DataStoreService")

local Analytics = require(script.Parent.Analytics)

local Feedback = {}

Feedback.STORE = "Feedback_v1"
Feedback.MAX_LENGTH = 200
Feedback.COOLDOWN = 60 -- seconds between messages from one player
Feedback.CATEGORIES = { fun = true, bug = true, balance = true, other = true }

local lastSent: { [number]: number } = {}

-- Returns "ok", "tooSoon", "invalid" or "failed".
function Feedback.submit(player: Player, category: unknown, text: unknown, locale: unknown): string
	if type(category) ~= "string" or not Feedback.CATEGORIES[category] or type(text) ~= "string" then
		return "invalid"
	end
	local body = string.sub(text, 1, Feedback.MAX_LENGTH)
	if #string.gsub(body, "%s", "") == 0 then
		return "invalid"
	end
	local t = os.time()
	local last = lastSent[player.UserId]
	if last and t - last < Feedback.COOLDOWN then
		return "tooSoon"
	end
	lastSent[player.UserId] = t
	local entry = {
		userId = player.UserId,
		name = player.Name,
		category = category,
		text = body,
		time = t,
		locale = if type(locale) == "string" then string.sub(locale, 1, 8) else "",
		placeVersion = game.PlaceVersion,
	}
	local ok = pcall(function()
		DataStoreService:GetDataStore(Feedback.STORE):SetAsync(`{t}_{player.UserId}`, entry)
	end)
	Analytics.event(player, "Feedback", 1, { category :: string })
	return if ok then "ok" else "failed"
end

return Feedback
