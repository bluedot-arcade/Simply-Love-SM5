-- Lobby code, players and their screens, drawn over the song banner while in a lobby.

local MAX_PLAYERS = 8
local ROWS = 4
local WIDTH = 418
local HEIGHT = 164
local COLUMN_X = { -196, 12 }
local COLUMN_WIDTH = 184
local FIRST_ROW_Y = -34
local ROW_HEIGHT = 24

local nameTexts = {}
local screenTexts = {}

local QueueRefresh = function(self)
	if self.refreshQueued then return end
	self.refreshQueued = true
	self:queuecommand("Refresh")
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		if IsUsingWideScreen() then
			self:zoom(0.7655):xy(_screen.cx - 170, 96)
		else
			self:zoom(0.75):xy(_screen.cx - 166, 96)
		end
		self:visible(false)
		QueueRefresh(self)
	end,
	LobbyStatusChangedMessageCommand=QueueRefresh,
	LobbyRosterChangedMessageCommand=QueueRefresh,
	LobbySongChangedMessageCommand=QueueRefresh,
	LobbySyncChangedMessageCommand=QueueRefresh,
	RefreshCommand=function(self)
		self.refreshQueued = false

		local lobby = GetLobbyState()
		self:visible(lobby.inLobby)
		if not lobby.inLobby then return end

		self:GetChild("Title"):settext("Lobby " .. (lobby.code or ""))

		for i = 1, MAX_PLAYERS do
			local player = lobby.players[i]
			nameTexts[i]:settext(player and player.name or "")
			screenTexts[i]:settext(player and player.screenLabel or "")
		end

		local status = ""
		if lobby.waiting then
			status = "Waiting for players to sync screens..."
		elseif lobby.songInfo ~= nil then
			status = "Song: " .. (lobby.songInfo.title or lobby.songInfo.songPath)
		end
		self:GetChild("Status"):settext(status)
	end,

	Def.Quad{
		InitCommand=function(self)
			self:zoomto(WIDTH, HEIGHT):diffuse(0, 0, 0, 0.85)
		end,
	},

	Def.BitmapText{
		Name="Title",
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			self:y(-62):zoom(1.1)
		end,
	},

	Def.BitmapText{
		Name="Status",
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			self:y(62):zoom(0.8):maxwidth((WIDTH - 20) / 0.8):diffuse(Color.Yellow)
		end,
	},
}

for i = 1, MAX_PLAYERS do
	local column = math.floor((i - 1) / ROWS) + 1
	local y = FIRST_ROW_Y + ((i - 1) % ROWS) * ROW_HEIGHT

	af[#af+1] = Def.BitmapText{
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			nameTexts[i] = self
			self:xy(COLUMN_X[column], y):halign(0):zoom(0.9):maxwidth(120 / 0.9)
		end,
	}

	af[#af+1] = Def.BitmapText{
		Font="Miso/_miso light",
		Text="",
		InitCommand=function(self)
			screenTexts[i] = self
			self:xy(COLUMN_X[column] + COLUMN_WIDTH, y):halign(1):zoom(0.7):maxwidth(60 / 0.7)
			self:diffuse(0.7, 0.7, 0.7, 1)
		end,
	}
end

return af
