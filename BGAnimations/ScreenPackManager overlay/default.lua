local packs = LoadActor("packs.lua")

local NUM_ITEMS = THEME:GetMetric("MusicWheel", "NumWheelItems")
local item_h = _screen.h / (NUM_ITEMS - 2)
local item_w = _screen.w / 2.125
local wheel_x = _screen.cx + WideScale(28, 33)
local indent_w = 14

local banner_zoom = IsUsingWideScreen() and 0.7655 or 0.75
local panel_x = _screen.cx - (IsUsingWideScreen() and 170 or 166)
local panel_w = 418 * banner_zoom
local panel_left = panel_x - panel_w/2 + 12
local info_top = 96 + 164 * banner_zoom / 2 + 6
local info_h = SCREEN_BOTTOM - 48 - info_top

local accent = GetCurrentColor(true)
local danger = color("#d84040")

local function S(key)
	return THEME:GetString("ScreenPackManager", key)
end

local function folder(key, color_offset)
	return {
		kind = "folder",
		id = "folder:" .. key,
		name = S("Folder" .. key),
		color = GetHexColor(SL.Global.ActiveColorIndex + color_offset, true),
		children = {},
	}
end

local usb_folder = folder("USB", 0)
local online_folder = folder("Online", 2)
local installed_folder = folder("Installed", 4)
online_folder.hidden = not packs.online_allowed()
local roots = { usb_folder, online_folder, installed_folder }

local state = {
	rows = {},
	cursor = 1,
	installed_by_name = {},
	catalog = "idle",
	confirm = nil,
	busy = nil,
	changed = false,
}
local holding = {}
local pending_op
local alive = true
local t

local function format_size(bytes)
	if bytes >= 1024^3 then return string.format("%.1f GB", bytes / 1024^3) end
	return string.format("%d MB", math.ceil(bytes / 1024^2))
end

local function redraw()
	if alive and t then t:playcommand("Refresh") end
end

local function installed_match(pack)
	if pack.source == "installed" then return pack end
	for _, group in ipairs(pack.groups) do
		local match = state.installed_by_name[group:lower()]
		if match then return match end
	end
end

local function folder_count(node)
	if node == online_folder then return node.count end
	return #node.children
end

local function flatten(nodes, parent, depth, out)
	for _, node in ipairs(nodes) do
		if not node.hidden then
			out[#out+1] = { node = node, parent = parent, depth = depth }
			if node.open then flatten(node.children, node, depth + 1, out) end
		end
	end
	return out
end

local function current_row()
	return state.rows[state.cursor]
end

local function rebuild(focus_id)
	local previous = current_row()
	focus_id = focus_id or (previous and previous.node.id)
	state.rows = flatten(roots, nil, 0, {})
	state.cursor = math.min(state.cursor, #state.rows)
	for i, row in ipairs(state.rows) do
		if row.node.id == focus_id then
			state.cursor = i
			break
		end
	end
end

local function refresh_installed()
	installed_folder.children = packs.installed()
	state.installed_by_name = {}
	for _, pack in ipairs(installed_folder.children) do
		state.installed_by_name[pack.name:lower()] = pack
	end
end

local function refresh_usb()
	usb_folder.children = packs.usb()
	usb_folder.hidden = #usb_folder.children == 0
	if usb_folder.hidden then usb_folder.open = false end
end

local function close(node)
	node.open = false
	for _, child in ipairs(node.children) do
		if child.kind == "folder" then close(child) end
	end
end

-- Like the music wheel, only one folder per level stays open.
local function open(node, parent)
	for _, sibling in ipairs(parent and parent.children or roots) do
		if sibling ~= node and sibling.kind == "folder" then close(sibling) end
	end
	node.open = true
end

local function build_letters(catalog)
	local by_letter, letters = {}, {}
	for _, pack in ipairs(catalog) do
		local letter = pack.name:sub(1, 1):upper()
		if not letter:match("[A-Z]") then letter = "#" end
		if not by_letter[letter] then
			by_letter[letter] = {
				kind = "folder",
				id = "folder:Online:" .. letter,
				name = letter,
				color = online_folder.color,
				children = {},
			}
			letters[#letters+1] = by_letter[letter]
		end
		table.insert(by_letter[letter].children, pack)
	end
	table.sort(letters, function(a, b) return a.name < b.name end)
	return letters
end

local function load_catalog()
	state.catalog = "loading"
	online_folder.message, online_folder.detail = "LoadingCatalog", nil
	packs.load_catalog(function(catalog, message, detail)
		if not alive then return end
		if catalog then
			state.catalog = "ready"
			online_folder.message = nil
			online_folder.children = build_letters(catalog)
			online_folder.count = #catalog
			local row = current_row()
			if row and row.node == online_folder then open(online_folder) end
		else
			state.catalog = "idle"
			online_folder.message, online_folder.detail = message, detail
		end
		rebuild()
		redraw()
	end)
end

local function scroll(delta)
	local count = #state.rows
	if count == 0 then return end
	state.cursor = (state.cursor - 1 + delta) % count + 1
end

local function close_current()
	local row = current_row()
	local target = row.parent or (row.node.open and row.node)
	if not target then return false end
	close(target)
	rebuild(target.id)
	return true
end

local function leave()
	packs.unmount_all()
	local screen = SCREENMAN:GetTopScreen()
	if state.changed then
		screen:SetNextScreenName("ScreenReloadSongs" .. (screen:GetName():gsub("^Screen", "")))
	end
	screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local function finish(ok, pack, failure_key, detail)
	state.busy = nil
	state.changed = state.changed or ok
	if not ok and failure_key then
		SM(string.format(S(failure_key), pack.name, detail or ""))
	end
	refresh_installed()
	rebuild()
	redraw()
end

local function start_download(pack)
	state.busy = { status = string.format(S("DownloadingStatus"), pack.name), hint = S("DownloadHint"), detail = "" }
	local request = packs.download(pack,
		function(current, total)
			-- The engine reports progress as 32-bit ints, so the catalog size is the reliable total.
			if not state.busy or current < 0 or not pack.size or pack.size <= 0 then return end
			local percent = math.floor(current * 100 / pack.size)
			if percent == state.busy.percent then return end
			state.busy.percent = percent
			state.busy.detail = string.format(S("DownloadProgress"), format_size(current), format_size(pack.size), percent)
			redraw()
		end,
		function(ok, failure_key, detail)
			if not alive then return end
			finish(ok, pack, failure_key, detail)
		end)
	if state.busy then state.busy.request = request end
end

local function start_operation(op)
	state.confirm = nil
	if op.kind == "install" and op.pack.source == "smo" then
		start_download(op.pack)
		return
	end
	local status = op.kind == "delete" and "DeletingStatus" or "InstallingStatus"
	state.busy = {
		status = string.format(S(status), op.pack.name),
		hint = op.pack.source == "usb" and S("BusyHint") or "",
		detail = "",
	}
	-- Let the overlay draw before the blocking FILEMAN call.
	pending_op = op
	t:sleep(0.05):queuecommand("RunOperation")
end

local function run_operation(op)
	local ok
	if op.kind == "delete" then
		ok = packs.delete(op.pack)
	else
		ok = packs.install_usb(op.pack)
	end
	finish(ok, op.pack, op.kind == "delete" and "DeleteFailed" or "InstallFailed")
end

local function toggle_folder(row)
	local node = row.node
	if node.open then
		close(node)
	elseif node == online_folder and state.catalog ~= "ready" then
		if state.catalog == "idle" then load_catalog() end
		return true
	elseif #node.children == 0 then
		return false
	else
		open(node, row.parent)
	end
	rebuild(node.id)
	return true
end

local function select_pack(pack)
	local match = installed_match(pack)
	if match and match.readonly then
		SM(string.format(S(pack.source == "installed" and "ReadOnlyPack" or "ReadOnlyReinstall"), pack.name))
		return false
	end
	if pack.source == "installed" then
		state.confirm = { kind = "delete", pack = pack, choice = 1 }
	elseif match then
		state.confirm = { kind = "install", pack = pack, choice = 1 }
	else
		start_operation({ kind = "install", pack = pack })
	end
	return true
end

local function handle_start()
	local c = state.confirm
	if c then
		if c.choice == 2 then start_operation(c) else state.confirm = nil end
		return true
	end
	local row = current_row()
	if not row then return false end
	if row.node.kind == "folder" then return toggle_folder(row) end
	return select_pack(row.node)
end

local function play(sound)
	SOUND:PlayOnce(THEME:GetPathS(sound[1], sound[2]))
end
local CHANGE, START = { "ScreenSelectMaster", "change" }, { "Common", "Start" }

local function input(event)
	if not event.GameButton then return false end
	local button = event.GameButton

	if event.type == "InputEventType_Release" then
		holding[button] = nil
		return false
	end
	local first = event.type == "InputEventType_FirstPress"
	if first then holding[button] = true end
	local both = holding.MenuLeft and holding.MenuRight

	if state.busy then
		local cancel = button == "Back" or both
		if first and cancel and state.busy.request then state.busy.request:Cancel() end
		return false
	end

	if button == "MenuLeft" or button == "MenuRight" then
		local delta = button == "MenuRight" and 1 or -1
		if both then
			if not first then return false end
			if state.confirm then
				state.confirm = nil
			else
				-- The first of the two presses already scrolled; this press undoes it.
				scroll(delta)
				if not close_current() then
					leave()
					return false
				end
			end
		elseif state.confirm then
			if not first then return false end
			state.confirm.choice = 3 - state.confirm.choice
			play(CHANGE)
		else
			scroll(delta)
			play(CHANGE)
		end
	elseif not first then
		return false
	elseif button == "Start" then
		if handle_start() then play(START) end
	elseif button == "Select" then
		if state.confirm then state.confirm = nil else close_current() end
	elseif button == "Back" then
		if not state.confirm then
			leave()
			return false
		end
		state.confirm = nil
	end

	redraw()
	return false
end

local function action_key(node)
	if node.kind == "folder" then return node.open and "ActionClose" or "ActionOpen" end
	local match = installed_match(node)
	if match and match.readonly then return "ActionReadOnly" end
	if node.source == "installed" then return "ActionDelete" end
	return match and "ActionReinstall" or "ActionInstall"
end

local function pack_tag(pack)
	local match = installed_match(pack)
	if match and match.readonly then return S("TagReadOnly"), color("#e0a030") end
	if pack.source == "installed" then return string.format(S("SongCount"), pack.songs), color("#bbbbbb") end
	if match then return S("TagInstalled"), color("#9a9a9a") end
	return S("TagNew"), color("#4ccd5f")
end

local SOURCE_FOLDER = { usb = "FolderUSB", smo = "FolderOnline", installed = "FolderInstalled" }

local function info_lines(node)
	local lines = {}
	local function add(key, value)
		if value and value ~= "" and value ~= "None" and value ~= "n/a" and value ~= "null" then
			lines[#lines+1] = S(key) .. ": " .. value
		end
	end

	if node.kind == "folder" then
		local count = folder_count(node)
		add("InfoPacks", count and tostring(count))
		if node.message then
			lines[#lines+1] = ""
			lines[#lines+1] = string.format(S(node.message), node.detail or "")
		end
		return table.concat(lines, "\n")
	end

	local match = installed_match(node)
	add("InfoSource", S(SOURCE_FOLDER[node.source]))
	add("InfoSongs", node.songs and tostring(node.songs))
	add("InfoSize", node.size and format_size(node.size))
	add("InfoStatus", S(match and (match.readonly and "StatusReadOnly" or "StatusInstalled") or "StatusNew"))
	add("InfoType", node.pack_type)
	add("InfoStyle", node.substyle)
	add("InfoSync", node.sync)
	return table.concat(lines, "\n")
end

local function footer_text()
	local three_key = PREFSMAN:GetPreference("ThreeKeyNavigation")
	if state.busy then return state.busy.request and S(three_key and "FooterBusyThreeKey" or "FooterBusy") or "" end
	if state.confirm then return S(three_key and "FooterConfirmThreeKey" or "FooterConfirm") end
	return S(three_key and "FooterThreeKey" or "Footer")
end

local af = Def.ActorFrame{
	OnCommand=function(self)
		t = self
		refresh_installed()
		refresh_usb()
		rebuild()
		SCREENMAN:GetTopScreen():AddInputCallback(input)
		self:playcommand("Refresh")
	end,
	OffCommand=function()
		alive = false
		packs.unmount_all()
	end,
	StorageDevicesChangedMessageCommand=function(self)
		if state.busy then return end
		refresh_usb()
		rebuild()
		self:playcommand("Refresh")
	end,
	RunOperationCommand=function(self)
		local op = pending_op
		pending_op = nil
		if op then run_operation(op) end
	end,
}

for i = 1, NUM_ITEMS do
	local offset = i - math.ceil(NUM_ITEMS / 2)
	af[#af+1] = Def.ActorFrame{
		InitCommand=function(self) self:xy(wheel_x, _screen.cy + offset * item_h) end,
		RefreshCommand=function(self)
			local count = #state.rows
			local index = state.cursor + offset
			-- Wrap like the music wheel only when there are enough rows to fill it.
			if count >= NUM_ITEMS then index = (index - 1) % count + 1 end
			local row = state.rows[index]
			self:visible(row ~= nil)
			if not row then return end

			local node = row.node
			local indent = row.depth * indent_w
			local is_folder = node.kind == "folder"
			self:GetChild("Bg"):diffuse(is_folder and color("#4c565d") or color("#0a141b"))
			self:GetChild("Folder"):visible(is_folder):x(8 + indent):diffuse(node.color or Color.White)
			self:GetChild("Label"):settext(node.name)
				:x((is_folder and WideScale(65, 74) or 12) + indent)
				:maxwidth(item_w - WideScale(150, 170) - indent)

			local right = self:GetChild("Right")
			if is_folder then
				local folder_total = folder_count(node)
				right:settext(folder_total and tostring(folder_total) or "..."):diffuse(Color.White)
			else
				local tag, tag_color = pack_tag(node)
				right:settext(tag):diffuse(tag_color)
			end
		end,

		Def.Quad{ InitCommand=function(self) self:horizalign(left):zoomto(item_w, item_h):diffuse(Color.Black) end },
		Def.Quad{ Name="Bg", InitCommand=function(self) self:horizalign(left):zoomto(item_w, item_h - 1) end },
		Def.Sprite{
			Name="Folder",
			Texture=THEME:GetPathG("", "folder-solid.png"),
			InitCommand=function(self) self:horizalign(left):zoom(0.175) end,
		},
		LoadFont("Common Normal")..{ Name="Label", InitCommand=function(self) self:horizalign(left) end },
		LoadFont("Common Normal")..{
			Name="Right",
			InitCommand=function(self) self:horizalign(right):x(item_w - 10):zoom(0.75) end,
		},
	}
end

af[#af+1] = Def.Quad{
	InitCommand=function(self)
		self:horizalign(left):xy(wheel_x, _screen.cy):zoomto(item_w, item_h - 1)
			:diffuseshift():effectperiod(2):effectcolor1(0.8, 0.8, 0.8, 0.15):effectcolor2(0.8, 0.8, 0.8, 0.05)
	end,
}

local banner_path
af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(panel_x, 96):zoom(banner_zoom) end,
	RefreshCommand=function(self)
		local row = current_row()
		local match = row and row.node.kind ~= "folder" and installed_match(row.node)
		local path = match and SONGMAN:GetSongGroupBannerPath(match.name) or ""
		local banner = self:GetChild("Banner")
		if path ~= banner_path and path ~= "" then
			banner:Load(path)
			banner:setsize(418, 164)
		end
		banner_path = path
		banner:visible(path ~= "")
	end,
	Def.Sprite{ Texture=GetFallbackBanner(), InitCommand=function(self) self:setsize(418, 164) end },
	Def.Sprite{ Name="Banner" },
}

af[#af+1] = Def.ActorFrame{
	RefreshCommand=function(self)
		local row = current_row()
		self:visible(row ~= nil)
		if not row then return end
		self:GetChild("Title"):settext(row.node.name)
		self:GetChild("Body"):settext(info_lines(row.node))
		self:GetChild("Action"):settext(S(action_key(row.node)))
	end,
	Def.Quad{
		InitCommand=function(self)
			self:xy(panel_x, info_top + info_h/2):zoomto(panel_w, info_h):diffuse(color("#1e282f"))
		end,
	},
	LoadFont("Common Normal")..{
		Name="Title",
		InitCommand=function(self)
			self:xy(panel_left, info_top + 18):horizalign(left):maxwidth(panel_w - 24)
		end,
	},
	LoadFont("Common Normal")..{
		Name="Body",
		InitCommand=function(self)
			self:xy(panel_left, info_top + 40):align(0, 0):zoom(0.8):wrapwidthpixels((panel_w - 24) / 0.8)
				:diffuse(color("#dddddd"))
		end,
	},
	LoadFont("Common Bold")..{
		Name="Action",
		InitCommand=function(self)
			self:xy(panel_left, info_top + info_h - 18):horizalign(left):zoom(0.4):diffuse(accent)
		end,
	},
}

af[#af+1] = LoadFont("Common Normal")..{
	InitCommand=function(self) self:xy(_screen.cx, SCREEN_BOTTOM - 24):zoom(0.7) end,
	RefreshCommand=function(self) self:settext(footer_text()) end,
}

local dialog_w = 520
af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,
	RefreshCommand=function(self)
		local c = state.confirm
		self:visible(c ~= nil)
		if not c then return end

		local title, detail, yes
		if c.kind == "delete" then
			title = string.format(S("ConfirmDelete"), c.pack.name)
			detail = string.format(S("ConfirmDeleteDetail"), c.pack.songs)
			yes = S("YesDelete")
		else
			title = string.format(S("ConfirmReinstall"), c.pack.name)
			detail = S("ConfirmReinstallDetail")
			yes = S("YesReinstall")
		end
		self:GetChild("Title"):settext(title)
		self:GetChild("Detail"):settext(detail)
		for i, name in ipairs({ "No", "Yes" }) do
			local on = c.choice == i
			local button = self:GetChild(name)
			button:GetChild("Bg"):diffuse(on and (i == 2 and danger or accent) or color("#2a3238"))
			button:GetChild("Label"):settext(i == 2 and yes or S("No")):diffuse(on and Color.Black or Color.White)
		end
	end,
	Def.Quad{ InitCommand=function(self) self:zoomto(_screen.w, _screen.h):diffuse(Color.Black):diffusealpha(0.6) end },
	Def.Quad{ InitCommand=function(self) self:zoomto(dialog_w + 4, 164):diffuse(danger) end },
	Def.Quad{ InitCommand=function(self) self:zoomto(dialog_w, 160):diffuse(color("#071016")) end },
	LoadFont("Common Bold")..{
		Name="Title",
		InitCommand=function(self) self:y(-46):zoom(0.5):maxwidth((dialog_w - 40) / 0.5) end,
	},
	LoadFont("Common Normal")..{
		Name="Detail",
		InitCommand=function(self) self:y(-12):zoom(0.7):diffuse(color("#bbbbbb")) end,
	},
	Def.ActorFrame{
		Name="No",
		InitCommand=function(self) self:xy(-70, 40) end,
		Def.Quad{ Name="Bg", InitCommand=function(self) self:zoomto(120, 34) end },
		LoadFont("Common Bold")..{ Name="Label", InitCommand=function(self) self:zoom(0.42) end },
	},
	Def.ActorFrame{
		Name="Yes",
		InitCommand=function(self) self:xy(70, 40) end,
		Def.Quad{ Name="Bg", InitCommand=function(self) self:zoomto(120, 34) end },
		LoadFont("Common Bold")..{ Name="Label", InitCommand=function(self) self:zoom(0.42) end },
	},
}

af[#af+1] = Def.ActorFrame{
	InitCommand=function(self) self:xy(_screen.cx, _screen.cy) end,
	RefreshCommand=function(self)
		local busy = state.busy
		self:visible(busy ~= nil)
		if not busy then return end
		self:GetChild("Status"):settext(busy.status)
		self:GetChild("Detail"):settext(busy.detail)
		self:GetChild("Hint"):settext(busy.hint)
	end,
	Def.Quad{ InitCommand=function(self) self:zoomto(_screen.w, 130):diffuse(color("#071016")):diffusealpha(0.95) end },
	LoadFont("Common Bold")..{
		Name="Status",
		InitCommand=function(self) self:y(-28):zoom(0.55):maxwidth((_screen.w - 40) / 0.55) end,
	},
	LoadFont("Common Normal")..{ Name="Detail", InitCommand=function(self) self:y(4):zoom(0.8) end },
	LoadFont("Common Normal")..{
		Name="Hint",
		InitCommand=function(self) self:y(34):zoom(0.7):diffuse(color("#bbbbbb")) end,
	},
}

return af
