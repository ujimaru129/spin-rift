--!strict
-- Music for each scene and the special-move sounds. Only this player hears it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioIds = require(Shared:WaitForChild("AudioIds"))
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))

local Audio = {}

local MUSIC_VOLUME = 0.45
local SFX_VOLUME = 0.9
local FADE = 0.8
local DUCKED = 0.4 -- how far the music drops under a special move
local DUCK_FOR = 0.9

local musicOn, sfxOn = true, true
local playing: string? = nil
local tracks: { [string]: Sound } = {}
local duckToken = 0

local function group(name: string): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end
local musicGroup = group("SpinRiftMusic")
local sfxGroup = group("SpinRiftSfx")

local function fade(inst: Instance, seconds: number, volume: number)
	TweenService:Create(inst, TweenInfo.new(seconds), { Volume = volume }):Play()
end

-- Someone needs only one more point to win the match.
function Audio.matchPoint(points: { number }): boolean
	local need = Config.Score
	for i = 1, 2 do
		local mine, theirs = points[i], points[3 - i]
		if mine >= need.pointsToWinGame - 1 and mine - theirs >= need.winBy - 1 then
			return true
		end
	end
	return false
end

-- The music of a match: ranked has its own, other matches follow the arena.
function Audio.matchTrack(arena: string?, ranked: boolean?): string
	if ranked then
		return "ranked"
	end
	return if arena and AudioIds.Music[arena] then arena else "Rooftop"
end

-- Cross-fades to a track (nil = silence). Asking for the one already playing does nothing.
function Audio.music(name: string?)
	if name == playing then
		return
	end
	local old = if playing then tracks[playing] else nil
	if old then
		fade(old, FADE, 0)
		local was = playing
		task.delay(FADE, function()
			if playing ~= was then
				old:Stop()
			end
		end)
	end
	playing = name
	local id = if name then AudioIds.Music[name] else nil
	if not name or not id or id == "" then
		return
	end
	local s = tracks[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Looped = true
		s.SoundGroup = musicGroup
		s.Parent = SoundService
		tracks[name] = s
	end
	s.Volume = 0
	s:Play()
	fade(s, FADE, MUSIC_VOLUME)
end

function Audio.current(): string?
	return playing
end

local function duck()
	duckToken += 1
	local token = duckToken
	if not musicOn then
		return
	end
	fade(musicGroup, 0.08, DUCKED)
	task.delay(DUCK_FOR, function()
		if token == duckToken and musicOn then
			fade(musicGroup, 0.5, 1)
		end
	end)
end

-- Plays one sound from the sheet. The opponent's are a little quieter. Returns whether it played.
function Audio.sfx(name: string, theirs: boolean?): boolean
	local from, to = AudioIds.region(name)
	if not sfxOn or AudioIds.Sheet == "" or not from or not to then
		return false
	end
	duck()
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = AudioIds.Sheet
	s.SoundGroup = sfxGroup
	s.Volume = if theirs then SFX_VOLUME * 0.75 else SFX_VOLUME
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(from, to)
	s.Parent = SoundService
	s:Play()
	task.delay(AudioIds.SLOT + 1, function()
		s:Destroy()
	end)
	return true
end

-- Loads the sheet ahead of time, so the first special move is heard on time.
function Audio.preload()
	if AudioIds.Sheet ~= "" then
		task.spawn(function()
			pcall(function()
				local s = Instance.new("Sound")
				s.SoundId = AudioIds.Sheet
				game:GetService("ContentProvider"):PreloadAsync({ s })
			end)
		end)
	end
end

function Audio.toggleMusic(): boolean
	musicOn = not musicOn
	duckToken += 1
	fade(musicGroup, 0.2, if musicOn then 1 else 0)
	return musicOn
end

function Audio.toggleSfx(): boolean
	sfxOn = not sfxOn
	return sfxOn
end

function Audio.isOn(): (boolean, boolean)
	return musicOn, sfxOn
end

return Audio
