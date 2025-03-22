return LoadFont("Common Bold")..{
	Text="Demo",
	InitCommand=function(self) self:Center():diffusealpha(0):shadowlength(1) end,
	OnCommand=function(self)
		self:accelerate(0.5):diffusealpha(1):sleep(0.66):accelerate(0.33)
		self:zoom(0.8):y(_screen.h-150)
	end
}