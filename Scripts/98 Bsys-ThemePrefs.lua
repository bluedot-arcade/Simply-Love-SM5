-- bsys ThemePrefs live here, not in SL_CustomPrefs.Get(), so upstream edits
-- to that table don't conflict with ours. They still end up in the same
-- [Simply Love] section of ThemePrefs.ini.
BsysThemePrefs = {}

local function Get()
	return {
		ShowBuild =
		{
			Default = false,
			Choices = { THEME:GetString("ThemePrefs","Yes"), THEME:GetString("ThemePrefs", "No") },
			Values  = { true, false }
		},
		HideCdTitles = {
			Default = true,
			Choices = {THEME:GetString("ThemePrefs", "Show"), THEME:GetString("ThemePrefs", "Hide") },
			Values = {true, false}
		},
	}
end

BsysThemePrefs.AddTo = function(prefs)
	for name, pref in pairs(Get()) do
		prefs[name] = pref
	end
	return prefs
end
