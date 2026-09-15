-- Seats the players a lobby controller calls to this cabinet's pads.
--
-- An assignSeats command turns each named side into a guest persona (a display
-- name, the player's tournament hub id and their modifiers) or, for a null
-- profile, into the placeholder guest of an empty pad. Nothing is loaded from
-- disk. Seats apply only on ScreenSelectMusic: a command received anywhere
-- else waits there, and a newer one replaces it.
--
-- Each called side shows a callout box and song select holds this cabinet's
-- input until every called side has pressed Start to check in. Check-in never
-- waits for other cabinets.

-- The name the core's IsPlaceholderSide recognises.
local PLACEHOLDER_NAME = "__EMPTY__"

local WIDTH = 320
local HEIGHT = 200
local BORDER = 4

-- seats["P1"] = { name, hubPlayerId, checkedIn, modifiersReported }
-- checkedIn is nil for a placeholder, which is never called.
local seats = {}
local queuedSeats = nil
local holding = false
local inputScreen = nil

local SeatOf = function(player)
	return seats[ToEnumShortString(player)]
end

local IsCalled = function(player)
	local seat = SeatOf(player)
	return GAMESTATE:IsHumanPlayer(player) and seat ~= nil and seat.checkedIn ~= nil
end

local IsAwaitingCheckIn = function(player)
	return IsCalled(player) and SeatOf(player).checkedIn == false
end

local AnySideAwaitingCheckIn = function()
	return IsAwaitingCheckIn(PLAYER_1) or IsAwaitingCheckIn(PLAYER_2)
end

local OnSongSelect = function()
	local screen = SCREENMAN:GetTopScreen()
	return screen ~= nil and screen:GetName() == "ScreenSelectMusic"
end

local SetInputRedirected = function(redirected)
	for player in ivalues(PlayerNumber) do
		SCREENMAN:set_input_redirected(player, redirected)
	end
end

-- -----------------------------------------------------------------------
-- Input hold

local UpdateInputHold

local CheckInInput = function(event)
	if not holding or event.type ~= "InputEventType_FirstPress" or event.GameButton ~= "Start" or not event.PlayerNumber then
		return false
	end
	if not IsAwaitingCheckIn(event.PlayerNumber) then
		return false
	end

	SeatOf(event.PlayerNumber).checkedIn = true
	MESSAGEMAN:Broadcast("LobbySeatsChanged")
	UpdateInputHold()
	MESSAGEMAN:Broadcast("UpdateMachineState")
	return false
end

-- The core releases redirection whenever its own lock clears, so the hold is
-- re-applied on every LobbySyncChanged; releasing it never frees the core's lock.
UpdateInputHold = function()
	if not OnSongSelect() then
		holding = false
		return
	end

	local lobby = GetLobbyState()
	if lobby.inLobby and AnySideAwaitingCheckIn() then
		holding = true
		SetInputRedirected(true)
		local screen = SCREENMAN:GetTopScreen()
		-- Input callbacks are dropped with their screen, so each screen gets one.
		if screen ~= inputScreen then
			screen:AddInputCallback(CheckInInput)
			inputScreen = screen
		end
	elseif holding then
		holding = false
		if not lobby.waiting then
			SetInputRedirected(false)
		end
	end
end

-- -----------------------------------------------------------------------
-- Seats

local SetGuestName = function(player, name)
	local profile = PROFILEMAN:GetProfile(player)
	if profile then
		profile:SetDisplayName(name)
	end
end

local SeatSide = function(player, profile)
	local pn = ToEnumShortString(player)

	if PROFILEMAN:IsPersistentProfile(player) then
		-- Unjoining the only joined side would leave song select without a player.
		if not GAMESTATE:IsSideJoined(OtherPlayer[player]) then
			SM(("%s holds a local profile. Unload it to seat the lobby's player on this pad."):format(pn))
			return false
		end
		GAMESTATE:UnjoinPlayer(player)
	end

	if not GAMESTATE:IsSideJoined(player) then
		GAMESTATE:JoinPlayer(player)
		if not GAMESTATE:IsSideJoined(player) then
			return false
		end
	end

	local name = PLACEHOLDER_NAME
	local hubPlayerId = nil
	local checkedIn = nil
	if profile ~= nil then
		name = profile.displayName
		hubPlayerId = tonumber(profile.hubPlayerId)
		checkedIn = false
	end

	SetGuestName(player, name)
	seats[pn] = { name = name, hubPlayerId = hubPlayerId, checkedIn = checkedIn, modifiersReported = false }

	-- Song select resets a guest when its profile is set, so the persona's
	-- modifiers are applied only after that has happened.
	MESSAGEMAN:Broadcast("PlayerProfileSet", { Player = player })
	LoadGuest(player)
	if profile ~= nil and type(profile.modifiers) == "table" then
		ApplyProfileSettings(player, profile.modifiers)
	end
	ApplyMods(player)
	return true
end

local QueueSeats = function(assignments)
	if type(assignments) ~= "table" then
		return
	end

	local queued = {}
	for assignment in ivalues(assignments) do
		if type(assignment) == "table" and (assignment.playerId == "P1" or assignment.playerId == "P2") then
			local profile = assignment.profile
			if type(profile) ~= "table" or type(profile.displayName) ~= "string" or profile.displayName == "" then
				profile = nil
			end
			queued[assignment.playerId] = { profile = profile }
		end
	end
	queuedSeats = queued
end

local ApplyQueuedSeats = function()
	if queuedSeats == nil or not OnSongSelect() then
		return
	end

	local queued = queuedSeats
	queuedSeats = nil
	local applied = false
	for player in ivalues({ PLAYER_1, PLAYER_2 }) do
		local seat = queued[ToEnumShortString(player)]
		if seat ~= nil then
			applied = SeatSide(player, seat.profile) or applied
		end
	end

	if applied then
		MESSAGEMAN:Broadcast("LobbySeatsChanged")
		UpdateInputHold()
		MESSAGEMAN:Broadcast("UpdateMachineState")
	end
end

local ClearSeat = function(player)
	local pn = ToEnumShortString(player)
	if seats[pn] == nil then
		return
	end
	seats[pn] = nil
	-- The engine keeps a guest profile's name across games.
	if not PROFILEMAN:IsPersistentProfile(player) then
		SetGuestName(player, "")
	end
	MESSAGEMAN:Broadcast("LobbySeatsChanged")
end

RegisterLobbyCommand("assignSeats", function(payload)
	QueueSeats(payload.seats)
	ApplyQueuedSeats()
end)

RegisterLobbyPlayerFields("assignSeat", function(player, screenName)
	local seat = SeatOf(player)
	if seat == nil then
		return nil
	end

	local fields = { checkedIn = seat.checkedIn, hubPlayerId = seat.hubPlayerId }
	-- A seated player's modifiers go back to the hub once per stage, from evaluation.
	if screenName == "ScreenEvaluationStage" and seat.hubPlayerId ~= nil and not seat.modifiersReported then
		seat.modifiersReported = true
		fields.modifiers = ProfileSettingsOf(player)
	end
	return fields
end)

-- -----------------------------------------------------------------------
-- Callout
-- &START; is drawn by the fonts as the green Start button.

local QueueRefresh = function(self)
	if self.refreshQueued then return end
	self.refreshQueued = true
	self:queuecommand("Refresh")
end

local CalloutShown = function()
	return GetLobbyState().inLobby and AnySideAwaitingCheckIn()
end

local CheckInCounts = function()
	local checkedIn, called = 0, 0
	for player in ivalues({ PLAYER_1, PLAYER_2 }) do
		if IsCalled(player) then
			called = called + 1
			if SeatOf(player).checkedIn then
				checkedIn = checkedIn + 1
			end
		end
	end
	return checkedIn, called
end

local Callout = function(player)
	local pn = ToEnumShortString(player)

	return Def.ActorFrame{
		InitCommand=function(self)
			self:xy(_screen.cx + (player == PLAYER_1 and -1 or 1) * _screen.w / 4, _screen.cy):visible(false)
		end,
		ModuleCommand=QueueRefresh,
		LobbyStatusChangedMessageCommand=QueueRefresh,
		LobbySeatsChangedMessageCommand=QueueRefresh,
		RefreshCommand=function(self)
			self.refreshQueued = false

			local shown = CalloutShown() and IsCalled(player)
			self:visible(shown)
			if not shown then return end

			local seat = SeatOf(player)
			local checkedIn, called = CheckInCounts()
			self:GetChild("Name"):settext(seat.name)
			self:GetChild("Prompt"):visible(not seat.checkedIn)
			self:GetChild("CheckedIn"):visible(seat.checkedIn)
			self:GetChild("Count"):settext(("%d/%d pads checked in"):format(checkedIn, called))
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
				self:settext(("PAD %s  -  CABINET %s"):format(pn, GetCabinetId()))
				self:y(-HEIGHT / 2 + 16):zoom(0.7):diffuse(0.75, 0.75, 0.75, 1)
			end,
		},

		LoadFont("Common Normal")..{
			Name="Name",
			InitCommand=function(self)
				self:y(-HEIGHT / 2 + 48):zoom(1.4):maxwidth((WIDTH - 20) / 1.4)
				self:diffuse(PlayerColor(player))
			end,
		},

		Def.ActorFrame{
			Name="Prompt",

			LoadFont("Common Bold")..{
				Text="STEP ON THIS PAD AND PRESS",
				InitCommand=function(self)
					self:y(-8):zoom(0.45)
				end,
			},

			LoadFont("Common Bold")..{
				Text="&START;",
				InitCommand=function(self)
					self:y(28):zoom(1.1)
					self:pulse():effectmagnitude(1, 1.15, 1):effectperiod(0.9)
				end,
			},

			LoadFont("Common Bold")..{
				Text="TO CHECK IN",
				InitCommand=function(self)
					self:y(62):zoom(0.45)
				end,
			},
		},

		LoadFont("Common Bold")..{
			Name="CheckedIn",
			Text="CHECKED IN!",
			InitCommand=function(self)
				self:y(24):zoom(0.9):diffuse(color("0.3,1,0.3,1")):visible(false)
			end,
		},

		LoadFont("Common Normal")..{
			Name="Count",
			Text="",
			InitCommand=function(self)
				self:y(HEIGHT / 2 - 14):zoom(0.8):diffuse(0.75, 0.75, 0.75, 1)
			end,
		},
	}
end

-- -----------------------------------------------------------------------
-- Screens

local t = {}

-- Module actors live in ScreenSystemLayer and keep receiving messages on every
-- screen, so seats are cleared whenever a side is unjoined.
t["ScreenSelectMusic"] = Def.ActorFrame{
	ModuleCommand=function(self)
		ApplyQueuedSeats()
		UpdateInputHold()
		QueueRefresh(self)
	end,
	LobbyStatusChangedMessageCommand=function(self)
		UpdateInputHold()
		QueueRefresh(self)
	end,
	LobbySyncChangedMessageCommand=function(self)
		UpdateInputHold()
	end,
	LobbySeatsChangedMessageCommand=QueueRefresh,
	PlayerUnjoinedMessageCommand=function(self, params)
		ClearSeat(params.Player)
		UpdateInputHold()
	end,
	RefreshCommand=function(self)
		self.refreshQueued = false
		self:GetChild("Dim"):visible(CalloutShown())
	end,

	Def.Quad{
		Name="Dim",
		InitCommand=function(self)
			self:FullScreen():diffuse(0, 0, 0, 0.6):visible(false)
		end,
	},

	Callout(PLAYER_1),
	Callout(PLAYER_2),
}

t[Branch.GameplayScreen()] = Def.Actor{
	ModuleCommand=function(self)
		for _, seat in pairs(seats) do
			seat.modifiersReported = false
		end
	end,
}

return t
