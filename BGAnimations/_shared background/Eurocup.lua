-- --------------------------------------------------------
-- non-RainbowMode (normal) background

local file = ...
EUROCUP = {
	Colors = {
		"#F2B90C",
		"#35D0F2",
		"#9A9996",
		"#2594D9",
		"#F2B90C",
		"#35D0F2",
		"#9A9996",
		"#2594D9",
		"#F2B90C",
		"#35D0F2",
		"#9A9996",
		"#2594D9",
	},
	TextColor = "#ffffff",
}

function DarkerColor(c)
	return { c[1]*0.9, c[2]*0.9, c[3]*0.9, c[4] }
end

function LocalGetHexColor( n, decorative )
	-- if we were passed nil or a non-number, return white
	if n == nil or type(n) ~= "number" then return Color.White end

	local style = ThemePrefs.Get("VisualStyle")
	local colorTable = EUROCUP.Colors

	-- use the number passed in to lookup a color in the corresponding color table
	-- ensure the index is kept in bounds via modulo operation
	local clr = ((n - 1) % #colorTable) + 1
	if colorTable[clr] then
		local c = color(colorTable[clr])
		if style == "Eurocup" and not decorative then
			c = LightenColor(c)
		end
		return LightenColor(c)
	end

	return Color.White
end

local anim_data = {
	color_add = {-1,2,0,-1,-1,-1,0,-2,0,-2},
	diffusealpha = {0.05,0.2,0.1,0.1,0.1,0.1,0.1,0.05,0.1,0.1},
	xy = {0,40,80,120,200,280,360,400,480,560},
	texcoordvelocity = {{0.03,0.01},{0.03,0.02},{0.03,0.01},{0.02,0.02},{0.03,0.03},{0.02,0.02},{0.03,0.01},{-0.03,0.01},{0.05,0.03},{0.03,0.04}}
}

local t = Def.ActorFrame {
	InitCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		self:visible(style == "Eurocup")
	end,
	OnCommand=function(self) self:accelerate(0.8):diffusealpha(1) end,
	HideCommand=function(self) self:visible(false) end,

	VisualStyleSelectedMessageCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")

		if style == "Eurocup" then
			self:visible(true):linear(0.6):diffusealpha(1)

			local new_file = THEME:GetPathG("", "_VisualStyles/" .. style .. "/SharedBackground.png")
			self:RunCommandsOnChildren(function(child) child:Load(new_file) end)
		end
	end
}

for i=1,10 do
	t[#t+1] = Def.Sprite {
		Texture=file,
		InitCommand=function(self)
			self:diffuse(LocalGetHexColor(SL.Global.ActiveColorIndex+anim_data.color_add[i], true))
		end,
		OnCommand=function(self)
			self:zoom(1.3):xy(anim_data.xy[i], anim_data.xy[i])
			:customtexturerect(0,0,1,1):texcoordvelocity(anim_data.texcoordvelocity[i][1], anim_data.texcoordvelocity[i][2])
			:diffusealpha(anim_data.diffusealpha[i] * 4)
		end,

		ColorSelectedMessageCommand=function(self)
			self:linear(0.5)
			:diffuse(LocalGetHexColor(SL.Global.ActiveColorIndex+anim_data.color_add[i], true))
			:diffusealpha(anim_data.diffusealpha[i] * 4)
		end
	}
end

return t
