-- local pad_img = GAMESTATE:GetCurrentGame():GetName()

-- if pad_img == "dance" and ThemePrefs.Get("AllowDanceSolo") then
-- 	local style = GAMESTATE:GetCurrentStyle()
-- 	-- style will be nil in ScreenTestInput within the operator menu
-- 	if style==nil or style:GetName()=="solo" then
-- 		pad_img = "dance-solo"
-- 	end
-- end

local CabinetHighlights = {
	MarqueeUpLeft=	{    x=-67, y=-148, rotationz=0, zoom=0.8, graphic="marqueehighlight.png" },
	MarqueeUpRight=	{    x=0,   y=-148, rotationz=0, zoom=0.8, graphic="marqueehighlight.png" },
	MarqueeLrLeft=	{    x=67,  y=-148, rotationz=0, zoom=0.8, graphic="marqueehighlight.png" },
	MarqueeLrRight=	{    x=-67, y=-80,  rotationz=0, zoom=0.8, graphic="marqueehighlight.png" },
	BassLeft=		{    x=0,   y=-80,  rotationz=0, zoom=0.8, graphic="bassHighlight.png" },
	BassRight=		{    x=67,  y=-80,  rotationz=0, zoom=0.8, graphic="bassHighlight.png" },
}

-- local GameButtonHighlights = {
-- 	Start={     x=0,   y=66, rotationz=0,   zoom=0.5, graphic="highlightgreen.png" }
-- 	Select={    x=0,   y=95, rotationz=180, zoom=0.5, graphic="highlightred.png" }
-- 	MenuRight={ x=37,  y=80, rotationz=0,   zoom=0.5, graphic="highlightarrow.png" }
-- 	MenuLeft={  x=-37, y=80, rotationz=180, zoom=0.5, graphic="highlightarrow.png" }
-- }

local cabinet = Def.ActorFrame{
	Name="Cabinet",
	InitCommand=function(self)
		self:visible(true)
		self.lastOn = nil
	end
	LoadActor("cabinet.png")..{
		InitCommand=function(self) 
			self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y):zoom(0.8)
		end
	},
	TestLightEventMessageCommand=function(self, params)
		if self.lastOn ~= nil then
			self.lastOn:queuecommand("TurnOff")
			self.lastOn = nil
		end

		self:GetChild(params.CabinetLightId):queuecommand("TurnOn")
		self.lastOn = self:GetChild(params.CabinetLightId)
	end
}

for panel,values in pairs(Highlights) do
	cabinet[#cabinet+1] = LoadActor(values.graphic)..{
		Name=panel,
		InitCommand=function(self) 
			self:xy(values.x, values.y):rotationz(values.rotationz):zoom(values.zoom):queuecommand("TurnOff")
		end,
		TurnOffCommand=function(self)
			self:visible(false)
		end,
		TurnOnCommand=function(self)
			self:visible(true)
		end
	}
end

local af = Def.ActorFrame{
	cabinet
}

return af