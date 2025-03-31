BsysResetMenuOptionRows = {}

-- -----------------------------------------------------------------------
-- Reset Menu Options

local function AskForConfirmation(message) 
	-- TODO: Implement a confirmation dialog before proceeding.
	return true
end

BsysResetMenuOptionRows.RestartGame = function()
	-- Set the flag to signal to the OS that we want to restart the game.
	BsysUtils.SetFlag("Save/Run/itg-restart")
end

BsysResetMenuOptionRows.QuitGame = function()
	-- Set the flag to signal to the OS that we want to quit the game.
	BsysUtils.SetFlag("Save/Run/itg-stop")
end

BsysResetMenuOptionRows.ResetGame = function()
	if AskForConfirmation("Are you sure you want to reset the game data?") then
		-- Set the flag to signal to the OS that we want to reset the game data.
		BsysUtils.SetFlag("Save/Run/itg-reset")
	end
end

BsysResetMenuOptionRows.RestartOs = function()
	-- Set the flag to signal to the OS that we want to restart the OS.
	BsysUtils.SetFlag("Save/Run/os-restart")
end

BsysResetMenuOptionRows.ShutdownOs = function()
	-- Set the flag to signal to the OS that we want to shutdown the OS.
	BsysUtils.SetFlag("Save/Run/os-shutdown")
end
