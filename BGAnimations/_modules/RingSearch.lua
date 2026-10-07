-- A search box driven by three buttons: Left/Right turn a ring, Start takes.
-- The ring only offers characters that keep at least one entry matching, the
-- most frequent first, so it shrinks as the text grows. Matches show live
-- below it; SUGGESTIONS, one press left of the start, moves the cursor there.
--
--   local search = LoadActor(THEME:GetPathB("", "_modules/RingSearch.lua"), {
--   	title = "Search",
--   	entries = function() return { { label = "Name", value = anything }, ... } end,
--   	on_pick = function(value) end,
--   })
--   search.open()  search.is_open()  search.refresh()  search.footer()
--   search.input(event, button, first, both)   -- while open, after which the host redraws
--   af[#af+1] = search.actor                   -- follows the host's RefreshCommand

local args = ...
local accent = args.accent or GetCurrentColor(true)

local CHARS = "abcdefghijklmnopqrstuvwxyz0123456789 "
local MAX_LEN = 64
local RING_SLOTS = 6
local RING_GAP = 22
local RING_HALF_W = _screen.w * 0.45
local LIST_ROWS = 5
local LIST_ROW_H = 26
local LIST_W = _screen.w * 0.6
local LIST_TOP = 44
local BACK_W = 260
local BOX_PAD = 10

local function S(key)
	return THEME:GetString("RingSearch", key)
end

local state = { open = false, text = "", focus = "ring", ring = {}, sel = 1, matches = {}, list_sel = 1 }

local function load_entries()
	local entries = {}
	for _, entry in ipairs(args.entries()) do
		entries[#entries+1] = { label = entry.label, value = entry.value, lower = entry.label:lower() }
	end
	return entries
end

-- How often each character follows the text; with no text, how often each
-- one starts a word.
local function next_char_counts(entries, needle)
	local counts = {}
	local function count(c) counts[c] = (counts[c] or 0) + 1 end
	for _, entry in ipairs(entries) do
		if needle == "" then
			for c in (" " .. entry.lower):gmatch(" (.)") do count(c) end
		else
			local from = 1
			while true do
				local s, e = entry.lower:find(needle, from, true)
				if not s then break end
				count(entry.lower:sub(e + 1, e + 1))
				from = s + 1
			end
		end
	end
	return counts
end

-- Entries containing the text, those starting with it first.
local function find_matches(entries, needle)
	local starts, inside = {}, {}
	for _, entry in ipairs(entries) do
		local at = entry.lower:find(needle, 1, true)
		if at == 1 then
			starts[#starts+1] = entry
		elseif at then
			inside[#inside+1] = entry
		end
	end
	for _, entry in ipairs(inside) do starts[#starts+1] = entry end
	return starts
end

-- keep: the kind of ring item the cursor stays on; otherwise it goes to the
-- likeliest character, or to SUGGESTIONS when only one entry is left.
local function rebuild(keep)
	local entries = load_entries()
	local needle = state.text:lower()
	local counts = next_char_counts(entries, needle)
	local chars = {}
	for c in CHARS:gmatch(".") do
		if counts[c] then chars[#chars+1] = c end
	end
	table.sort(chars, function(a, b)
		if counts[a] ~= counts[b] then return counts[a] > counts[b] end
		return CHARS:find(a, 1, true) < CHARS:find(b, 1, true)
	end)

	local ring = {}
	for _, c in ipairs(chars) do
		ring[#ring+1] = { kind = "char", value = c, label = c == " " and S("Space") or c:upper() }
	end
	ring[#ring+1] = { kind = "del", label = S("Del") }
	state.matches = needle == "" and {} or find_matches(entries, needle)
	if #state.matches > 0 then ring[#ring+1] = { kind = "suggestions", label = S("Suggestions") } end

	state.ring, state.sel = ring, 1
	if keep then
		for i, item in ipairs(ring) do
			if item.kind == keep then state.sel = i end
		end
	elseif #state.matches == 1 then
		state.sel = #ring
	end
end

local function set_text(text, keep)
	state.text = text:sub(1, MAX_LEN)
	state.focus = "ring"
	rebuild(keep)
end

local function take()
	if state.focus == "list" then
		if state.list_sel == 1 then
			state.focus = "ring"
		else
			state.open = false
			args.on_pick(state.matches[state.list_sel - 1].value)
		end
		return
	end
	local item = state.ring[state.sel]
	if item.kind == "char" then
		set_text(state.text .. item.value)
	elseif item.kind == "del" then
		set_text(state.text:sub(1, -2), "del")
	else
		state.focus, state.list_sel = "list", 2
	end
end

local function turn(step)
	if state.focus == "list" then
		state.list_sel = (state.list_sel - 1 + step) % (#state.matches + 1) + 1
	else
		state.sel = (state.sel - 1 + step) % #state.ring + 1
	end
end

local function close()
	if state.focus == "list" then state.focus = "ring" else state.open = false end
end

-- DeviceButton_a .. DeviceButton_9, and space, from a real keyboard.
local function keyboard_char(event)
	local device = event.DeviceInput and event.DeviceInput.button or ""
	local c = device:match("^DeviceButton_(%w)$")
	if c then return c:lower() end
	if device == "DeviceButton_space" then return " " end
end

local function play(section, name)
	SOUND:PlayOnce(THEME:GetPathS(section, name))
end

local M = {}

function M.open()
	state.open = true
	set_text(state.text)
end

function M.is_open()
	return state.open
end

-- For when the entries change while the search is open.
function M.refresh()
	if not state.open then return end
	local item = state.ring[state.sel]
	rebuild(item and item.kind ~= "char" and item.kind or nil)
end

function M.footer()
	local three_key = PREFSMAN:GetPreference("ThreeKeyNavigation")
	local focus = state.focus == "list" and "List" or "Ring"
	return S("Footer" .. focus .. (three_key and "ThreeKey" or ""))
end

function M.input(event, button, first, both)
	local typed = first and keyboard_char(event)
	if typed then
		set_text(state.text .. typed)
		return
	end
	if both then
		if first then
			-- The first of the two presses already turned; this press undoes it.
			turn(button == "MenuRight" and 1 or -1)
			play("Common", "cancel")
			close()
		end
		return
	end
	if button == "MenuLeft" or button == "MenuRight" then
		turn(button == "MenuRight" and 1 or -1)
		return
	end
	if not first then return end

	if button == "Start" then
		play("Common", "Start")
		take()
	elseif button == "Back" then
		play("Common", "cancel")
		if state.focus == "ring" and state.text ~= "" then set_text(state.text:sub(1, -2)) else close() end
	elseif button == "Select" and #state.matches > 0 then
		play("Common", "Start")
		state.focus = state.focus == "list" and "ring" or "list"
		state.list_sel = 2
	end
end

-- DEL and SUGGESTIONS are actions, not letters: they sit in a box.
local function draw_slot(slot, item, selected, fade)
	local label, box = slot:GetChild("Label"), slot:GetChild("Box")
	label:settext(item.label):zoom(selected and 0.9 or 0.6)
	local w = label:GetZoomedWidth()
	if item.kind == "char" then
		box:visible(false)
		if selected then label:diffuse(accent) else label:diffuse(0.75, 0.75, 0.75, fade) end
		return w
	end

	w = w + 2 * BOX_PAD
	box:visible(true):zoomto(w, selected and 34 or 26)
	if item.kind == "suggestions" then
		box:diffuse(accent):diffusealpha(selected and 1 or 0.4 * fade)
		label:diffuse(selected and Color.Black or Color.White):diffusealpha(selected and 1 or fade)
	else
		box:diffuse(color("#3a444b")):diffusealpha(fade)
		label:diffuse(selected and accent or Color.White):diffusealpha(fade)
	end
	return w
end

local function draw_ring(frame)
	local n = #state.ring
	local active = state.focus == "ring"
	local function slot(offset) return frame:GetChild("Slot" .. offset) end
	local function fill(offset)
		local item = state.ring[(state.sel - 1 + offset) % n + 1]
		local s = slot(offset)
		return s, draw_slot(s, item, offset == 0, 1 - math.abs(offset) * 0.12)
	end

	for offset = -RING_SLOTS, RING_SLOTS do slot(offset):visible(false) end
	local center, center_w = fill(0)
	center:visible(true):x(0)

	-- A short ring would show items twice: the extra one goes left, where
	-- DEL and SUGGESTIONS sit.
	local sides = { { dir = -1, count = math.ceil((n - 1) / 2) }, { dir = 1, count = math.floor((n - 1) / 2) } }
	for _, side in ipairs(sides) do
		local edge = center_w / 2
		for step = 1, math.min(RING_SLOTS, side.count) do
			local s, w = fill(side.dir * step)
			local x = edge + RING_GAP + w / 2
			if x + w / 2 > RING_HALF_W then break end
			s:visible(true):x(side.dir * x)
			edge = x + w / 2
		end
	end
	frame:diffusealpha(active and 1 or 0.35)
end

local function hint_text()
	if state.focus == "list" then
		return state.list_sel == 1 and S("HintKeyboard") or S("HintPick")
	end
	local kind = state.ring[state.sel].kind
	if kind == "del" then return S("HintDel") end
	if kind == "suggestions" then return string.format(S("HintSuggestions"), #state.matches) end
	return ""
end

-- In the list, item 1 is the button back to the letters; the matches follow.
local function draw_list(frame)
	local in_list = state.focus == "list"
	local on_back = in_list and state.list_sel == 1

	local back = frame:GetChild("Back")
	back:visible(in_list)
	back:GetChild("Box"):diffuse(on_back and accent or color("#3a444b"))
	back:GetChild("Label"):diffuse(on_back and Color.Black or Color.White)

	local labels = {}
	for _, entry in ipairs(state.matches) do labels[#labels+1] = entry.label end
	if #labels == 0 and state.text ~= "" then labels[1] = S("NoMatches") end

	local picked = in_list and state.list_sel - 1 or 0
	local first = math.max(1, math.min(picked - math.floor(LIST_ROWS / 2), #labels - LIST_ROWS + 1))
	local bar = frame:GetChild("Bar"):visible(false)
	for row = 1, LIST_ROWS do
		local index = first + row - 1
		local label = frame:GetChild("Row" .. row)
		local selected = index == picked
		label:settext(labels[index] or ""):diffuse(selected and accent or Color.White)
			:diffusealpha(in_list and 1 or 0.55)
		if selected then bar:visible(true):y(label:GetY()) end
	end
end

local ring = Def.ActorFrame{ Name="Ring", InitCommand=function(self) self:y(-40) end }
for offset = -RING_SLOTS, RING_SLOTS do
	ring[#ring+1] = Def.ActorFrame{
		Name="Slot" .. offset,
		Def.Quad{ Name="Box" },
		LoadFont("Common Bold")..{ Name="Label" },
	}
end

local list = Def.ActorFrame{
	Name="List",
	InitCommand=function(self) self:y(28) end,
	Def.ActorFrame{
		Name="Back",
		Def.Quad{ Name="Box", InitCommand=function(self) self:zoomto(BACK_W, 30) end },
		LoadFont("Common Bold")..{
			Name="Label",
			Text=S("Keyboard"),
			InitCommand=function(self) self:zoom(0.45):maxwidth((BACK_W - 16) / 0.45) end,
		},
	},
	Def.Quad{ Name="Bar", InitCommand=function(self) self:zoomto(LIST_W, LIST_ROW_H - 2):diffuse(1, 1, 1, 0.1) end },
}
for row = 1, LIST_ROWS do
	list[#list+1] = LoadFont("Common Normal")..{
		Name="Row" .. row,
		InitCommand=function(self)
			self:y(LIST_TOP + (row - 1) * LIST_ROW_H):zoom(0.8):maxwidth((LIST_W - 20) / 0.8)
		end,
	}
end

M.actor = Def.ActorFrame{
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy):visible(false) end,
	RefreshCommand=function(self)
		self:visible(state.open)
		if not state.open then return end
		self:GetChild("Text"):settext(state.text .. "_")
		self:GetChild("Hint"):settext(hint_text())
		draw_ring(self:GetChild("Ring"))
		draw_list(self:GetChild("List"))
	end,
	Def.Quad{ InitCommand=function(self) self:zoomto(_screen.w, _screen.h):diffuse(Color.Black):diffusealpha(0.9) end },
	LoadFont("Common Bold")..{
		Text=args.title,
		InitCommand=function(self) self:y(-160):zoom(0.7) end,
	},
	Def.Quad{ InitCommand=function(self) self:y(-100):zoomto(LIST_W, 30):diffuse(1, 1, 1, 0.08) end },
	LoadFont("Common Normal")..{
		Name="Text",
		InitCommand=function(self) self:y(-100):zoom(0.8):maxwidth((LIST_W - 10) / 0.8) end,
	},
	ring,
	LoadFont("Common Normal")..{
		Name="Hint",
		InitCommand=function(self) self:y(-10):zoom(0.6):diffuse(accent) end,
	},
	list,
}

return M
