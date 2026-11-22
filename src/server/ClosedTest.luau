--!strict
-- Closed test settings.
--
-- To let only testers in: create a Roblox group for testers, put its id in GROUP_ID, set the
-- minimum rank, and set ENABLED to true. Everyone else is shown a message and removed.
-- In Studio the check is skipped so development is not blocked.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Strings"))

local ClosedTest = {}

ClosedTest.ENABLED = false
ClosedTest.GROUP_ID = 0 -- the tester group's id (the number in its URL)
ClosedTest.MIN_RANK = 1 -- 1 = any member

local function kickMessage(): string
	S.setLocale("ja")
	local ja = S.t("access.denied")
	S.setLocale("en")
	local en = S.t("access.denied")
	return ja .. "\n" .. en
end

-- Returns true if the player may play. Players who may not are kicked.
function ClosedTest.admit(player: Player): boolean
	if not ClosedTest.ENABLED or RunService:IsStudio() or ClosedTest.GROUP_ID == 0 then
		return true
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(ClosedTest.GROUP_ID)
	end)
	if ok and rank >= ClosedTest.MIN_RANK then
		return true
	end
	player:Kick(kickMessage())
	return false
end

function ClosedTest.start()
	Players.PlayerAdded:Connect(ClosedTest.admit)
	for _, p in Players:GetPlayers() do
		ClosedTest.admit(p)
	end
end

return ClosedTest
