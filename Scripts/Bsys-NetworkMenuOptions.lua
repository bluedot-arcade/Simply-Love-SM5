BsysNetworkMenuOptionRows = {}

-- -----------------------------------------------------------------------
-- Network Menu Options

BsysNetworkMenuOptionRows.EthernetAddress = function()
	local ethernetIp = BsysUtils.GetEthernetIpAddress()
	local choices;
	if ethernetIp then
		choices = { ethernetIp }
	else
		choices = { "Not connected" }
	end

	return {
		Name = "EthernetAddress",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectNone",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn) end,
		SaveSelections = function(self, list, pn) end,
	}
end

BsysNetworkMenuOptionRows.WlanAddress = function()
	local wlanIp = BsysUtils.GetWlanIpAddress()
	local choices;
	if wlanIp then
		choices = { wlanIp }
	else
		choices = { "Not connected" }
	end

	return {
		Name = "WlanAddress",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectNone",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn) end,
		SaveSelections = function(self, list, pn) end,
	}
end

BsysNetworkMenuOptionRows.BnetAddress = function()
	local bnetIp = BsysUtils.GetBlueNetIpAddress()
	local choices;
	if bnetIp then
		choices = { bnetIp }
	else
		choices = { "Not connected" }
	end

	return {
		Name = "BnetAddress",
		Choices = choices,
		LayoutType = "ShowAllInRow",
		SelectType = "SelectNone",
		OneChoiceForAllPlayers = true,
		ExportOnChange = false,
		LoadSelections = function(self, list, pn) end,
		SaveSelections = function(self, list, pn) end,
	}
end