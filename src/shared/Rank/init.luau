--!strict
-- Ranked play rules shared by server and clients. No Instances, so the same code runs in Lune tests.

return {
	Rating = require(script.Rating),
	Regions = require(script.Regions),
	Matchmaker = require(script.Matchmaker),
}
