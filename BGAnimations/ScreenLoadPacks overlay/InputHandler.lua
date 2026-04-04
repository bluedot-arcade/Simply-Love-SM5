return function(context)
	return function(event)
		if not event.button or context.state.busy then
			return false
		end

		if event.type == "InputEventType_FirstPress" then
			if event.GameButton == "MenuLeft" or event.GameButton == "MenuRight" then
				context.holding[event.GameButton] = true
				local delta = event.GameButton == "MenuRight" and 1 or -1
				if context.state.wheel_mode == nil then
					context.move_focus(delta)
				else
					local other = event.GameButton == "MenuRight" and "MenuLeft" or "MenuRight"
					if context.holding[other] then
						context.state.wheel_mode = nil
						context.update_visuals()
					else
						context.move_wheel(delta)
					end
				end
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
			elseif event.GameButton == "Start" then
				SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
				context.handle_start()
			elseif event.GameButton == "Select" or event.GameButton == "Back" then
				SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
				if context.state.wheel_mode == nil then
					context.leave_screen()
				else
					context.state.wheel_mode = nil
					context.update_visuals()
				end
			end
		elseif event.type == "InputEventType_Release" then
			if event.GameButton == "MenuLeft" or event.GameButton == "MenuRight" then
				context.holding[event.GameButton] = false
			end
		end

		return false
	end
end
