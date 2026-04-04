return function(args)
	local side = args.side
	local screen_string = args.screen_string
	local state = args.state
	local current_focus = args.current_focus
	local panel_w = args.panel_w
	local panel_h = args.panel_h

	local function row_text(entry, selected)
		if entry == nil then
			return ""
		end
		return selected and ("> " .. entry.label) or entry.label
	end

	return Def.ActorFrame{
		Name=args.name,
		InitCommand=function(self)
			self:xy(args.x, _screen.cy - 5)
		end,
		RefreshCommand=function(self)
			local active = current_focus() == side
			self:GetChild("Border"):diffuse(active and PlayerColor(PLAYER_1) or color("#8c8c8c"))
			self:GetChild("Title"):diffuse(active and PlayerColor(PLAYER_1) or Color.White)
			self:GetChild("List"):playcommand("RefreshList")
		end,

		Def.Quad{
			Name="Border",
			InitCommand=function(self)
				self:zoomto(panel_w + 8, panel_h + 8):diffuse(color("#071016"))
			end
		},
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(panel_w, panel_h):diffuse(color("#071016")):diffusealpha(0.86)
			end
		},
		LoadFont("Common Bold")..{
			Name="Title",
			Text=screen_string(args.title_key),
			InitCommand=function(self)
				self:y((-panel_h/2) + 38):zoom(0.82):diffuse(Color.White)
			end
		},
		Def.BitmapText{
			Name="List",
			Font="Common Normal",
			InitCommand=function(self)
				self:xy((-panel_w/2) + 34, (-panel_h/2) + 86):align(0, 0):zoom(0.72):maxwidth((panel_w - 68) / 0.72)
			end,
			RefreshListCommand=function(self)
				local entries = side == "usb" and state.left_entries or state.right_entries
				local index = side == "usb" and state.left_index or state.right_index
				if #entries == 0 then
					self:settext(side == "usb" and screen_string("EmptyUSB") or screen_string("EmptyInstalled"))
					self:diffuse(color("#bbbbbb"))
					return
				end

				local lines = {}
				for i, entry in ipairs(entries) do
					lines[#lines+1] = row_text(entry, state.wheel_mode == side and i == index)
				end
				self:settext(table.concat(lines, "\n\n"))
				self:diffuse(Color.White)
			end
		},
	}
end
