--!strict
-- What happens when a ranked match ends: both ratings change, records and leaderboards are saved,
-- and each player still here is told how their rating and rank moved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rating = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rank"):WaitForChild("Rating"))
local PlayerData = require(script.Parent.PlayerData)
local Leaderboard = require(script.Parent.Leaderboard)

local RankedResult = {}

-- One side of a ranked match, as it stood when the match started.
export type Side = { userId: number, rating: number, games: number, region: string }

export type Outcome = {
	userId: number,
	won: boolean,
	before: number,
	after: number,
	delta: number,
	tierBefore: string,
	tierAfter: string,
}

-- winner = 1 or 2. leaver = the side that walked out (counts as a loss and an abandon), if any.
function RankedResult.finish(
	sides: { Side },
	winner: number,
	leaver: number?,
	fire: (player: Player, event: { [string]: any }) -> ()
): { Outcome }
	local outcomes: { Outcome } = {}
	for i, side in sides do
		local other = sides[if i == 1 then 2 else 1]
		local won = i == winner
		local delta = Rating.delta(side.rating, other.rating, won, side.games)
		local data = PlayerData.recordResult(side.userId, delta, won, leaver == i)
		Leaderboard.submit(side.userId, data.rating, side.region)
		local outcome: Outcome = {
			userId = side.userId,
			won = won,
			before = side.rating,
			after = data.rating,
			delta = delta,
			tierBefore = Rating.tier(side.rating).label,
			tierAfter = Rating.tier(data.rating).label,
		}
		table.insert(outcomes, outcome)
		local player = Players:GetPlayerByUserId(side.userId)
		if player then
			fire(player, {
				kind = "RankResult",
				won = won,
				before = outcome.before,
				after = outcome.after,
				delta = delta,
				tierBefore = outcome.tierBefore,
				tierAfter = outcome.tierAfter,
				rankUp = outcome.tierAfter ~= outcome.tierBefore and won,
				rankDown = outcome.tierAfter ~= outcome.tierBefore and not won,
			})
		end
	end
	return outcomes
end

return RankedResult
