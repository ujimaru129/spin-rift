--!strict
-- Remote names, shared by server and client. The server creates them at startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FOLDER = "SpinRiftRemotes"
-- client -> server: (mode: string, loadout: { string }, arena: string) — mode is "Ranked", "Online"
-- (casual), "Tutorial" or a Bot profile name; loadout is the 2 ability ids the player brings;
-- arena is the arena id picked on the menu (ignored for ranked)
Net.REQUEST_MATCH = "RequestMatch"
Net.LEAVE_MATCH = "LeaveMatch" -- client -> server: () — leave the match or stop waiting
-- client -> server: (serverTime: number, aim: number in -1..1, myZ: number across the table)
Net.SWING = "Swing"
Net.HELLO = "Hello" -- client -> server: () — the client is ready; the server replies with a Profile event
Net.REQUEST_LEADERBOARD = "RequestLeaderboard" -- client -> server: (scope: "GLOBAL" | region id)
-- client -> server: (category: "fun" | "bug" | "balance" | "other", text: string, locale: string)
Net.SEND_FEEDBACK = "SendFeedback"
Net.EQUIP = "Equip" -- client -> server: (kind: "paddle" | "trail" | "title", itemId: string) — "" for none
Net.BUY_PREMIUM = "BuyPremium" -- client -> server: () — buy this season's Premium Battle Pass
Net.MATCH_EVENT = "MatchEvent" -- server -> client: (event: { kind: string, ... })

-- Set this attribute on ReplicatedStorage in Studio (e.g. 200) to add that many ms of round-trip
-- delay to match messages, to test how the game feels on a slow connection.
Net.DEBUG_LAG_ATTRIBUTE = "DebugLagMs"

local REMOTES = {
	Net.REQUEST_MATCH,
	Net.LEAVE_MATCH,
	Net.SWING,
	Net.HELLO,
	Net.REQUEST_LEADERBOARD,
	Net.SEND_FEEDBACK,
	Net.EQUIP,
	Net.BUY_PREMIUM,
	Net.MATCH_EVENT,
}

-- Server only: creates the remotes folder once.
function Net.create(): Folder
	local folder = Instance.new("Folder")
	folder.Name = Net.FOLDER
	for _, name in REMOTES do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

function Net.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Net.FOLDER)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
