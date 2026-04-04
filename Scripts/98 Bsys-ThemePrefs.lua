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
		LobbyUpdateInterval = {
			Default = 100,
			Choices = { "0 ms", "50 ms", "100 ms", "250 ms", "500 ms", "1000 ms" },
			Values  = { 0, 50, 100, 250, 500, 1000 }
		},
	}
end

BsysThemePrefs.AddTo = function(prefs)
	for name, pref in pairs(Get()) do
		prefs[name] = pref
	end
	return prefs
end
