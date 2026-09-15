-- -----------------------------------------------------------------------
-- Cabinet identity.
--
-- Every cabinet has a four-character id, the address a lobby controller uses
-- to command one cabinet. It is generated on first boot and stored as plain
-- text: IniFile would turn an id such as 2345 into a number.
--
-- A side whose profile is named __EMPTY__ is a placeholder on an empty pad:
-- it stays joined but is never part of the lobby.
-- -----------------------------------------------------------------------

local PLACEHOLDER_NAME = "__EMPTY__"
local CABINET_ID_PATH = "Save/CabinetId.txt"
local CABINET_ID_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local CABINET_ID_LENGTH = 4

local cabinetId = nil

local ReadCabinetId = function()
  local file = RageFileUtil.CreateRageFile()
  local id = nil
  if file:Open(CABINET_ID_PATH, 1) then
    id = file:Read():match("^%s*([A-Z2-9]+)%s*$")
    file:Close()
  else
    file:ClearError()
  end
  file:destroy()
  return id
end

local WriteCabinetId = function(id)
  local file = RageFileUtil.CreateRageFile()
  if file:Open(CABINET_ID_PATH, 2) then
    file:Write(id)
    file:Close()
  else
    Warn("[Cabinet] Cannot store the cabinet id: " .. file:GetError())
    file:ClearError()
  end
  file:destroy()
end

local GenerateCabinetId = function()
  -- Cabinets booted in the same second still differ by their uptime in milliseconds.
  math.randomseed(Year() * 31622400 + DayOfYear() * 86400 + Hour() * 3600 + Minute() * 60 + Second() + math.floor(GetTimeSinceStart() * 1000))
  local characters = {}
  for i = 1, CABINET_ID_LENGTH do
    local index = math.random(1, #CABINET_ID_ALPHABET)
    characters[i] = CABINET_ID_ALPHABET:sub(index, index)
  end
  return table.concat(characters)
end

GetCabinetId = function()
  if cabinetId == nil then
    cabinetId = ReadCabinetId()
    if cabinetId == nil or #cabinetId ~= CABINET_ID_LENGTH then
      cabinetId = GenerateCabinetId()
      WriteCabinetId(cabinetId)
    end
  end
  return cabinetId
end

-- An operator typing __EMPTY__ as a profile name gets the same treatment.
IsPlaceholderSide = function(player)
  return GAMESTATE:IsHumanPlayer(player) and PROFILEMAN:GetPlayerName(player) == PLACEHOLDER_NAME
end

IsParkedCabinet = function()
  local humans = GAMESTATE:GetHumanPlayers()
  if #humans == 0 then
    return false
  end
  for player in ivalues(humans) do
    if not IsPlaceholderSide(player) then
      return false
    end
  end
  return true
end
