BsysUpdateMenuOptionRows = {}

-- -----------------------------------------------------------------------
-- Update Menu Options

BsysUpdateMenuOptionRows.UpdateAvailable = function()
	local isUpdateReady = BsysUtils.IsFlagSet("Save/Run/update-ready")
	local choices;
	if isUpdateReady then
		choices = { "Update available!" }
	else
		choices = { "Not available" }
	end

	return {
		Name = "UpdateAvailable",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectNone",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn) end,
		SaveSelections = function(self, list, pn) 
			Warn (pn)
		end,
	}
end

BsysUpdateMenuOptionRows.Update = function()
	local isUpdateReady = BsysUtils.IsFlagSet("Save/Run/update-ready")

	-- Hide the row when no update is available
	if not isUpdateReady then
		return nil 
	end

	local choices = { "No", "Yes" }
	local flagFilePath = "Save/Run/update"

	return {
		Name = "Update",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false, -- SetFlag when exiting screen
		LoadSelections = function(self, list, pn) 
			list[1] = true
		end,
		SaveSelections = function(self, list, pn)
			if list[2] then
				BsysUtils.SetFlag(flagFilePath)
			end
		end, 	
	}	
end

