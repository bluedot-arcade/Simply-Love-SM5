-- -----------------------------------------------------------------------
-- Online lobbies.
--
-- This file owns the websocket connection and the lobby protocol. The rest of
-- the theme never handles protocol messages: it reads GetLobbyState() and
-- reacts to these messages, each broadcast only when what it describes changed:
--
--   LobbyStatusChanged   connection, lobby membership, or lobby code
--   LobbyRosterChanged   players joining, leaving, or changing screen/ready
--   LobbySongChanged     the song selected for the lobby
--   LobbySyncChanged     the input lock, or anyone's ready state
--   LobbyScoresChanged   standings, or whether everyone reached evaluation
--
-- The LobbyUpdateInterval theme pref limits how often machine state is sent
-- during gameplay and how often lobby state is processed; 0 handles every one.
-- -----------------------------------------------------------------------

local host = "syncservice.groovestats.com"
local port = 1337

local isWaiting = false
local readyState = {
  ["P1"] = true,
  ["P2"] = true
}
local songSelected = false
-- Track Start button hold time for disconnect
local startHoldTime = {
  ["P1"] = 0,
  ["P2"] = 0
}
local lastDisconnectCountdown = nil

local scoreScreens = {
  ["ScreenGameplay"] = true,
  ["ScreenGameplayShared"] = true,
  ["ScreenEvaluationStage"] = true,
}

local syncLockScreens = {
  ["ScreenSelectMusic"] = true,
  ["ScreenGameplay"] = true,
  ["ScreenGameplayShared"] = true,
  ["ScreenEvaluationStage"] = true,
}

local autoReadyScreens = {
  ["ScreenSelectMusic"] = true,
  ["ScreenEvaluationStage"] = true,
}

local knownDisconnectScreens = {
  ["ScreenTitleMenu"] = true,
  ["ScreenGameOver"] = true,
  ["ScreenNameEntryTraditional"] = true,
  ["ScreenOptionsService"] = true,
}

local screenLabels = {
  ["NoScreen"] = "Transitioning",
  ["ScreenSelectMusic"] = "Select Music",
  ["ScreenPlayerOptions"] = "Options",
  ["ScreenPlayerOptions2"] = "Options",
  ["ScreenPlayerOptions3"] = "Options",
  ["ScreenGameplay"] = "Gameplay",
  ["ScreenGameplayShared"] = "Gameplay",
  ["ScreenEvaluationStage"] = "Evaluation",
}

-- Only allow one instance of the online handler at a time.
-- Things can get a bit convoluted if we have many handlers trying to manage
-- multiple connections.
local onlineHandler = nil
local onlineHandlerInstance = nil
local onlineHandlerShuttingDown = false

GetOnlineHandlerInstance = function()
  return onlineHandlerInstance
end

local TopScreenName = function()
  local screen = SCREENMAN:GetTopScreen()
  return screen and screen:GetName() or "NoScreen"
end

local LocalProfileName = function(player)
  if PROFILEMAN:IsPersistentProfile(player) and PROFILEMAN:GetProfile(player) then
    return PROFILEMAN:GetProfile(player):GetDisplayName()
  end
  return "NoName"
end

local InLobbySession = function()
  local handler = onlineHandlerInstance
  return handler ~= nil and handler.connected and handler.socket ~= nil and handler.inLobby
end

-- -----------------------------------------------------------------------
-- Lobby model

local lobby = {
  connected = false,
  inLobby = false,
  code = nil,
  songInfo = nil,
  -- every player in the lobby, in server order
  players = {},
  -- players on a score screen, best score first
  standings = {},
  playersInEvaluation = 0,
  waiting = false,
  localReady = readyState,
  allReady = true,
  allInSameScreen = true,
  anyInGameplay = false,
  allInEvaluation = false,
}

GetLobbyState = function()
  return lobby
end

FormatLobbyScore = function(score)
  return score and ("%.2f%%"):format(score) or "--"
end

local lastBroadcastSignatures = {}

local BroadcastIfChanged = function(message, signature)
  if lastBroadcastSignatures[message] == signature then
    return
  end
  lastBroadcastSignatures[message] = signature
  MESSAGEMAN:Broadcast(message)
end

local SetLobbyStatus = function(connected, inLobby, code)
  if lobby.connected == connected and lobby.inLobby == inLobby and lobby.code == code then
    return
  end
  lobby.connected = connected
  lobby.inLobby = inLobby
  lobby.code = code
  MESSAGEMAN:Broadcast("LobbyStatusChanged")
end

local BroadcastSyncChanged = function()
  lobby.waiting = isWaiting

  local parts = { tostring(isWaiting), tostring(readyState["P1"]), tostring(readyState["P2"]) }
  for player in ivalues(lobby.players) do
    parts[#parts+1] = player.name .. ":" .. tostring(player.ready)
  end
  BroadcastIfChanged("LobbySyncChanged", table.concat(parts, "|"))
end

local BroadcastModelChanges = function()
  local roster = { lobby.code or "" }
  for player in ivalues(lobby.players) do
    roster[#roster+1] = ("%s:%s:%s:%s"):format(player.id, player.name, player.screen, tostring(player.ready))
  end
  BroadcastIfChanged("LobbyRosterChanged", table.concat(roster, "|"))

  BroadcastIfChanged("LobbySongChanged", lobby.songInfo and lobby.songInfo.songPath or "")

  local scores = { tostring(lobby.allInEvaluation) }
  for player in ivalues(lobby.standings) do
    scores[#scores+1] = ("%s:%s:%s:%s:%s"):format(player.id, player.name, FormatLobbyScore(player.exScore), FormatLobbyScore(player.itgScore), tostring(player.failed))
  end
  BroadcastIfChanged("LobbyScoresChanged", table.concat(scores, "|"))

  BroadcastSyncChanged()
end

local ClearLobbyModel = function()
  lobby.songInfo = nil
  lobby.players = {}
  lobby.standings = {}
  lobby.playersInEvaluation = 0
  lobby.allReady = true
  lobby.allInSameScreen = true
  lobby.anyInGameplay = false
  lobby.allInEvaluation = false
  BroadcastModelChanges()
end

local CompareStandings = function(a, b)
  if a.score ~= b.score then
    if a.score == nil then return false end
    if b.score == nil then return true end
    return a.score > b.score
  end
  if a.name ~= b.name then
    return a.name < b.name
  end
  return a.id < b.id
end

local UpdateLobbyModel = function(data)
  local localScreen = TopScreenName()
  local useExScore = ThemePrefs.Get("ScoringSystem") == "EX"
  local players = {}
  local standings = {}
  local playersInEvaluation = 0

  lobby.allReady = true
  lobby.allInSameScreen = true
  lobby.anyInGameplay = false

  -- The server's players array can contain nil gaps, where ipairs and # stop.
  local serverPlayers = data.players or {}
  for i = 1, table.maxn(serverPlayers) do
    local entry = serverPlayers[i]
    if type(entry) == "table" then
      local player = {
        id = entry.playerId or "",
        name = entry.profileName or "NoName",
        screen = entry.screenName or "NoScreen",
        ready = entry.ready == true,
        failed = entry.isFailed == true,
      }
      player.exScore = entry.exScore
      player.itgScore = entry.score
      if useExScore then
        player.score = player.exScore
      else
        player.score = player.itgScore
      end
      player.screenLabel = screenLabels[player.screen] or (player.screen:gsub("^Screen", ""))
      players[#players+1] = player

      if player.screen ~= localScreen then
        lobby.allInSameScreen = false
      end
      if player.screen == Branch.GameplayScreen() then
        lobby.anyInGameplay = true
      end
      if not player.ready then
        lobby.allReady = false
      end
      if player.screen == "ScreenEvaluationStage" then
        playersInEvaluation = playersInEvaluation + 1
      end
      if scoreScreens[player.screen] then
        standings[#standings+1] = player
      end
    end
  end

  table.sort(standings, CompareStandings)

  lobby.songInfo = data.songInfo
  lobby.players = players
  lobby.standings = standings
  lobby.playersInEvaluation = playersInEvaluation
  lobby.allInEvaluation = #players > 0 and playersInEvaluation == #players
end

GetLobbyEntryForPlayer = function(player)
  local id = ToEnumShortString(player)
  local name = LocalProfileName(player)
  for entry in ivalues(lobby.players) do
    if entry.id == id and entry.name == name then
      return entry
    end
  end
  return nil
end

IsLobbyLocalOnly = function()
  local humanPlayers = GAMESTATE:GetHumanPlayers()
  if #lobby.players == 0 or #lobby.players ~= #humanPlayers then
    return false
  end

  local localKeys = {}
  for player in ivalues(humanPlayers) do
    localKeys[ToEnumShortString(player) .. ":" .. LocalProfileName(player)] = true
  end
  for player in ivalues(lobby.players) do
    if not localKeys[player.id .. ":" .. player.name] then
      return false
    end
  end
  return true
end

-- -----------------------------------------------------------------------
-- Input lock and song sync

local ReleaseInputLock = function(screenName)
  isWaiting = false

  -- The below does work, but it's currently possible that other screens are resetting this early.
  for player in ivalues(PlayerNumber) do
    SCREENMAN:set_input_redirected(player, false)
  end

  if screenName == Branch.GameplayScreen() then
    SCREENMAN:GetTopScreen():PauseGame(false)
  end
end

local UpdateInputLock = function()
  if not isWaiting then
    return
  end

  local screenName = TopScreenName()
  local readyToUnlock = false
  if screenName == Branch.GameplayScreen() then
    -- Gameplay requires everyone to be in gameplay and manually ready-up.
    readyToUnlock = lobby.allInSameScreen and lobby.allReady
  elseif screenName == "ScreenEvaluationStage" then
    -- Evaluation should only be blocked while someone is still playing.
    readyToUnlock = not lobby.anyInGameplay
  elseif autoReadyScreens[screenName] then
    -- Other auto-ready screens require everyone to arrive at the same screen.
    readyToUnlock = lobby.allInSameScreen
  else
    readyToUnlock = lobby.allReady
  end

  -- Coming back to song selection after syncing (say from options) keeps input
  -- free, unless someone is still in evaluation and the lobby is moving on.
  if screenName == "ScreenSelectMusic" and lobby.songInfo ~= nil and lobby.playersInEvaluation == 0 then
    readyToUnlock = true
  end

  if readyToUnlock then
    ReleaseInputLock(screenName)
  end
end

local SelectLobbySong = function()
  local songInfo = lobby.songInfo
  if songInfo ~= nil and not songSelected then
    local topScreen = SCREENMAN:GetTopScreen()
    if topScreen and topScreen:GetName() == "ScreenSelectMusic" then
      local song = SONGMAN:FindSong(songInfo.songPath)
      local songFolder = songInfo.songPath:split("/")[2]
      if not song and songFolder then
        song = SONGMAN:FindSong(songFolder)
      end
      local wheel = topScreen:GetMusicWheel()
      if song and wheel then
        wheel:SelectSong(song)
        wheel:Move(1)
        wheel:Move(-1)
        wheel:Move(0)
      end
    end
  end

  -- This gets cleared out by the server when every player has arrived at the song selection screen.
  songSelected = (songInfo ~= nil)
end

-- -----------------------------------------------------------------------
-- Update throttling

local LobbyUpdateInterval = function()
  return (ThemePrefs.Get("LobbyUpdateInterval") or 0) / 1000
end

-- Runs work at most once per LobbyUpdateInterval: a request runs it right away
-- when the interval has already elapsed, otherwise once when the interval ends.
local CreateThrottle = function(work)
  local throttle = { pending = false, dueAt = nil, lastRunAt = nil, timer = nil }

  throttle.Run = function()
    throttle.dueAt = nil
    if not throttle.pending then
      return
    end
    throttle.pending = false
    throttle.lastRunAt = GetTimeSinceStart()
    work()
  end

  throttle.Request = function()
    throttle.pending = true
    local now = GetTimeSinceStart()

    -- A timer can lose its queued command when its tweens get cleared, so a
    -- long overdue run is treated as never scheduled.
    if throttle.dueAt ~= nil and now < throttle.dueAt + 1 then
      return
    end

    local remaining = 0
    if throttle.lastRunAt ~= nil then
      remaining = throttle.lastRunAt + LobbyUpdateInterval() - now
    end

    if remaining <= 0 or throttle.timer == nil then
      throttle.Run()
      return
    end

    throttle.dueAt = now + remaining
    throttle.timer:stoptweening():sleep(remaining):queuecommand("Run")
  end

  throttle.MarkRun = function()
    throttle.pending = false
    throttle.lastRunAt = GetTimeSinceStart()
  end

  throttle.Drop = function()
    throttle.pending = false
  end

  return throttle
end

-- -----------------------------------------------------------------------
-- Outgoing messages

local CreateRequest = function(event, data)
  return JsonEncode({
    event=event,
    data=data
  })
end

local GetJudgmentCounts = function(player)
  local counts = GetExJudgmentCounts(player)
  local translation = {
    ["W0"] = "fantasticPlus",
    ["W1"] = "fantastics",
    ["W2"] = "excellents",
    ["W3"] = "greats",
    ["W4"] = "decents",
    ["W5"] = "wayOffs",
    ["Miss"] = "misses",
    ["totalSteps"] = "totalSteps",
    ["Mines"] = "minesHit",
    ["totalMines"] = "totalMines",
    ["Holds"] = "holdsHeld",
    ["totalHolds"] = "totalHolds",
    ["Rolls"] = "rollsHeld",
    ["totalRolls"] = "totalRolls"
  }

  local judgmentCounts = {}

  for key, value in pairs(counts) do
    if translation[key] ~= nil then
      judgmentCounts[translation[key]] = value
    end
  end

  return judgmentCounts
end

local GetMachineState = function(params)
  -- NOTE(teejusb): Keep in mind that SCREENMAN:GetTopScreen() might return nil since we might be
  -- transitioning screens when we receive any messages from the server.

  if params == nil then
    params = {}
  end

  -- If the caller provided a screenName, use that instead of the current screen.
  local screenName = params.screenName or TopScreenName()

  local players = {}
  for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
    if GAMESTATE:IsSideJoined(player) then
      local judgments = nil
      local score = nil
      local exScore = nil
      local isFailed = nil
      if screenName == Branch.GameplayScreen() or screenName == "ScreenEvaluationStage" then
        local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
        judgments = GetJudgmentCounts(player)
        local dance_points = stats:GetPercentDancePoints()
        local percent = FormatPercentScore( dance_points ):gsub("%%", "")
        score = tonumber(percent)
        exScore = CalculateExScore(player)
        isFailed = stats:GetFailed()
      end

      local pn = ToEnumShortString(player)
      players[pn] = {
        playerId = pn,
        profileName = LocalProfileName(player),
        screenName=screenName,
        ready=readyState[pn],

        judgments = judgments,
        score = score,
        exScore = exScore,
        isFailed = isFailed,
        -- TODO(teejusb): Add song progression.
      }
    end
  end

  -- If "P1"/"P2" is missing from players, then the player isn't enabled and the corresponding
  -- player1/player2 key will be nil.
  return {
    machine = {
      player1=players["P1"],
      player2=players["P2"]
    }
  }
end

local SendMachineState = function(params)
  if InLobbySession() then
    onlineHandlerInstance.socket:Send(CreateRequest("updateMachine", GetMachineState(params)))
  end
end

local outboundThrottle = CreateThrottle(function()
  SendMachineState()
end)

local SendMachineStateNow = function(params)
  outboundThrottle.MarkRun()
  SendMachineState(params)
end

-- -----------------------------------------------------------------------
-- Incoming messages

local pendingLobbyStateJson = nil

local HandleLobbyState = function(data)
  if data == nil or onlineHandlerInstance == nil then
    return
  end

  onlineHandlerInstance.inLobby = true
  SetLobbyStatus(true, true, data.code)
  UpdateLobbyModel(data)
  UpdateInputLock()
  SelectLobbySong()
  MESSAGEMAN:Broadcast("OnlineLobbyState", data)
  BroadcastModelChanges()
end

local inboundThrottle = CreateThrottle(function()
  local json = pendingLobbyStateJson
  pendingLobbyStateJson = nil
  if json == nil then
    return
  end

  local response = JsonDecode(json)
  if response ~= nil then
    HandleLobbyState(response.data)
  end
end)

local LeaveLobbyModel = function()
  pendingLobbyStateJson = nil
  inboundThrottle.Drop()

  local handler = onlineHandlerInstance
  if handler ~= nil then
    handler.inLobby = false
  end
  SetLobbyStatus(handler ~= nil and handler.connected == true, false, nil)
  ClearLobbyModel()
end

local HandleResponse = function(response)
  if response == nil then
    return
  end

  local event = response.event
  local data = response.data

  if event == "lobbyState" then
    HandleLobbyState(data)
  elseif event == "lobbySearched" then
    MESSAGEMAN:Broadcast("LobbySearched", {
      lobbies = data and data.lobbies or {}
    })
  elseif event == "lobbyLeft" then
    LeaveLobbyModel()
    MESSAGEMAN:Broadcast("OnlineLobbyLeft", data or {})
  elseif event == "clientDisconnected" then
    LeaveLobbyModel()
    MESSAGEMAN:Broadcast("OnlineClientDisconnected", data or {})
  elseif event == "responseStatus" then
    MESSAGEMAN:Broadcast("OnlineResponseStatus", data or {})
  end
end

-- -----------------------------------------------------------------------
-- Input

-- This input handler is used to lock input while we're waiting on the server to tell us to proceed.
-- It does nothing, but it's necessary to prevent the player from interacting with the screen
-- until everyone is ready.
-- Holding Start for 5 seconds will disconnect from the lobby.
local InputHandler = function(event)
  if SCREENMAN:GetTopScreen() and isWaiting and event.PlayerNumber then
    local pn = ToEnumShortString(event.PlayerNumber)
    if event.type == "InputEventType_FirstPress" and event.GameButton == "Start" then
      startHoldTime[pn] = GetTimeSinceStart()
      lastDisconnectCountdown = nil
      if SCREENMAN:GetTopScreen():GetName() == Branch.GameplayScreen() then
        readyState[pn] = true
        BroadcastSyncChanged()
        SendMachineStateNow()
      end
    elseif event.type == "InputEventType_Repeat" and event.GameButton == "Start" then
      -- Check if Start has been held for 5 seconds
      if startHoldTime[pn] > 0 then
        local holdDuration = GetTimeSinceStart() - startHoldTime[pn]
        local remainingSeconds = math.max(0, 5 - math.floor(holdDuration))
        if remainingSeconds ~= lastDisconnectCountdown then
          SM("Continue holding &START; for " .. remainingSeconds .. " more seconds to disconnect...")
          lastDisconnectCountdown = remainingSeconds
        end
        if holdDuration >= 5.0 then
          SM("Disconnected from lobby.")
          startHoldTime[pn] = 0
          lastDisconnectCountdown = nil
          isWaiting = false
          if SCREENMAN:GetTopScreen():GetName() == Branch.GameplayScreen() then
            SCREENMAN:GetTopScreen():PauseGame(false)
          end
          MESSAGEMAN:Broadcast("DisconnectOnline")
        end
      end
    elseif event.type == "InputEventType_Release" and event.GameButton == "Start" then
      startHoldTime[pn] = 0
      lastDisconnectCountdown = nil
    end
  end

  return false
end

-- -----------------------------------------------------------------------
-- Handler actor

CreateOnlineHandler = function()
  if onlineHandler == nil then
    onlineHandler = Def.ActorFrame{
      Name="OnlineWebsocketHandler",
      InitCommand=function(self)
        onlineHandlerInstance = self
        onlineHandlerShuttingDown = false
        self.socket = nil
        self.connected = false
        self.inLobby = false
        self.errorMsg = nil
      end,
      OffCommand=function(self)
        onlineHandlerShuttingDown = true
        if self.socket ~= nil then
          self.socket:Close()
          self.socket = nil
        end
        self.connected = false
        self.errorMsg = nil
        LeaveLobbyModel()
        if onlineHandlerInstance == self then
          onlineHandlerInstance = nil
        end
      end,
      ConnectOnlineMessageCommand=function(self)
        if self.socket == nil or self.errorMsg ~= nil then
          onlineHandlerShuttingDown = false
          self.socket = NETWORK:WebSocket{
            url="ws://"..host..":"..port,
            pingInterval=15,
            automaticReconnect=true,
            onMessage=function(msg)
              if onlineHandlerShuttingDown then
                return
              end

              local msgType = ToEnumShortString(msg.type)
              if msgType == "Open" then
                self.connected = true
                self.inLobby = false
                self.errorMsg = nil
                SetLobbyStatus(true, false, nil)
              elseif msgType == "Message" then
                -- Each lobby state supersedes the previous one, so only the
                -- latest is decoded once the throttle lets it through.
                if msg.data:find('"event"%s*:%s*"lobbyState"') then
                  pendingLobbyStateJson = msg.data
                  inboundThrottle.Request()
                else
                  HandleResponse(JsonDecode(msg.data))
                end
              elseif msgType == "Close" then
                MESSAGEMAN:Broadcast("DisconnectOnline")
              elseif msgType == "Error" then
                self.errorMsg = msg.reason
                LeaveLobbyModel()
              end
            end,
          }
        end
      end,
      UpdateOnlineStateMessageCommand=function(self, params)
        SendMachineStateNow(params)
      end,
      ScreenChangedMessageCommand=function(self)
        if not InLobbySession() then
          return
        end

        local screenName = TopScreenName()

        if knownDisconnectScreens[screenName] then
          MESSAGEMAN:Broadcast("DisconnectOnline")
          return
        end

        -- Lock input while syncing arrival on key screens.
        if syncLockScreens[screenName] then
          isWaiting = true

          -- The below does work, but it's currently possible that other screens are resetting this early.
          for player in ivalues(PlayerNumber) do
            SCREENMAN:set_input_redirected(player, true)
          end
        end

        if autoReadyScreens[screenName] then
          for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
            readyState[ToEnumShortString(player)] = true
          end
        end

        if screenName == Branch.GameplayScreen() then
          -- Nobody else has to be waited for when the lobby is only this machine's players.
          local autoReady = IsLobbyLocalOnly()
          for player in ivalues(GAMESTATE:GetEnabledPlayers()) do
            readyState[ToEnumShortString(player)] = autoReady
          end
          -- Input callbacks get cleared out when we transition screens, so we don't need to worry about explicitly removing it.
          SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)
          SCREENMAN:GetTopScreen():PauseGame(true)
        elseif isWaiting then
          SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)
        end

        -- Components of the new screen may have read the model before this
        -- lock was applied, so they are always told about it.
        lastBroadcastSignatures["LobbySyncChanged"] = nil
        BroadcastSyncChanged()
        SendMachineStateNow()
      end,
      PlayerJoinedMessageCommand=function(self)
        SendMachineStateNow()
      end,
      PlayerUnjoinedMessageCommand=function(self)
        SendMachineStateNow()
      end,
      UpdateMachineStateMessageCommand=function(self)
        SendMachineStateNow()
      end,
      ExCountsChangedMessageCommand=function(self)
        if InLobbySession() then
          outboundThrottle.Request()
        end
      end,
      SongSelectedMessageCommand=function(self)
        if InLobbySession() then
          local song = GAMESTATE:GetCurrentSong()
          -- GetSongDir returns /Songs/<Group>/<Song>/
          -- We convert it to: <Group>/<Song>
          local songPath = song:GetSongDir()
          songPath = songPath:sub(8, #songPath-1)

          local data = {
            songInfo = {
              songPath=songPath,
              title=song:GetDisplayFullTitle(),
              artist=song:GetDisplayArtist(),
              songLength=song:MusicLengthSeconds()
            }
          }
          self.socket:Send(CreateRequest("selectSong", data))
        end
      end,
      JoinLobbyMessageCommand=function(self, params)
        if self.connected and self.socket ~= nil then
          LeaveLobbyModel()
          local data = GetMachineState()
          data.code = params.code and params.code
          data.password = params.password and params.password or ""
          self.socket:Send(CreateRequest("joinLobby", data))
        end
      end,
      CreateLobbyMessageCommand=function(self, params)
        if self.connected and self.socket ~= nil then
          LeaveLobbyModel()
          local data = GetMachineState()
          data.password = params.password and params.password or ""
          self.socket:Send(CreateRequest("createLobby", data))
        end
      end,
      SearchLobbyMessageCommand=function(self)
        if self.connected and self.socket ~= nil then
          self.socket:Send(CreateRequest("searchLobby", {}))
        end
      end,
      LeaveLobbyMessageCommand=function(self)
        if self.connected and self.socket ~= nil then
          self.socket:Send(CreateRequest("leaveLobby", {}))
        end
      end,
      DisconnectOnlineMessageCommand=function(self)
        onlineHandlerShuttingDown = true
        isWaiting = false
        if self.socket ~= nil then
          self.socket:Close()
        end
        for player in ivalues(PlayerNumber) do
          SCREENMAN:set_input_redirected(player, false)
        end
        self.connected = false
        self.socket = nil
        LeaveLobbyModel()
      end,

      Def.Actor{
        Name="InboundTimer",
        InitCommand=function(self)
          inboundThrottle.timer = self
        end,
        RunCommand=function(self)
          inboundThrottle.Run()
        end,
      },

      Def.Actor{
        Name="OutboundTimer",
        InitCommand=function(self)
          outboundThrottle.timer = self
        end,
        RunCommand=function(self)
          outboundThrottle.Run()
        end,
      },
    }
  end

  return onlineHandler
end
