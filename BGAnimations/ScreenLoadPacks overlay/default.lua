local focus_order = { "usb", "installed", "exit" }
local mounted_devices = {}
local device_counter = 0
local zip_mount_counter = 0
local operation = nil
local t = nil
local panel_w = math.min(_screen.w * 0.41, 520)
local panel_h = math.min(_screen.h * 0.69, 492)
local panel_gap = math.max(_screen.w * 0.08, 96)
local panel_offset = panel_w/2 + panel_gap/2

local state = {
	focus_index = 1,
	wheel_mode = nil,
	busy = false,
	changed = false,
	left_entries = {},
	right_entries = {},
	left_index = 1,
	right_index = 1,
	status = "",
}

local holding = {
	MenuLeft = false,
	MenuRight = false,
}

local function screen_string(key)
	return THEME:GetString("ScreenLoadPacks", key)
end

local function basename(path)
	local normalized = path:gsub("\\", "/"):gsub("/+$", "")
	return normalized:match("([^/]+)$") or normalized
end

local function strip_extension(name)
	return name:gsub("%.[^%.]+$", "")
end

local function make_mountpoint(prefix)
	device_counter = device_counter + 1
	return string.format("/@load-packs-%s-%d/", prefix, device_counter)
end

local function make_zip_mountpoint()
	zip_mount_counter = zip_mount_counter + 1
	return string.format("/@load-pack-zip-%d/", zip_mount_counter)
end

local function sort_entries(entries)
	table.sort(entries, function(a, b)
		return a.label:lower() < b.label:lower()
	end)
end

local function current_focus()
	return focus_order[state.focus_index]
end

local function current_footer()
	if state.wheel_mode == nil then
		return screen_string("FooterFocus")
	end
	if PREFSMAN:GetPreference("ThreeKeyNavigation") then
		return screen_string("FooterWheelThreeKey")
	end
	return screen_string("FooterWheel")
end

local function unmount_all_devices()
	for _, mount in ipairs(mounted_devices) do
		FILEMAN:Unmount("dirro", mount.root, mount.mountpoint)
	end
	mounted_devices = {}
end

local function get_group_names_from_dirs(dir_paths)
	local groups = {}
	for _, path in ipairs(dir_paths) do
		local group = basename(path)
		if group ~= "" and group ~= "__MACOSX" then
			groups[#groups+1] = group
		end
	end
	table.sort(groups, function(a, b)
		return a:lower() < b:lower()
	end)
	return groups
end

local function get_installed_groups()
	return get_group_names_from_dirs(FILEMAN:GetDirListing("/Songs/*", true, true))
end

local function inspect_zip(zip_path)
	local zip_mount = make_zip_mountpoint()
	if not FILEMAN:Mount("zip", zip_path, zip_mount) then
		return nil
	end

	local has_songs_root = FILEMAN:DoesFileExist(zip_mount .. "Songs")
	local group_paths
	if has_songs_root then
		group_paths = FILEMAN:GetDirListing(zip_mount .. "Songs/*", true, true)
	else
		group_paths = FILEMAN:GetDirListing(zip_mount .. "*", true, true)
	end

	local groups = get_group_names_from_dirs(group_paths)
	FILEMAN:Unmount("zip", zip_path, zip_mount)

	if #groups == 0 then
		return nil
	end

	return {
		groups = groups,
		strip = has_songs_root and 1 or 0,
	}
end

local function refresh_entries()
	unmount_all_devices()

	state.right_entries = {}
	local installed_lookup = {}
	for _, group in ipairs(get_installed_groups()) do
		state.right_entries[#state.right_entries+1] = {
			label = group,
			group = group,
		}
		installed_lookup[group:lower()] = true
	end
	sort_entries(state.right_entries)

	state.left_entries = {}
	for _, device in ipairs(MEMCARDMAN:GetStorageDevices()) do
		if device.ready and device.mountDir ~= "" then
			local mountpoint = make_mountpoint("usb")
			if FILEMAN:Mount("dirro", device.mountDir, mountpoint) then
				mounted_devices[#mounted_devices+1] = { root = device.mountDir, mountpoint = mountpoint }

				local archive_paths = {}
				for _, path in ipairs(FILEMAN:GetDirListing(mountpoint .. "*.zip", false, true)) do
					archive_paths[#archive_paths+1] = path
				end
				for _, path in ipairs(FILEMAN:GetDirListing(mountpoint .. "*.smzip", false, true)) do
					archive_paths[#archive_paths+1] = path
				end

				table.sort(archive_paths, function(a, b)
					return a:lower() < b:lower()
				end)

				for _, archive_path in ipairs(archive_paths) do
					local info = inspect_zip(archive_path)
					if info ~= nil then
						local duplicate = false
						for _, group in ipairs(info.groups) do
							if installed_lookup[group:lower()] then
								duplicate = true
								break
							end
						end

						if not duplicate then
							local label = info.groups[1]
							if #info.groups > 1 then
								label = strip_extension(basename(archive_path))
							end

							state.left_entries[#state.left_entries+1] = {
								label = label,
								path = archive_path,
								groups = info.groups,
								strip = info.strip,
							}
						end
					end
				end
			end
		end
	end
	sort_entries(state.left_entries)

	state.left_index = #state.left_entries == 0 and 1 or math.min(state.left_index, #state.left_entries)
	state.right_index = #state.right_entries == 0 and 1 or math.min(state.right_index, #state.right_entries)
end

local function current_entry(side)
	if side == "usb" then
		return state.left_entries[state.left_index]
	end
	if side == "installed" then
		return state.right_entries[state.right_index]
	end
	return nil
end

local function update_visuals()
	if t ~= nil then
		t:playcommand("Refresh")
	end
end

local function leave_screen()
	unmount_all_devices()
	local top_screen = SCREENMAN:GetTopScreen()
	top_screen:SetNextScreenName("ScreenOptionsService")
	top_screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local function activate_exit()
	unmount_all_devices()
	local top_screen = SCREENMAN:GetTopScreen()
	if state.changed then
		top_screen:SetNextScreenName("ScreenReloadSongsLoadPacks")
	else
		top_screen:SetNextScreenName("ScreenOptionsService")
	end
	top_screen:StartTransitioningScreen("SM_GoToNextScreen")
end

local function finish_operation(success, failure_key, label)
	if not success then
		SM(string.format(screen_string(failure_key), label))
	end

	state.busy = false
	state.status = ""
	operation = nil
	refresh_entries()

	if state.wheel_mode == "usb" and #state.left_entries == 0 then
		state.wheel_mode = nil
	end
	if state.wheel_mode == "installed" and #state.right_entries == 0 then
		state.wheel_mode = nil
	end

	update_visuals()
end

local function perform_install(entry)
	local success = FILEMAN:Unzip(entry.path, "/Songs", entry.strip)
	if success then
		state.changed = true
	end
	finish_operation(success, "InstallFailed", entry.label)
end

local function perform_uninstall(entry)
	local success = FILEMAN:DeleteRecursive("/Songs/" .. entry.group .. "/")
	if success then
		state.changed = true
	end
	finish_operation(success, "UninstallFailed", entry.label)
end

local function begin_operation(kind, entry)
	if state.busy or entry == nil then
		SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
		return
	end

	state.busy = true
	operation = { kind = kind, entry = entry }
	state.status = string.format(
		screen_string(kind == "install" and "InstallStatus" or "UninstallStatus"),
		entry.label
	)
	update_visuals()
	t:sleep(0.05):queuecommand("PerformOperation")
end

local function move_focus(delta)
	state.focus_index = ((state.focus_index - 1 + delta) % #focus_order) + 1
	update_visuals()
end

local function move_wheel(delta)
	if state.wheel_mode == "usb" and #state.left_entries > 0 then
		state.left_index = ((state.left_index - 1 + delta) % #state.left_entries) + 1
	end
	if state.wheel_mode == "installed" and #state.right_entries > 0 then
		state.right_index = ((state.right_index - 1 + delta) % #state.right_entries) + 1
	end
	update_visuals()
end

local function handle_start()
	if state.wheel_mode == nil then
		local focus = current_focus()
		if focus == "usb" then
			if #state.left_entries > 0 then
				state.wheel_mode = "usb"
			else
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			end
		elseif focus == "installed" then
			if #state.right_entries > 0 then
				state.wheel_mode = "installed"
			else
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			end
		else
			activate_exit()
		end
		update_visuals()
		return
	end

	if holding.MenuLeft and holding.MenuRight then
		state.wheel_mode = nil
		update_visuals()
		return
	end

	if state.wheel_mode == "usb" then
		begin_operation("install", current_entry("usb"))
	else
		begin_operation("uninstall", current_entry("installed"))
	end
end

local create_input_handler = LoadActor("./InputHandler.lua")
local create_usb_wheel = LoadActor("./UsbWheel.lua")
local create_installed_wheel = LoadActor("./InstalledWheel.lua")

refresh_entries()

local af = Def.ActorFrame{
	OnCommand=function(self)
		t = self
		SCREENMAN:GetTopScreen():AddInputCallback(create_input_handler({
			state = state,
			holding = holding,
			move_focus = move_focus,
			move_wheel = move_wheel,
			handle_start = handle_start,
			leave_screen = leave_screen,
			update_visuals = update_visuals,
		}))
		self:playcommand("Refresh")
	end,
	OffCommand=function()
		unmount_all_devices()
	end,
	PerformOperationCommand=function(self)
		if operation == nil then return end
		if operation.kind == "install" then
			perform_install(operation.entry)
		else
			perform_uninstall(operation.entry)
		end
	end,
}

af[#af+1] = create_usb_wheel({
	x = _screen.cx - panel_offset,
	screen_string = screen_string,
	state = state,
	current_focus = current_focus,
	panel_w = panel_w,
	panel_h = panel_h,
})

af[#af+1] = create_installed_wheel({
	x = _screen.cx + panel_offset,
	screen_string = screen_string,
	state = state,
	current_focus = current_focus,
	panel_w = panel_w,
	panel_h = panel_h,
})

af[#af+1] = Def.ActorFrame{
	Name="ExitBar",
	InitCommand=function(self)
		self:xy(_screen.cx, SCREEN_BOTTOM - 42)
	end,
	RefreshCommand=function(self)
		local active = current_focus() == "exit"
		self:GetChild("Border"):diffuse(active and PlayerColor(PLAYER_1) or color("#071016"))
		self:GetChild("Background"):diffuse(active and color("#293238") or color("#071016"))
		self:GetChild("Background"):diffusealpha(0.92)
		self:GetChild("ExitText"):diffuse(Color.White)
		self:GetChild("Footer"):diffuse(Color.White)
	end,
	Def.Quad{
		Name="Border",
		InitCommand=function(self)
			self:zoomto(392, 54):diffuse(color("#071016"))
		end
	},
	Def.Quad{
		Name="Background",
		InitCommand=function(self)
			self:zoomto(384, 46):diffuse(color("#071016")):diffusealpha(0.92)
		end
	},
	LoadFont("Common Bold")..{
		Name="ExitText",
		Text=screen_string("Exit"),
		InitCommand=function(self)
			self:y(-7):zoom(0.42):diffuse(Color.White)
		end
	},
	LoadFont("Common Normal")..{
		Name="Footer",
		InitCommand=function(self)
			self:y(9):zoom(0.68):diffuse(Color.White)
		end,
		RefreshCommand=function(self)
			self:settext(current_footer())
		end
	},
}

af[#af+1] = Def.ActorFrame{
	Name="BusyOverlay",
	RefreshCommand=function(self)
		self:visible(state.busy)
		self:GetChild("BusyStatus"):settext(state.status)
	end,
	Def.Quad{
		InitCommand=function(self)
			self:xy(_screen.cx, _screen.cy):zoomto(_screen.w, 96):diffuse(color("#071016")):diffusealpha(0.92)
		end
	},
	LoadFont("Common Bold")..{
		Text=screen_string("OverlayText"),
		InitCommand=function(self)
			self:xy(_screen.cx, _screen.cy - 8):zoom(0.95):diffuse(Color.White)
		end
	},
	LoadFont("Common Normal")..{
		Name="BusyStatus",
		InitCommand=function(self)
			self:xy(_screen.cx, _screen.cy + 24):zoom(0.75):diffuse(Color.White)
		end
	},
}

return af
