-- Live lobby standings, shown once the lobby has released gameplay.

if not GetLobbyState().inLobby then
	return Def.Actor{}
end

local MAX_PLAYER_COUNT = 8
local Y_FROM_BOTTOM = 30

local playerNameTexts = {}
local scoreTexts = {}

local isDouble = GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides"

local QueueUpdate = function(self)
	if self.updateQueued then return end
	self.updateQueued = true
	self:queuecommand("UpdateScores")
end

local t = Def.ActorFrame{
	OnCommand=QueueUpdate,
	LobbyStatusChangedMessageCommand=QueueUpdate,
	LobbySyncChangedMessageCommand=QueueUpdate,
	LobbyScoresChangedMessageCommand=QueueUpdate,

	UpdateScoresCommand=function(self)
		self.updateQueued = false

		local lobby = GetLobbyState()
		self:visible(lobby.inLobby and not lobby.waiting)

		local scores = lobby.standings
		local count = math.min(#scores, MAX_PLAYER_COUNT)

		for i = 1, MAX_PLAYER_COUNT do
			local scoreIndex = i - (MAX_PLAYER_COUNT - count)

			if scoreIndex > 0 then
				local score = scores[scoreIndex]
				local textColor = score.failed and color("1,0.3,0.3,0.4") or color("1,1,1,0.5")
				playerNameTexts[i]:settext(score.name):diffuse(textColor)
				scoreTexts[i]:settext(FormatLobbyScore(score.score)):diffuse(textColor)
			else
				playerNameTexts[i]:settext("")
				scoreTexts[i]:settext("")
			end
		end
	end
}

for i = 1, MAX_PLAYER_COUNT do
	local playerIndex = MAX_PLAYER_COUNT - i + 1

	t[#t+1] = Def.BitmapText{
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			playerNameTexts[playerIndex] = self
			if isDouble then
				self:x(20)
				self:align(0, 0.5)
			else
				self:CenterX()
				self:align(0.5, 0.5)
			end

			self:zoom(0.75):maxwidth(120 / 0.75)
			self:y(SCREEN_HEIGHT - (i * 40) - Y_FROM_BOTTOM)
		end
	}

	t[#t+1] = Def.BitmapText{
		Font="Wendy/_wendy small",
		Text="",
		InitCommand=function(self)
			scoreTexts[playerIndex] = self
			if isDouble then
				self:x(20)
				self:align(0, 0.5)
			else
				self:CenterX()
				self:align(0.5, 0.5)
			end

			self:zoom(0.25)
			self:y(SCREEN_HEIGHT - (i * 40) - Y_FROM_BOTTOM + 15)
		end
	}
end

return t
