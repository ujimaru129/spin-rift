--!strict
-- Grades a swing by how far it was from the moment the ball reached the paddle.

local Config = require(script.Parent.Config)

local Judge = {}

export type Grade = "Perfect" | "Good" | "Weak" | "Miss"

-- offset = swing time - arrival time, in seconds (negative = early).
function Judge.grade(offset: number): Grade
	local a = math.abs(offset)
	if a <= Config.Timing.perfect then
		return "Perfect"
	elseif a <= Config.Timing.good then
		return "Good"
	elseif a <= Config.Timing.weak then
		return "Weak"
	end
	return "Miss"
end

-- Can a player standing at playerZ reach a ball arriving at ballZ?
function Judge.inReach(ballZ: number, playerZ: number): boolean
	return math.abs(ballZ - playerZ) <= Config.Reach
end

-- Gauge gained for returning the ball with this grade.
function Judge.gaugeFor(grade: Grade): number
	if grade == "Perfect" then
		return Config.Gauge.perPerfect
	elseif grade == "Miss" then
		return 0
	end
	return Config.Gauge.perReturn
end

-- The swing time a server should use, given the time the client reported and when the
-- server received it. Reports from the future, or older than MaxReportedLag, are clamped,
-- so a modified client cannot claim it swung at a better moment than was possible.
function Judge.trustedSwingTime(reported: number, receivedAt: number): number
	return math.clamp(reported, receivedAt - Config.MaxReportedLag, receivedAt)
end

-- Where the server should treat the player as standing. The client reports its own position,
-- which is up to date on its screen, while the server only sees it after the network delay.
-- The report is trusted when it is within what the player could have walked in that time.
function Judge.trustedPlayerZ(reported: number?, serverZ: number, ping: number): number
	if reported == nil or reported ~= reported then
		return serverZ
	end
	local tolerance = Config.PositionToleranceBase + Config.PositionTolerancePerSecond * math.max(ping, 0)
	if math.abs(reported - serverZ) <= tolerance then
		return reported
	end
	return serverZ
end

return Judge
