--!strict
-- Remote names, shared by server and client. The server creates them at startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FOLDER = "SpinRiftRemotes"
-- client -> server: (mode: string, loadout: { string }) — mode is "Online" to wait for another
-- player, or a Bot profile name; loadout is the 2 ability ids the player brings
Net.REQUEST_MATCH = "RequestMatch"
Net.LEAVE_MATCH = "LeaveMatch" -- client -> server: () — leave the match or stop waiting
-- client -> server: (serverTime: number, aim: number in -1..1, myZ: number across the table)
Net.SWING = "Swing"
Net.USE_ABILITY = "UseAbility" -- client -> server: (slot: 1 | 2, dirZ: number) — dirZ is for Blink
Net.MATCH_EVENT = "MatchEvent" -- server -> client: (event: { kind: string, ... })

-- Set this attribute on ReplicatedStorage in Studio (e.g. 200) to add that many ms of round-trip
-- delay to match messages, to test how the game feels on a slow connection.
Net.DEBUG_LAG_ATTRIBUTE = "DebugLagMs"

local REMOTES = { Net.REQUEST_MATCH, Net.LEAVE_MATCH, Net.SWING, Net.USE_ABILITY, Net.MATCH_EVENT }

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
