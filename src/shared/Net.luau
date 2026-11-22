--!strict
-- Remote names, shared by server and client. The server creates them at startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FOLDER = "SpinRiftRemotes"
Net.START_PRACTICE = "StartPractice" -- client -> server: (mode: string)
Net.LEAVE_PRACTICE = "LeavePractice" -- client -> server: ()
Net.SWING = "Swing" -- client -> server: (serverTime: number, aim: number in -1..1)
Net.MATCH_EVENT = "MatchEvent" -- server -> client: (event: { kind: string, ... })

local REMOTES = { Net.START_PRACTICE, Net.LEAVE_PRACTICE, Net.SWING, Net.MATCH_EVENT }

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
