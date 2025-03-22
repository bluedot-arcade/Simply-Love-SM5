-- mostly adapted from normal.lua so this is kind of a freaking mess, not gonna lie

local file = ...

local file1 = "./ITG/abstract_lines_1su3.png"
local file2 = "./ITG/abstract_lines_2su3.png"
local file3 = "./ITG/abstract_lines_3su3.png"

local file1_inv = "./ITG/abstract_lines_1su3_inv.png"
local file2_inv = "./ITG/abstract_lines_2su3_inv.png"
local file3_inv = "./ITG/abstract_lines_3su3_inv.png"

local t = Def.ActorFrame {
	InitCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		self:visible(style == "ITG")
	end,
	OnCommand=function(self) self:fov(90):diffusealpha(1) end,
	HideCommand=function(self) self:visible(false) end,

	ScreenChangedMessageCommand=function(self)

		
		local screen = SCREENMAN:GetTopScreen()
		if screen then
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
		
			-- Check if the current screen is in the list and dim it
			for _, screenName in ipairs(screensToDim) do
				if name == screenName then
					self:diffusealpha(0.5)
					break  -- Exit the loop once we find a match
				end
			end
		end
	
	end,
    -- Altri elementi o comandi dell'ActorFrame
	

	VisualStyleSelectedMessageCommand=function(self)
		local style = ThemePrefs.Get("VisualStyle")
		if style == "ITG" then
			self:visible(true):linear(0.6):diffusealpha(1)
		else
			self:linear(0.6):diffusealpha(0):queuecommand("Hide")
		end
	end,

    LoopCommand=function(self)
		index = index + 1
		self:queuecommand("NewColor"):sleep(delay):queuecommand("Loop")
	end,
}

-- background
t[#t+1] = Def.Quad {
	InitCommand=function(self)
		self:diffuse(20/255, 20/255, 20/255, 1):zoomto(SCREEN_WIDTH, SCREEN_HEIGHT):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0)
		end
	end
}

local myZoom = 0.442
local delta = SCREEN_HEIGHT / 3

-- grid i think
t[#t+1] = Def.Sprite {
	Texture = file1,
	OnCommand=function(self)
		
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.10, 0)
		:diffusealpha(0.2)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}
t[#t+1] = Def.Sprite {
	Texture = file2,
	OnCommand=function(self)
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.03, 0)
		:diffusealpha(0.5)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}
t[#t+1] = Def.Sprite {
	Texture = file3,
	OnCommand=function(self)
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y - delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.08, 0)
		:diffusealpha(0.8)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}

t[#t+1] = Def.Sprite {
	Texture = file1_inv,
	OnCommand=function(self)
	
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.10, 0)
		:diffusealpha(0.2)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}
t[#t+1] = Def.Sprite {
	Texture = file2_inv,
	OnCommand=function(self)
	
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.03, 0)
		:diffusealpha(0.5)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}
t[#t+1] = Def.Sprite {
	Texture = file3_inv,
	OnCommand=function(self)
	
		self:zoom(myZoom):xy(SCREEN_CENTER_X, SCREEN_CENTER_Y + delta)
		--:customtexturerect(0,0,60,60)
		:texcoordvelocity(-0.08, 0)
		:diffusealpha(0.8)
        if ThemePrefs.Get("RainbowMode") then
			self:diffusealpha(0.15)
		end
	end
}

return t