local player = ...
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

return Def.Actor{
	JudgmentMessageCommand=function(self, params)
		if SYNCMAN and SYNCMAN:IsEnabled() and 
		ThemePrefs.Get("ScoringSystem") == "ITG" and 
		player == params.Player then

			local dance_points = pss:GetPercentDancePoints()
			local percent = FormatPercentScore( dance_points ):sub(1,-2)
			Trace("Triggering BroadcastScoreChange From ITG")
			SYNCMAN:BroadcastScoreChange(pss, percent, 0, pss:GetActualDancePoints(), pss:GetPossibleDancePoints())
		end
	end,
	ExCountsChangedMessageCommand=function(self, params)
		if SYNCMAN and SYNCMAN:IsEnabled() and 
		ThemePrefs.Get("ScoringSystem") == "EX" and 
		player == params.Player then

			local ex_counts = SL[ToEnumShortString(player)].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].ex_counts
			local white_count = ex_counts["W1"]
			Trace("Triggering BroadcastScoreChange From EX")
			SYNCMAN:BroadcastScoreChange(pss, params.ExScore, white_count, params.ActualPoints, params.ActualPossible)
        end
	end,
}