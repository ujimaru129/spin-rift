--!strict
-- A reserved server made for one ranked match. It reads who should come from MemoryStore, waits
-- for both players, runs the match, records the result and sends everyone back to the lobby.
-- If someone does not arrive within ARRIVE_TIMEOUT seconds, the match is called off without any
-- rating change.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local RankedQueue = require(script.Parent.RankedQueue)
local RankedResult = require(script.Parent.RankedResult)
local PlayerData = require(script.Parent.PlayerData)

local RankedRoom = {}

local ARRIVE_TIMEOUT = 40
local BACK_TO_LOBBY_AFTER = 12

export type Api = {
	fire: (player: Player, event: { [string]: any }) -> (),
	startRanked: (players: { Player }, loadouts: { { string } }, onOver: (winner: number, reason: string?) -> ()) -> (),
}

function RankedRoom.isRoom(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function backToLobby(players: { Player })
	if #players == 0 then
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
end

function RankedRoom.start(api: Api)
	local info: any = nil
	for _ = 1, 10 do
		info = RankedQueue.readMatch(game.PrivateServerId)
		if info then
			break
		end
		task.wait(1)
	end
	if not info then
		warn("[RankedRoom] no match details for this server; sending players back")
		for _, p in Players:GetPlayers() do
			api.fire(p, { kind = "RankCancelled", reason = "nomatch" })
		end
		task.wait(3)
		backToLobby(Players:GetPlayers())
		return
	end

	local expected: { any } = info.players
	local started = false

	local function present(): { Player }
		local list = {}
		for _, e in expected do
			local p = Players:GetPlayerByUserId(e.userId)
			if p then
				table.insert(list, p)
			end
		end
		return list
	end

	local function tryStart()
		local here = present()
		if started or #here < 2 then
			return
		end
		started = true
		local sides = {}
		for _, e in expected do
			local data = PlayerData.load(e.userId)
			table.insert(sides, { userId = e.userId, rating = data.rating, games = data.games, region = e.region })
		end
		local players = {
			Players:GetPlayerByUserId(expected[1].userId) :: Player,
			Players:GetPlayerByUserId(expected[2].userId) :: Player,
		}
		api.startRanked(players, { expected[1].loadout, expected[2].loadout }, function(winner, reason)
			local leaver = if reason == "forfeit" or reason == "idle" then (if winner == 1 then 2 else 1) else nil
			RankedResult.finish(sides, winner, leaver, api.fire)
			task.delay(BACK_TO_LOBBY_AFTER, function()
				backToLobby(Players:GetPlayers())
			end)
		end)
	end

	local function onJoin(player: Player)
		local isExpected = false
		for _, e in expected do
			if e.userId == player.UserId then
				isExpected = true
			end
		end
		if not isExpected then
			backToLobby({ player })
			return
		end
		api.fire(player, { kind = "RoomWaiting" })
		tryStart()
	end

	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end
	task.delay(ARRIVE_TIMEOUT, function()
		if not started then
			for _, p in Players:GetPlayers() do
				api.fire(p, { kind = "RankCancelled", reason = "noshow" })
			end
			task.wait(3)
			backToLobby(Players:GetPlayers())
		end
	end)
end

return RankedRoom
