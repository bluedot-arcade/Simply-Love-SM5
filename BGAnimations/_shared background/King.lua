local file = ...

local file1 = "./KING/1.png"
local file2 = "./KING/2.png"
local file3 = "./KING/3.png"
local file4 = "./KING/4.png"
local grain = "./KING/grain.png"

local glitchBPM = 50
local glitchBeat = 60 / glitchBPM

local myZoom = 0.7
local mySleep = glitchBeat / 5
local spriteX = SCREEN_CENTER_X + (SCREEN_WIDTH/4)+60
local spriteY = SCREEN_CENTER_Y
local anaglyphSleep = glitchBeat / 10
local anaglyphAlpha = 0.22
local anaglyphJitter = 7

local function AddKingSprite(texture, alpha)
	return Def.Sprite {
		Texture = texture,

		OnCommand=function(self)
			self:zoom(myZoom)
				:xy(spriteX, spriteY)
				:diffusealpha(alpha)
		end
	}
end

local function AddAnaglyphSprite(texture, color, alpha)
	return Def.Sprite {
		Texture = texture,

		OnCommand=function(self)
			self:zoom(myZoom)
				:xy(spriteX, spriteY)
				:diffuse(color[1], color[2], color[3], alpha)
		end
	}
end

local t = Def.ActorFrame {

	----------------------------------------------------
	-- INIT
	----------------------------------------------------
	InitCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		self:visible(style == "KING")
	end,

	OnCommand=function(self)
		self:fov(90):diffusealpha(1)
		self:queuecommand("GlitchLoop")
	end,

	HideCommand=function(self)
		self:visible(false)
	end,

	----------------------------------------------------
	-- SCREEN DIM LOGIC
	----------------------------------------------------
	ScreenChangedMessageCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		local screensToDim = {
			"ScreenSelectStyle",
			"ScreenSelectMusic",
			"ScreenProfileSaveSummary",
			"ScreenEvaluationStage",
			"ScreenEvaluationSummary",
			"ScreenGameOver",
			"ScreenPlayerOptions"
		}

		local name = screen:GetName()

		for _, screenName in ipairs(screensToDim) do
			if name == screenName then
				self:diffusealpha(0.5)
				return
			end
		end
	end,

	----------------------------------------------------
	-- STYLE TOGGLE
	----------------------------------------------------
	VisualStyleSelectedMessageCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")

		if style == "KING" then
			self:visible(true):linear(0.6):diffusealpha(1)
		else
			self:linear(0.6):diffusealpha(0):queuecommand("Hide")
		end
	end,

	----------------------------------------------------
	-- GLITCH LOOP (3 LAYERS)
	----------------------------------------------------
	GlitchLoopCommand=function(self)
		local f2 = self:GetChild("F2")
		local f3 = self:GetChild("F3")
		local f4 = self:GetChild("F4")

		f2:linear(mySleep):diffusealpha(0.5)
		f3:linear(mySleep):diffusealpha(0.2)
		f4:linear(mySleep):diffusealpha(0.5)

		self:sleep(mySleep)
		self:queuecommand("Step2")
	end,

	Step2Command=function(self)
		local f2 = self:GetChild("F2")
		local f3 = self:GetChild("F3")
		local f4 = self:GetChild("F4")

		f2:linear(mySleep):diffusealpha(0.2)
		f3:linear(mySleep):diffusealpha(0.5)
		f4:linear(mySleep):diffusealpha(0.3)

		self:sleep(mySleep)
		self:queuecommand("Step3")
	end,

	Step3Command=function(self)
		local f2 = self:GetChild("F2")
		local f3 = self:GetChild("F3")
		local f4 = self:GetChild("F4")

		f2:linear(mySleep):diffusealpha(0.18)
		f3:linear(mySleep):diffusealpha(0.24)
		f4:linear(mySleep):diffusealpha(0.18)

		self:sleep(mySleep)
		self:queuecommand("Step4")
	end,

	Step4Command=function(self)
		local f2 = self:GetChild("F2")
		local f3 = self:GetChild("F3")
		local f4 = self:GetChild("F4")

		local r = math.random(1,3)

		f2:linear(mySleep):diffusealpha(r == 1 and 0.5 or 0.25)
		f3:linear(mySleep):diffusealpha(r == 2 and 0.5 or 0.25)
		f4:linear(mySleep):diffusealpha(r == 3 and 0.5 or 0.25)

		self:sleep(mySleep)
		self:queuecommand("Step5")
	end,

	Step5Command=function(self)
		local f2 = self:GetChild("F2")
		local f3 = self:GetChild("F3")
		local f4 = self:GetChild("F4")

		f2:linear(mySleep):diffusealpha(0.7)
		f3:linear(mySleep):diffusealpha(0.7)
		f4:linear(mySleep):diffusealpha(0.7)

		self:sleep(mySleep)
		self:queuecommand("GlitchLoop")
	end
}

----------------------------------------------------
-- BACKGROUND
----------------------------------------------------
t[#t+1] = Def.Quad {
	InitCommand=function(self)
		self:diffuse(20/255, 20/255, 20/255, 1)
			:zoomto(SCREEN_WIDTH, SCREEN_HEIGHT)
			:Center()
	end
}

t[#t+1] = Def.Quad {
	InitCommand=function(self)
		self:Center():FullScreen():diffuse(Color.Black)
	end
}

----------------------------------------------------
-- RED / BLUE 3D OFFSET LAYERS
----------------------------------------------------
t[#t+1] = Def.ActorFrame {
	Name="Red3D",
	OnCommand=function(self)
		self:diffusealpha(anaglyphAlpha)
		self:queuecommand("AnaglyphLoop")
	end,
	AnaglyphLoopCommand=function(self)
		self:stoptweening()
			:xy(math.random(-anaglyphJitter, anaglyphJitter), math.random(-anaglyphJitter, anaglyphJitter))
			:sleep(anaglyphSleep)
			:queuecommand("AnaglyphLoop")
	end,
	AddAnaglyphSprite(file1, {1, 0, 0}, 0.5),
	AddAnaglyphSprite(file2, {1, 0, 0}, 1),
	AddAnaglyphSprite(file3, {1, 0, 0}, 1),
	AddAnaglyphSprite(file4, {1, 0, 0}, 1)
}

t[#t+1] = Def.ActorFrame {
	Name="Blue3D",
	OnCommand=function(self)
		self:diffusealpha(anaglyphAlpha)
		self:queuecommand("AnaglyphLoop")
	end,
	AnaglyphLoopCommand=function(self)
		self:stoptweening()
			:xy(math.random(-anaglyphJitter, anaglyphJitter), math.random(-anaglyphJitter, anaglyphJitter))
			:sleep(anaglyphSleep)
			:queuecommand("AnaglyphLoop")
	end,
	AddAnaglyphSprite(file1, {0, 0.45, 1}, 0.5),
	AddAnaglyphSprite(file2, {0, 0.45, 1}, 1),
	AddAnaglyphSprite(file3, {0, 0.45, 1}, 1),
	AddAnaglyphSprite(file4, {0, 0.45, 1}, 1)
}

----------------------------------------------------
-- FILE 1 (STATIC)
----------------------------------------------------
t[#t+1] = AddKingSprite(file1, 0.5)

----------------------------------------------------
-- FILE 2 (GLITCH A)
----------------------------------------------------
t[#t+1] = Def.Sprite {
	Name="F2",
	Texture = file2,

	OnCommand=function(self)
		self:zoom(myZoom)
			:xy(spriteX, spriteY)
			:diffusealpha(1)
	end
}

----------------------------------------------------
-- FILE 3 (GLITCH B)
----------------------------------------------------
t[#t+1] = Def.Sprite {
	Name="F3",
	Texture = file3,

	OnCommand=function(self)
		self:zoom(myZoom)
			:xy(spriteX, spriteY)
			:diffusealpha(1)
	end
}

----------------------------------------------------
-- FILE 4 (GLITCH C)
----------------------------------------------------
t[#t+1] = Def.Sprite {
	Name="F4",
	Texture = file4,

	OnCommand=function(self)
		self:zoom(myZoom)
			:xy(spriteX, spriteY)
			:diffusealpha(1)
	end
}
---------------------------------------------------- 
-- GRAIN OVERLAY (ITGmania SAFE) 
---------------------------------------------------- 
t[#t+1] = Def.Sprite { 
	Texture = grain, 
	OnCommand=function(self) 
		self:FullScreen() 
			:visible(true) 
			:diffusealpha(0.05) 
			:queuecommand("Pulse") 
	end, 
	PulseCommand=function(self) 
		self:linear(glitchBeat / 2) 
			:diffusealpha(2) 
			:linear(glitchBeat / 2) 
			:diffusealpha(1)
		
		self:queuecommand("Pulse") 
	end 
}

return t
