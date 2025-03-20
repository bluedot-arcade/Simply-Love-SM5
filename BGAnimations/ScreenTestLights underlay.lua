local game = GAMESTATE:GetCurrentGame():GetName()

local af = Def.ActorFrame {
	OffCommand=function(self) self:sleep(0.4) end
}

-- for these specific games
if (game=="dance" or game=="pump" or game=="techno") then
	local testLights = LoadActor(THEME:GetPathB("", "_modules/TestLights"))

	testLights.InitCommand=function(self) self:xy(_screen.cx + 150 * (player==PLAYER_1 and -1 or 1), _screen.cy):diffusealpha(0) end
	testLights.OnCommand=function(self) self:linear(0.3):diffusealpha(1) end
	testLights.OffCommand=function(self) self:linear(0.2):diffusealpha(0) end

	af[#af+1] = testLights
end

return af