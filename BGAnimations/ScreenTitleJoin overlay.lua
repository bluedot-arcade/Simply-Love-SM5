-- Pad arrows R L, RR LL, RRR LLL open the pack manager, but only while a USB drive
-- with the pack manager key file is plugged in.
local PACK_MANAGER_CODE = "RLRRLLRRRLLL"
local packs = LoadActor("ScreenPackManager overlay/packs.lua")
local pressed = ""

local function code_input(event)
	if event.type ~= "InputEventType_FirstPress" then return false end
	local arrow = ({ Left = "L", Right = "R" })[event.button]
	pressed = arrow and (pressed .. arrow):sub(-#PACK_MANAGER_CODE) or ""
	if pressed == PACK_MANAGER_CODE and packs.usb_has_key() then
		local screen = SCREENMAN:GetTopScreen()
		screen:SetNextScreenName("ScreenPackManagerTitle")
		screen:StartTransitioningScreen("SM_GoToNextScreen")
	end
	return false
end

return LoadFont("Common Bold")..{
	InitCommand=function(self)
		self:xy(_screen.cx,_screen.h-80):zoom(0.7):shadowlength(0.75)
		self:visible(false):queuecommand("Refresh")
	end,
	OnCommand=function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(code_input)
		self:diffuseshift():effectperiod(1.333)
		self:effectcolor1(1,1,1,0):effectcolor2(1,1,1,1)
	end,
	OffCommand=function(self) self:visible(false) end,

	CoinsChangedMessageCommand=function(self) self:queuecommand("Refresh") end,
	CoinModeChangedMessageCommand=function(self) self:queuecommand("Refresh") end,

	RefreshCommand=function(self)
		self:visible( not IsHome() )

		if GAMESTATE:GetCoinMode() == "CoinMode_Free" then
		 	self:settext( THEME:GetString("ScreenTitleJoin", "Press Start") )
			return
		end

		if GetCredits().Credits <= 0 then
			self:settext( THEME:GetString("ScreenLogo", "EnterCreditsToPlay") )
		else
		 	self:settext( THEME:GetString("ScreenTitleJoin", "Press Start") )
		end
	end
}