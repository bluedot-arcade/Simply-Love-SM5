-- A ready-up box over each local player's notefield, shown while the lobby holds
-- gameplay until everyone is ready. &START; is drawn by the fonts as the green
-- Start button.

if not GetLobbyState().inLobby then
	return Def.Actor{}
end

local WIDTH = 260
local HEIGHT = 190
local BORDER = 4

local QueueRefresh = function(self)
	if self.refreshQueued then return end
	self.refreshQueued = true
	self:queuecommand("Refresh")
end

local ReadyCounts = function(lobby)
	local localPlayerOfEntry = {}
	for player in ivalues(GAMESTATE:GetHumanPlayers()) do
		local entry = GetLobbyEntryForPlayer(player)
		if entry then
			localPlayerOfEntry[entry] = ToEnumShortString(player)
		end
	end

	local ready = 0
	for entry in ivalues(lobby.players) do
		local pn = localPlayerOfEntry[entry]
		-- A local press counts right away, before the server echoes it back.
		local isReady
		if pn then
			isReady = lobby.localReady[pn] == true
		else
			isReady = entry.ready
		end
		if isReady then
			ready = ready + 1
		end
	end
	return ready, #lobby.players
end

local NotefieldX = function(player)
	local playerAF = SCREENMAN:GetTopScreen():GetChild("Player" .. ToEnumShortString(player))
	if playerAF then
		return playerAF:GetX()
	end
	return _screen.cx + (player == PLAYER_1 and -1 or 1) * _screen.w / 4
end

local ReadyBox = function(player)
	local pn = ToEnumShortString(player)

	return Def.ActorFrame{
		InitCommand=function(self)
			self:y(_screen.cy)
		end,
		OnCommand=function(self)
			self:x(NotefieldX(player))
			QueueRefresh(self)
		end,
		LobbyStatusChangedMessageCommand=QueueRefresh,
		LobbySyncChangedMessageCommand=QueueRefresh,
		RefreshCommand=function(self)
			self.refreshQueued = false

			local lobby = GetLobbyState()
			if not (lobby.inLobby and lobby.waiting) then return end

			local isReady = lobby.localReady[pn] == true
			local ready, total = ReadyCounts(lobby)
			self:GetChild("Prompt"):visible(not isReady)
			self:GetChild("Ready"):visible(isReady)
			self:GetChild("Count"):settext(("%d/%d players ready"):format(ready, total))
		end,

		Def.Quad{
			InitCommand=function(self)
				self:zoomto(WIDTH + BORDER * 2, HEIGHT + BORDER * 2):diffuse(PlayerColor(player))
			end,
		},

		Def.Quad{
			InitCommand=function(self)
				self:zoomto(WIDTH, HEIGHT):diffuse(0, 0, 0, 0.92)
			end,
		},

		LoadFont("Common Normal")..{
			InitCommand=function(self)
				local name = PROFILEMAN:GetPlayerName(player)
				self:settext(name ~= "" and name or pn)
				self:y(-HEIGHT / 2 + 20):zoom(1.1):maxwidth((WIDTH - 20) / 1.1)
				self:diffuse(PlayerColor(player))
			end,
		},

		Def.ActorFrame{
			Name="Prompt",

			LoadFont("Common Bold")..{
				Text="PRESS",
				InitCommand=function(self)
					self:y(-40):zoom(0.5)
				end,
			},

			LoadFont("Common Bold")..{
				Text="&START;",
				InitCommand=function(self)
					self:y(5):zoom(1.2)
					self:pulse():effectmagnitude(1, 1.15, 1):effectperiod(0.9)
				end,
			},

			LoadFont("Common Bold")..{
				Text="TO READY UP",
				InitCommand=function(self)
					self:y(48):zoom(0.5)
				end,
			},
		},

		LoadFont("Common Bold")..{
			Name="Ready",
			Text="READY!",
			InitCommand=function(self)
				self:y(0):zoom(0.9):diffuse(color("0.3,1,0.3,1")):visible(false)
			end,
		},

		LoadFont("Common Normal")..{
			Name="Count",
			Text="",
			InitCommand=function(self)
				self:y(HEIGHT / 2 - 18):zoom(0.9):diffuse(0.75, 0.75, 0.75, 1)
			end,
		},
	}
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		self:visible(false)
	end,
	OnCommand=QueueRefresh,
	LobbyStatusChangedMessageCommand=QueueRefresh,
	LobbySyncChangedMessageCommand=QueueRefresh,
	RefreshCommand=function(self)
		self.refreshQueued = false
		local lobby = GetLobbyState()
		self:visible(lobby.inLobby and lobby.waiting)
	end,

	Def.Quad{
		InitCommand=function(self)
			self:FullScreen():diffuse(0, 0, 0, 0.6)
		end,
	},
}

for player in ivalues(GAMESTATE:GetHumanPlayers()) do
	af[#af+1] = ReadyBox(player)
end

return af
