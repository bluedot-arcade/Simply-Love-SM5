if not Branch then Branch = {} end

Branch.AfterScreenRankingDouble = function()
	return PREFSMAN:GetPreference("MemoryCards") and "ScreenMemoryCard" or "ScreenRainbow"
end

SelectMusicOrCourse = function()
	if GAMESTATE:IsCourseMode() then
		return "ScreenSelectCourse"
	else
		if SL.Global.GameMode == "Casual" then
			return "ScreenSelectMusicCasual"
		end

		return "ScreenSelectMusic"
	end
end

Branch.AllowScreenSelectProfile = function()
	if ThemePrefs.Get("AllowScreenSelectProfile") then
		return "ScreenSelectProfile"
	else
		return Branch.AfterSelectProfile()
	end
end

Branch.AfterSelectProfile = function()
	-- If we only want to sometimes display QR Login, only do so if at least one
	-- of the chosen profiles doesn't already have an API key saved.
	local allApiKeys = true
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local pn = ToEnumShortString(player)
		if SL[pn].ApiKey == "" then
			allApiKeys = false
			break
		end
	end
	if (SL.GrooveStats.IsConnected and
	    (ThemePrefs.Get("QRLogin") == "Always" or
			 (ThemePrefs.Get("QRLogin") == "Sometimes" and not allApiKeys))) then
		return "ScreenGrooveStatsLogin"
	else
		return Branch.AllowScreenSelectColor()
	end
end

Branch.AllowScreenSelectColor = function()
	if ThemePrefs.Get("AllowScreenSelectColor") and not ThemePrefs.Get("RainbowMode") then
		return "ScreenSelectColor"
	else
		return Branch.AfterScreenSelectColor()
	end
end

Branch.AfterScreenSelectColor = function()
	
	if THEME:GetMetric("Common", "AutoSetStyle") == true then
		local styles = { "single", "versus" }
		-- If for any reason all the screens prior are skipped we may
		-- end up here without any players joined yet, so default to 
		-- to single as PLAYER_2 can always join later
		GAMESTATE:SetCurrentStyle( styles[math.max(GAMESTATE:GetNumSidesJoined(), 1)] )
		return Branch.AllowScreenSelectPlayMode()
	end

	-- ------------------------------------------------------------
	local preferred_style = ThemePrefs.Get("PreferredStyle")

	if preferred_style ~= "none"
	-- PreferredStyle should not be possible in pay mode
	-- it's too confusing for machine operators, novice players, and developers alike
	and GAMESTATE:GetCoinMode() ~= "CoinMode_Pay" then

		-- If "versus" ensure that both players are actually considered joined.
		if preferred_style == "versus" then
			GAMESTATE:JoinPlayer(PLAYER_1)
			GAMESTATE:JoinPlayer(PLAYER_2)

		-- if PreferredStyle was "single" but both players are already joined
		-- (for whatever reason), we're in a bit of a pickle, as there is
		-- no way to read the player's mind and know which side they really
		-- want to play on. Unjoin PLAYER_2 for lack of a better solution.
		elseif preferred_style == "single" and GAMESTATE:GetNumSidesJoined() == 2 then
			GAMESTATE:UnjoinPlayer(PLAYER_2)
		end

		-- FIXME: there's probably a more sensible place to set the current style for
		-- the engine, but I guess we're doing it here, in SL-Branches.lua, for now.
		GAMESTATE:SetCurrentStyle( preferred_style )

		return Branch.AllowScreenSelectPlayMode()
	end

	return "ScreenSelectStyle"
end

Branch.AllowScreenSelectPlayMode = function()
	if ThemePrefs.Get("AllowScreenSelectPlayMode") then
		return "ScreenSelectPlayMode"
	else
		return Branch.AllowScreenSelectPlayMode2()
	end
end

Branch.AllowScreenSelectPlayMode2 = function()
	-- now that a GameMode has been selected (or defaulted), set related preferences
	SetGameModePreferences()
	-- and reload the theme's Metrics
	THEME:ReloadMetrics()
	if SL.Global.GameMode == "ITG" and ThemePrefs.Get("AllowScreenSelectPlayMode2") then
		return "ScreenSelectPlayMode2"
	else
		return "ScreenProfileLoad"
	end
end

Branch.AfterEvaluationStage = function()
	-- If we're in Casual mode, don't save the profile(s).
	if SL.Global.GameMode == "Casual" then
		return Branch.AfterProfileSave()
	else
		return "ScreenProfileSave"
	end
end

Branch.AfterSelectPlayMode = function()
	return SelectMusicOrCourse()
end

Branch.AfterGameplay = function()
	if THEME:GetMetric("ScreenHeartEntry", "HeartEntryEnabled") then
		local go_to_heart= false
		for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
			local profile= PROFILEMAN:GetProfile(pn)
			if profile and profile:GetIgnoreStepCountCalories() then
				go_to_heart= true
			end
		end

		if go_to_heart then
			return "ScreenHeartEntry"
		end
	end

	return Branch.AfterHeartEntry()
end

Branch.AfterHeartEntry = function()
	local pm = ToEnumShortString(GAMESTATE:GetPlayMode())
	if( pm == "Regular" ) then return "ScreenEvaluationStage" end
	if( pm == "Nonstop" ) then return "ScreenEvaluationNonstop" end
end

Branch.AfterSelectMusic = function()
	-- This happens in the "good path" i.e. when proceeding forward in the game
	-- loop vs. reloading the screen programmatically, or ending the session, etc.
	-- Broadcasting song selection (for online lobbies) here makes sense since
	-- this is the point at which the player has actually "selected" a song and
	-- we're proceeding to the next screen which is either Gameplay or PlayerOptions.
	--
	-- NOTE: It is possible for a player to back out of PlayerOptions, but they
	-- would be expected to pick the same song since it's broadcast to the library.
	--
	-- TODO: Consider locking the music wheel in this case.
	MESSAGEMAN:Broadcast("SongSelected")

	if SCREENMAN:GetTopScreen():GetGoToOptions() then
		return "ScreenPlayerOptions"
	else
		-- routine mode specifically uses ScreenGameplayShared
		local style = GAMESTATE:GetCurrentStyle():GetName()
		if style == "routine" then
			return "ScreenGameplayShared"
		end

		-- while everything else (single, versus, double, etc.) uses ScreenGameplay
		return Branch.GameplayScreen()
	end
end

Branch.SSMCancel = function()

	if GAMESTATE:GetCurrentStageIndex() > 0 then
		return Branch.AllowScreenEvalSummary()
	end

	return Branch.TitleMenu()
end

Branch.AllowScreenNameEntry = function()

	-- If we're in Casual mode, don't allow NameEntry, and don't
	-- bother saving the profile(s). Skip directly to GameOver.
	if SL.Global.GameMode == "Casual" then
		return Branch.AfterProfileSaveSummary()

	elseif ThemePrefs.Get("AllowScreenNameEntry") then
		return "ScreenNameEntryTraditional"

	else
		return "ScreenProfileSaveSummary"
	end
end

Branch.AllowScreenEvalSummary = function()
	if ThemePrefs.Get("AllowScreenEvalSummary") then
		return "ScreenEvaluationSummary"
	else
		return Branch.AllowScreenNameEntry()
	end
end

Branch.AfterProfileSave = function()

	if PREFSMAN:GetPreference("EventMode") then
		return SelectMusicOrCourse()
	
	elseif PremiumFreeActive() then
		if PremiumFreeExpired() then
			return Branch.AllowScreenEvalSummary()
		end

		return SelectMusicOrCourse()
		
	elseif GAMESTATE:IsCourseMode() then
		return Branch.AllowScreenNameEntry()

	elseif GAMESTATE:GetSmallestNumStagesLeftForAnyHumanPlayer() > 0 then
		return SelectMusicOrCourse()

	elseif GAMESTATE:CanContinue() then
		return "ScreenPlayAgain"

	else
		return Branch.AllowScreenEvalSummary()
	end

	-- just in case?
	return SelectMusicOrCourse()
end

Branch.AfterProfileSaveSummary = function()
	if ThemePrefs.Get("AllowScreenGameOver") then
		return "ScreenGameOver"
	else
		return Branch.AfterInit()
	end
end
