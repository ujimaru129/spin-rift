--!strict
-- Rally rules shared by server and clients. No Instances, so the same code runs in Lune tests.

return {
	Config = require(script.Config),
	Trajectory = require(script.Trajectory),
	Judge = require(script.Judge),
	Match = require(script.Match),
	Bot = require(script.Bot),
}
