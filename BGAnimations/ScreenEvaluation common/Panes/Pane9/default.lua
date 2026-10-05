-- Pane9 is Pane2 with the blue Fantastic narrowed to the player's FaPlusWindowMs.
local player, controller, ComputedData = unpack(...)

return LoadActor(THEME:GetPathB("", "ScreenEvaluation common/Panes/Pane2/default.lua"), {player, controller, ComputedData, true})
