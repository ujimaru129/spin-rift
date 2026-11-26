--!strict
-- Tuning numbers for the rally. Every distance is in studs, in the arena's local space:
-- the table is centred on the origin, its long side runs along X and the net sits at X = 0.
-- Side -1 is the player who stands at negative X, side 1 the one at positive X.

local Config = {}

Config.Table = {
	halfLength = 9, -- the table is 18 studs long
	halfWidth = 5, -- and 10 studs wide
	surfaceY = 3, -- height of the playing surface
	netHeight = 1.2, -- net top above the surface
}

Config.Ball = {
	radius = 0.3,
}

-- Where a paddle meets the ball: |X| of the contact point and its height.
Config.HitX = 11
Config.HitY = 4.4

-- How far (in Z) the ball may land from the player and still be returned.
Config.Reach = 3.2

-- Timing windows, in seconds either side of the moment the ball reaches the paddle.
-- Perfect gives a fast shot and +2 gauge, Good a normal shot, Weak a slow, high, easy ball.
-- A swing outside the Weak window, or out of reach, misses.
Config.Timing = {
	perfect = 0.06,
	good = 0.14,
	weak = 0.24,
}

-- A weak ball (あまい) is easy to read, so the receiver's timing windows are this much wider.
Config.WeakBallWindow = 1.4

-- Swings earlier than this before the ball arrives are ignored rather than counted as a whiff,
-- so pressing the button too early is not punished harshly while the ball is still far away.
Config.IgnoreEarlierThan = 0.45

-- Shape of each kind of shot. duration = seconds from contact to the opponent's paddle.
-- arc1 = extra height over the first leg (to the bounce), arc2 = over the second leg.
-- depth = where on the opponent's half it bounces, 0 at the net to 1 at the end line.
-- aim = how far from the middle (|Z| at the opponent's paddle, past the end of the table) the
-- shot can be placed. The ball flies straight (seen from above), so it bounces on the way there:
-- a Perfect at full aim bounces in the corner, a Good near the side line, a Weak well inside it.
export type ShotStyle = { duration: number, arc1: number, arc2: number, depth: number, aim: number }
Config.Shots = {
	Serve = { duration = 1.25, arc1 = 1.4, arc2 = 2.2, depth = 0.55, aim = 4.5 } :: ShotStyle,
	Perfect = { duration = 0.7, arc1 = 1.0, arc2 = 1.3, depth = 0.8, aim = 6.5 } :: ShotStyle,
	Good = { duration = 1.05, arc1 = 2.0, arc2 = 2.0, depth = 0.6, aim = 5.5 } :: ShotStyle,
	Weak = { duration = 1.35, arc1 = 3.4, arc2 = 2.8, depth = 0.4, aim = 4 } :: ShotStyle,
}

-- The widest aim of any shot. Aim input from -1 to 1 maps onto this, then each shot kind clamps it.
Config.MaxAim = 6.5

-- How wide the bots aim at most (their aimSpread scales this). Kept at the old width so the bots
-- play as before while players can reach the corners.
Config.BotMaxAim = 4.5

-- The bounce stays at least this far inside the side lines.
Config.BounceMargin = 0.4

-- The rally speeds up: every return makes the next ball this much quicker (a share of its flight
-- time), up to `max`, and the receiver's timing windows narrow by `window` times that share.
-- A long rally becomes hard to keep going, so points end on skill rather than on a lucky miss.
Config.Pace = {
	perReturn = 0.06,
	max = 0.45,
	window = 0.9,
}

-- Share of the flight spent before the bounce.
Config.BounceFraction = 0.55

-- Keep the ball this far inside the side lines when aiming.
Config.AimMargin = 1

-- Clearance the ball must keep over the net.
Config.NetClearance = 0.4

-- A match is one game to 5 points (shorter matches; was best of 3 games to 7).
Config.Score = {
	pointsToWinGame = 5,
	deuceAt = 4, -- from 4-4, serve alternates every point and a game needs a 2-point lead
	winBy = 2,
	gamesToWinMatch = 1,
	servesPerTurn = 2,
}

Config.Gauge = {
	max = 10,
	perReturn = 1,
	perPerfect = 2,
}

-- Pause between a point ending and the next serve, and before the first serve of a game.
Config.PointPause = 1.6
Config.GamePause = 3

-- A client's reported swing time is trusted only within this many seconds before the server got it.
Config.MaxReportedLag = 0.35

-- After the ball passes a player, the server waits this long before giving the point away,
-- so a swing that was on time but is still travelling over the network can arrive.
Config.MissGrace = 0.35

-- How far (studs) a player's own reported position may differ from where the server sees them,
-- per second of their ping. Characters walk at 16 studs/s by default.
Config.PositionTolerancePerSecond = 18
Config.PositionToleranceBase = 1.5

return Config
