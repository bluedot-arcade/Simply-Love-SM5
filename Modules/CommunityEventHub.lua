-- Submits a played score to a Community Event Hub.
--
-- One envelope per play, sent from evaluation with the player's own key. The hub
-- recognises the chart by the same hash GrooveStats uses, so a contest phase
-- claims the play by itself and this module decides nothing about what it counts
-- for.
--
-- The key and the address live in CommunityEventHub.ini in the player's profile,
-- the way GrooveStats.ini does: a cabinet with no profile submits nothing, and a
-- profile with no key is a player who has not asked to take part.
--
-- Every play is written to a queue in the profile before it is sent, and the
-- whole queue goes in one batch: a cabinet that was offline catches up on the
-- next evaluation screen, and nothing is lost by a send that failed.
--
-- Nothing is dated here. The engine exposes a wall clock with no timezone, and an
-- instant that may be hours out is worse than the hub's own clock, which is
-- within seconds of a play submitted as it happens.

local INI_FILE = "CommunityEventHub.ini"
local QUEUE_FILE = "CommunityEventHubQueue.json"

-- What the hub accepts in one batch. The oldest plays go first when a cabinet has
-- been offline for longer than that.
local QUEUE_LIMIT = 50

local READ = 1
local WRITE = 6

local PROFILE_SLOT = {
	[PLAYER_1] = "ProfileSlot_Player1",
	[PLAYER_2] = "ProfileSlot_Player2",
}

local requests = {}

local ProfileDirOf = function(player)
	local slot = PROFILE_SLOT[player]
	if not slot then return nil end

	local dir = PROFILEMAN:GetProfileDir(slot)
	if not dir or #dir == 0 then return nil end

	return dir
end

-- The address and the key, created empty the first time so a player has a file to fill in.
local SettingsOf = function(player)
	local dir = ProfileDirOf(player)
	if not dir then return nil end

	local path = dir .. INI_FILE

	if not FILEMAN:DoesFileExist(path) then
		IniFile.WriteFile(path, { ["CommunityEventHub"] = { ["Url"] = "", ["ApiKey"] = "" } })
		return nil
	end

	local contents = IniFile.ReadFile(path)
	local section = contents and contents["CommunityEventHub"]
	if not section then return nil end

	local url = tostring(section["Url"] or ""):gsub("/+$", "")
	local apiKey = tostring(section["ApiKey"] or "")

	if #url == 0 or #apiKey == 0 then return nil end

	return { url = url, apiKey = apiKey }
end

local ReadQueue = function(player)
	local dir = ProfileDirOf(player)
	if not dir then return {} end

	local path = dir .. QUEUE_FILE
	if not FILEMAN:DoesFileExist(path) then return {} end

	local file = RageFileUtil.CreateRageFile()
	local queued = {}
	if file:Open(path, READ) then
		queued = JsonDecode(file:Read()) or {}
		file:Close()
	end
	file:destroy()

	return queued
end

local WriteQueue = function(player, scores)
	local dir = ProfileDirOf(player)
	if not dir then return end

	while #scores > QUEUE_LIMIT do
		table.remove(scores, 1)
	end

	local file = RageFileUtil.CreateRageFile()
	if file:Open(dir .. QUEUE_FILE, WRITE) then
		file:Write(JsonEncode(scores))
		file:Close()
	end
	file:destroy()
end

-- Every number here is one the evaluation screen shows, in the scale the hub
-- keeps: hundredths of a percent, and one count per timing window with
-- Fantastic+ apart, which is what EX cannot be recomputed without.
local EnvelopeOf = function(player)
	local pn = ToEnumShortString(player)
	local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
	local hash = SL[pn].Streams.Hash

	if not hash or #hash == 0 then return nil end

	local counts = GetExJudgmentCounts(player)
	local ex = CalculateExScore(player)
	local itg = stats:GetPercentDancePoints() * 10000

	return {
		-- The hub answers a repeated submission with the first result instead of
		-- archiving the play twice, which is what makes a queued send safe to retry.
		submissionId = string.format("%s-%s-%d-%d", pn, hash, SL.Global.Stages.PlayedThisGame + 1, math.floor(GetTimeSinceStart())),
		chartHash = hash,
		rate = tonumber(string.format("%.0f", SL.Global.ActiveModifiers.MusicRate * 100)),
		exScore = math.floor(ex * 100 + 0.5),
		itgScore = math.max(0, math.floor(itg + 0.5)),
		outcome = stats:GetFailed() and "failed" or "cleared",
		device = SL[pn].IsPadPlayer and "pad" or "keyboard",
		judgments = {
			fantasticPlus = counts["W0"] or 0,
			fantastic = counts["W1"] or 0,
			excellent = counts["W2"] or 0,
			great = counts["W3"] or 0,
			decent = counts["W4"] or 0,
			wayOff = counts["W5"] or 0,
			miss = counts["Miss"] or 0,
		},
		holds = { held = counts["Holds"] or 0, total = counts["totalHolds"] or 0 },
		rolls = { held = counts["Rolls"] or 0, total = counts["totalRolls"] or 0 },
		mines = { hit = counts["Mines"] or 0, total = counts["totalMines"] or 0 },
		modifiers = CreateCommentString(player),
	}
end

local Refused = function(response)
	local body = response.statusCode == 200 and JsonDecode(response.body) or nil
	if not body or not body.results then return 0 end

	local refused = 0
	for result in ivalues(body.results) do
		if not result.accepted then
			refused = refused + 1
		end
	end

	return refused
end

-- One request per player, because one key authorizes one player.
local Send = function(player, settings, scores)
	local index = #requests + 1

	requests[index] = NETWORK:HttpRequest{
		url = settings.url .. "/scores/batch",
		method = "POST",
		body = JsonEncode({ scores = scores }),
		headers = { ["Content-Type"] = "application/json", ["X-Api-Key"] = settings.apiKey },
		connectTimeout = 10,
		transferTimeout = 30,
		onResponse = function(response)
			requests[index] = nil

			-- A queue the hub has answered for is a queue that is done with, refusals
			-- included: an unknown chart is not going to become known by being sent again.
			if response.statusCode == 200 or response.statusCode == 201 then
				WriteQueue(player, {})

				local refused = Refused(response)
				if refused > 0 then
					SM("Community Event Hub: " .. refused .. " score(s) refused")
				end

				return
			end

			-- The queue is already on disk: leaving it is the retry.
			SM("Community Event Hub: score queued (" .. tostring(response.statusCode or "no answer") .. ")")
		end,
	}
end

local SubmitFor = function(player)
	local settings = SettingsOf(player)
	if not settings then return end

	local scores = ReadQueue(player)

	local envelope = EnvelopeOf(player)
	if envelope then
		scores[#scores + 1] = envelope
	end

	if #scores == 0 then return end

	WriteQueue(player, scores)
	Send(player, settings, scores)
end

local t = {}

t["ScreenEvaluationStage"] = Def.ActorFrame {
	ModuleCommand = function(self)
		if GAMESTATE:IsCourseMode() then return end

		for player in ivalues(GAMESTATE:GetHumanPlayers()) do
			SubmitFor(player)
		end
	end,
	OffCommand = function(self)
		-- A request outliving its screen would answer into nothing.
		for index, request in pairs(requests) do
			request:Cancel()
			requests[index] = nil
		end
	end,
}

return t
