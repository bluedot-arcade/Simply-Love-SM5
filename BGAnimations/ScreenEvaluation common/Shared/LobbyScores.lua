-- Final lobby standings, shown once every player in the lobby has reached evaluation.

if not GetLobbyState().inLobby then
	return Def.Actor{}
end

local MAX_PLAYER_COUNT = 8
local ROWS = 4
local CELL_WIDTH = 110
local CELL_HEIGHT = 20
local COL_DISTANCE = 140

local Y_POS = 112
local INIT_X = _screen.cx - (CELL_WIDTH + COL_DISTANCE) / 2
local INIT_Y = Y_POS - (CELL_HEIGHT * (ROWS - 1)) / 2

local BACKGROUND_MARGIN = 10

local playerNameTexts = {}
local scoreTexts = {}

-- Once shown, the standings stay: players leaving for the next song must not
-- take the leaderboard with them.
local showingFinal = false

local QueueUpdate = function(self)
	if self.updateQueued then return end
	self.updateQueued = true
	self:queuecommand("UpdateScores")
end

local t = Def.ActorFrame{
	OnCommand=QueueUpdate,
	LobbyStatusChangedMessageCommand=QueueUpdate,
	LobbyRosterChangedMessageCommand=QueueUpdate,
	LobbyScoresChangedMessageCommand=QueueUpdate,

	UpdateScoresCommand=function(self)
		self.updateQueued = false

		local lobby = GetLobbyState()
		self:visible(showingFinal or lobby.inLobby)

		if lobby.allInEvaluation then
			showingFinal = true
			local scores = lobby.standings

			for i = 1, MAX_PLAYER_COUNT do
				local score = scores[i]
				if score then
					local textColor = score.failed and color("1,0.3,0.3,0.8") or Color.White
					playerNameTexts[i]:settext(score.name):diffuse(textColor)
					scoreTexts[i]:settext(FormatLobbyScore(score.score)):diffuse(textColor)
				else
					playerNameTexts[i]:settext("")
					scoreTexts[i]:settext("")
				end
			end
		end

		local waitingText = self:GetChild("WaitingText")
		waitingText:visible(not showingFinal)
		if not showingFinal then
			waitingText:settext(("Waiting for players...\n%d/%d in evaluation"):format(lobby.playersInEvaluation, #lobby.players))
		end
	end
}

t[#t+1] = Def.Quad{
	InitCommand=function(self)
		self:xy(_screen.cx, Y_POS)
		self:zoom(0.7)
		self:setsize(418 - BACKGROUND_MARGIN, 164 - BACKGROUND_MARGIN)
		self:diffuse(0, 0, 0, 0.80)
	end
}

t[#t+1] = Def.BitmapText{
	Name="WaitingText",
	Font="Miso/_miso light",
	Text="",
	InitCommand=function(self)
		self:xy(_screen.cx, Y_POS):zoom(0.9)
	end
}

for i = 1, MAX_PLAYER_COUNT do
	local col = math.floor((i - 1) / ROWS)
	local row = (i - 1) % ROWS

	t[#t+1] = Def.BitmapText{
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			playerNameTexts[i] = self
			self:x(INIT_X + (col * COL_DISTANCE))
			self:y(INIT_Y + row * CELL_HEIGHT)
			self:align(0, 0.5)
			self:zoom(0.75):maxwidth(80 / 0.75)
		end
	}

	t[#t+1] = Def.BitmapText{
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			scoreTexts[i] = self
			self:x(INIT_X + (col * COL_DISTANCE) + CELL_WIDTH)
			self:y(INIT_Y + row * CELL_HEIGHT)
			self:align(1, 0.5)
			self:zoom(0.75)
		end
	}
end

return t
