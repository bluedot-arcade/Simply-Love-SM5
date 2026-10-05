-- Pane2 displays the FA+ centric score out of a possible 100.00
-- aggregate judgment counts (overall W1, overall W2, overall miss, etc.)
-- and judgment counts on holds, mines, rolls
local player, _, _, restricted = unpack(...)
local pn = ToEnumShortString(player)

-- We only want to use this in ITG mode.
-- We don't want this version in casual mode at all.
if SL.Global.GameMode ~= "ITG" or not SL[pn].ActiveModifiers.ShowFaPlusPane then
	return
end

-- Pane9 reuses this pane for the player's narrower FaPlusWindowMs.
local window_ms = SL[pn].ActiveModifiers.FaPlusWindowMs
if restricted and not (window_ms and window_ms < 15) then
	return
end

return Def.ActorFrame{
	-- score displayed as a percentage
	LoadActor("./Percentage.lua", ...),

	-- labels like "FANTASTIC", "MISS", "holds", "rolls", etc.
	LoadActor("./JudgmentLabels.lua", ...),

	-- numbers (How many Fantastics? How many Misses? etc.)
	LoadActor("./JudgmentNumbers.lua", ...),
}