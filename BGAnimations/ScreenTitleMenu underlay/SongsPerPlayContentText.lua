local af = Def.ActorFrame {}


local songsPerPlay = PREFSMAN:GetPreference("SongsPerPlay")

local text = ("%i %s"):format(songsPerPlay, THEME:GetString("ScreenTitleMenu", "songs per play"))

af[#af + 1] = LoadFont("Common Normal") .. {
	Text = text,
	InitCommand = function(self)
		self:zoom(1):xy(0, 190):horizalign(center):diffusealpha(0)
		self:playcommand("UpdateColor")
	end,
	OnCommand = function(self)
		if SCREENMAN:GetTopScreen():GetName() == "ScreenTitleJoin" and GAMESTATE:GetCoinMode() == "CoinMode_Pay" then
			self:diffusealpha(0):linear(0.5):diffusealpha(1)
		else
			-- hide
			self:diffusealpha(0)
		end
	end,
	UpdateColorCommand = function(self)
		local textColor = color("#ffffff")
		local shadowLength = 0
		if ThemePrefs.Get("RainbowMode") and not HolidayCheer() then
			textColor = Color.Black
		end
		if ThemePrefs.Get("VisualStyle") == "SRPG8" then
			textColor = color(SL.SRPG8.TextColor)
			shadowLength = 0.4
		end

		self:diffuse(textColor):shadowlength(shadowLength)
	end,
	VisualStyleSelectedMessageCommand = function(self)
		self:playcommand("UpdateColor")
	end,
}

return af
