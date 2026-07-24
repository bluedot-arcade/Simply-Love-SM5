local player = ...

local playerStats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

-- only run in modified ITGmania build
if SYNCMAN and SYNCMAN:IsEnabled() then
    local ex_counts = SL[ToEnumShortString(player)].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].ex_counts
    local white_count = ex_counts["W1"]
    local ExScore, ActualPoints, ActualPossible = CalculateExScore(player)
	local percent = ExScore

	if ThemePrefs.Get("ScoringSystem") == "ITG" then
		local dance_points = playerStats:GetPercentDancePoints()
		percent = FormatPercentScore( dance_points ):sub(1,-2)
		white_count = 0
		ActualPoints = playerStats:GetActualDancePoints()
		ActualPossible = playerStats:GetPossibleDancePoints()
	end	

	-- Broadcast final score for each player, used by syncstart-web to save scores
	if GAMESTATE:IsCourseMode() then
		SYNCMAN:BroadcastFinalCourseScore(playerStats, percent, white_count, ActualPoints, ActualPossible)
	else
		SYNCMAN:BroadcastFinalScore(playerStats, percent, white_count, ActualPoints, ActualPossible)
	end
end