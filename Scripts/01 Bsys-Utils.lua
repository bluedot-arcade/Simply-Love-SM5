BsysUtils = {}

BsysUtils.IsFlagSet = function(flagFilePath)
    local f = RageFileUtil.CreateRageFile()

    -- Open the file for reading (1:READ)
    if not f:Open(flagFilePath, 1) then
        Warn("[BSYS-Utils] Cannot open file " .. flagFilePath .. ": " .. f:GetError())
        f:ClearError()
        f:destroy()
        return false
    end

    local content = f:Read()
    f:Close()
    f:destroy()

    -- Trim leading and trailing whitespace
    content = content:match("^%s*(.-)%s*$") 

    return content == "1"
end

BsysUtils.SetFlag = function(flagFilePath)
	local f = RageFileUtil.CreateRageFile()

	-- Open the file for writing (2:WRITE + 4:STREAMED)
	if not f:Open(flagFilePath, 6) then
		Warn("[BSYS-Utils] Cannot open file " .. flagFilePath .. ": " .. f:GetError())
		f:ClearError()
		f:destroy()

		SOUND:PlayOnce(THEME:GetPathS("Common", "Invalid"))
		return
	end

	f:Write("1")
	f:Close()
	f:destroy()

	SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
end

BsysUtils.GetIpAddresses = function()
    local addresses = {}
    local f = RageFileUtil.CreateRageFile()
    local ipaddrFilePath = "Save/Run/ipaddr"

    -- Open the file for reading (1:READ)
    if not f:Open(ipaddrFilePath, 1) then
        Warn("[BSYS-Utils] Cannot open file " .. flagFilePath .. ": " .. f:GetError())
        f:ClearError()
        f:destroy()
        return {}
    end

    local content = f:Read()
    
    f:Close()
    f:destroy()

    -- Each line contains a network interface and its IP address
    -- in the format of "interface: ipaddr" (e.g. "eth0:192.168.1.116)
    for line in content:gmatch("[^\r\n]+") do
        local interface, ipaddr = line:match("([^=]+)=([^=]+)")
        if interface and ipaddr then
            addresses[interface] = ipaddr
        end
    end
    
    return addresses
end

BsysUtils.GetEthernetIpAddress = function()
    local addresses = BsysUtils.GetIpAddresses()

    -- Return the ip address of the first ethernet interface found.
    -- An ethernet interface starts with either "eth" or "enp" (e.g. "eth0", "enp0s3")
    for interface, ipaddr in pairs(addresses) do
        if interface:match("^(eth)") or interface:match("^(enp)") then
            return ipaddr
        end
    end

    Warn ("[BSYS-Utils] No ethernet interface found")

    return nil
end

BsysUtils.GetWlanIpAddress = function()
    local addresses = BsysUtils.GetIpAddresses()

    -- Return the ip address of the first wlan interface found.
    -- A wlan interface starts either with "wlan" or "wlp" (e.g. "wlan0", "wlp3s0")
    for interface, ipaddr in pairs(addresses) do
        if interface:match("^(wlan)") or interface:match("^(wlp)") then
            return ipaddr
        end 
    end

    Warn ("[BSYS-Utils] No wlan interface found")

    return nil
end

BsysUtils.GetBlueNetIpAddress = function()
    local addresses = BsysUtils.GetIpAddresses()

    -- Return the ip address of the first BlueNet interface found.
    -- A BlueNet interface starts with "bnet" (e.g. "bnet0")
    for interface, ipaddr in pairs(addresses) do
        if interface:match("^(bnet)") then
            return ipaddr
        end
    end

    Warn ("[BSYS-Utils] No bnet interface found")

    return nil
end