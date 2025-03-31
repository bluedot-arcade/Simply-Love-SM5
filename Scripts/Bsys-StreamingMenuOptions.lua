BsysStreamingMenuOptionRows = {}

-- -----------------------------------------------------------------------
-- Streaming Menu Options

BsysStreamingMenuOptionRows.Streaming = function()
	local choices = { "Off", "On" }
	local flagFilePath = "Save/Run/itg-stream-enabled"

	return {
		Name = "Streaming",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectOne",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn)
			local f = RageFileUtil.CreateRageFile()	

			-- Open the file for reading (1:READ)
			if not f:Open(flagFilePath, 1) then
				Warn("[BSYS-StreamingOptions] Cannot open file " .. flagFilePath .. ": " .. f:GetError())
				f:ClearError()
				f:destroy()
				return
			end
			
			local content = f:Read()

			-- Trim leading and trailing whitespace
			content = content:match("^%s*(.-)%s*$") 

			if content == "1" then
				list[2] = true 
			else
				list[1] = true
			end

			f:Close()
			f:destroy()
		end,
		SaveSelections = function(self, list, pn)
			local f = RageFileUtil.CreateRageFile()

			-- Open the file for writing (2:WRITE + 4:STREAMED)	
			if not f:Open(flagFilePath, 6) then
				Warn("[BSYS-StreamingOptions] Cannot open file " .. flagFilePath .. ": " .. f:GetError())
				f:ClearError()
				f:destroy()
				return
			end
		
			if list[1] then
				f:Write("0")
			else
				f:Write("1")
			end
			
			f:Close()
			f:destroy()
		end,
	}
end

BsysStreamingMenuOptionRows.StreamAddress = function()
	local ethernetIp = BsysUtils.GetEthernetIpAddress()
	
	local choices;
	if ethernetIp then
		choices = { "rtmp://" .. ethernetIp .. "/live/itgmania" }
	else
		choices = { "Not available" }
	end

	return {
		Name = "StreamAddress",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectNone",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn) end,
		SaveSelections = function(self, list, pn) end,
	}
end
