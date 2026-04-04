-- Change the opacity of the score BitmapText actors to visually indicate who is
-- winning at a given moment during gameplay: the other local player, or the whole
-- lobby when playing against other machines in an online lobby.
------------------------------------------------------------

local canCompareLocally = #GAMESTATE:GetHumanPlayers() >= 2
	and SL["P1"].ActiveModifiers.ShowExScore == SL["P2"].ActiveModifiers.ShowExScore

if not canCompareLocally and not GetLobbyState().inLobby then return end

local p1_score, p2_score
local p1_dp = 0
local p2_dp = 0
local p1_pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_1)
local p2_pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(PLAYER_2)
local IsEX = SL["P1"].ActiveModifiers.ShowExScore

-- refreshed when the lobby status or roster changes, not on every judgment
local useLobbyStandings = false

-- allow for HideScore, which outright removes score actors
local try_diffusealpha = function(af, alpha)
	if not af or not (af.diffusealpha) then return end
	af:diffusealpha(alpha)
end

local LobbyScore = function(entry, useExScore)
	if useExScore then
		return entry.exScore
	end
	return entry.itgScore
end

-- Both sides of the comparison come from the same lobby snapshot, so a local
-- player is never ranked against a staler copy of their own score.
local LobbyAlpha = function(player)
	local useExScore = SL[ToEnumShortString(player)].ActiveModifiers.ShowExScore
	local mine = GetLobbyEntryForPlayer(player)
	local myScore = mine and LobbyScore(mine, useExScore)
	if myScore == nil then return 1 end

	for entry in ivalues(GetLobbyState().standings) do
		local score = LobbyScore(entry, useExScore)
		if score ~= nil and score > myScore then
			return 0.65
		end
	end
	return 1
end

local QueueWinning = function(self)
	if self.winningQueued then return end
	self.winningQueued = true
	self:queuecommand("Winning")
end

local RefreshLobbyMode = function(self)
	useLobbyStandings = GetLobbyState().inLobby and not IsLobbyLocalOnly()
	QueueWinning(self)
end

return Def.Actor{
	OnCommand=function(self)
		local underlay = SCREENMAN:GetTopScreen():GetChild("Underlay")
		p1_score = underlay:GetChild("P1Score")
		p2_score = underlay:GetChild("P2Score")
		RefreshLobbyMode(self)
	end,
	LobbyStatusChangedMessageCommand=RefreshLobbyMode,
	LobbyRosterChangedMessageCommand=RefreshLobbyMode,
	LobbyScoresChangedMessageCommand=function(self)
		if useLobbyStandings then
			QueueWinning(self)
		end
	end,
	JudgmentMessageCommand=function(self, params)
		if not IsEX then
			-- calculate the percentage DP manually rather than use GetPercentDancePoints.
			-- That function rounds to the nearest .01%, which is inaccurate on long songs.
			if params.Player == PLAYER_1 then
				p1_dp = p1_pss:GetActualDancePoints() / p1_pss:GetPossibleDancePoints()
			elseif params.Player == PLAYER_2 then
				p2_dp = p2_pss:GetActualDancePoints() / p2_pss:GetPossibleDancePoints()
			end
			if not useLobbyStandings then
				QueueWinning(self)
			end
		end
	end,
	ExCountsChangedMessageCommand=function(self, params)
		if IsEX then
			if params.Player == PLAYER_1 then
				p1_dp = params.ExScore
			elseif params.Player == PLAYER_2 then
				p2_dp = params.ExScore
			end
			if not useLobbyStandings then
				QueueWinning(self)
			end
		end
	end,
	WinningCommand=function(self)
		self.winningQueued = false

		if useLobbyStandings then
			try_diffusealpha(p1_score, LobbyAlpha(PLAYER_1))
			try_diffusealpha(p2_score, LobbyAlpha(PLAYER_2))
			return
		end

		if not canCompareLocally or p1_dp == p2_dp then
			try_diffusealpha(p1_score, 1)
			try_diffusealpha(p2_score, 1)
		elseif p1_dp > p2_dp then
			try_diffusealpha(p1_score, 1)
			try_diffusealpha(p2_score, 0.65)
		elseif p2_dp > p1_dp then
			try_diffusealpha(p1_score, 0.65)
			try_diffusealpha(p2_score, 1)
		end
	end
}
