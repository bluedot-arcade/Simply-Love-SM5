local SMO_CATALOG_URL = "https://stepmaniaonline.net/api/packs"
local SMO_CATALOG_FILE = "smo_packs.csv"
-- USB drives are only used by the pack manager when this file is in their root.
local KEY_FILE = "bsys-pack-manager.key"

local M = {}
local mounted = {}
local mount_counter = 0

local function basename(path)
	return path:gsub("\\", "/"):gsub("/+$", ""):match("([^/]+)$") or path
end

local function strip_extension(name)
	return (name:gsub("%.[^%.]+$", ""))
end

local function by_name(a, b)
	return a.name:lower() < b.name:lower()
end

local function next_mountpoint()
	mount_counter = mount_counter + 1
	return string.format("/@pack-manager-%d/", mount_counter)
end

local function list_dirs(pattern)
	local dirs = {}
	for _, path in ipairs(FILEMAN:GetDirListing(pattern, true, true)) do
		local name = basename(path)
		if name ~= "__MACOSX" then dirs[#dirs+1] = name end
	end
	return dirs
end

local function has_simfile(dir)
	return #FILEMAN:GetDirListing(dir .. "/*.sm") > 0 or #FILEMAN:GetDirListing(dir .. "/*.ssc") > 0
end

-- Strips the characters Windows refuses in folder names, since catalog names become /Songs folders.
local function safe_folder_name(name)
	return (name:gsub('[\\/:%*%?"<>|]', ""):gsub("^%s+", ""):gsub("[%s%.]+$", ""))
end

-- Supported layouts: Songs/<pack>/<song>, <pack>/<song>, or <song> folders at the zip root
-- (installed into a pack named pack_name).
local function inspect_zip(zip_path, pack_name)
	local mp = next_mountpoint()
	if not FILEMAN:Mount("zip", zip_path, mp) then return nil end

	local info
	local root = FILEMAN:DoesFileExist(mp .. "Songs") and mp .. "Songs/" or mp
	local dirs = list_dirs(root .. "*")
	if #dirs > 0 then
		if root == mp and has_simfile(mp .. dirs[1]) then
			info = { groups = { pack_name }, target = "/Songs/" .. pack_name, strip = 0, songs = #dirs }
		else
			local songs = 0
			for _, group in ipairs(dirs) do songs = songs + #list_dirs(root .. group .. "/*") end
			info = { groups = dirs, target = "/Songs", strip = root == mp and 0 or 1, songs = songs }
		end
	end

	FILEMAN:Unmount("zip", zip_path, mp)
	return info
end

function M.unmount_all()
	for _, m in ipairs(mounted) do
		FILEMAN:Unmount(m.fs, m.root, m.mountpoint)
	end
	mounted = {}
end

function M.installed()
	local packs = {}
	for _, group in ipairs(list_dirs("/Songs/*")) do
		packs[#packs+1] = {
			source = "installed",
			id = "installed:" .. group,
			name = group,
			groups = { group },
			songs = #FILEMAN:GetDirListing("/Songs/" .. group .. "/*", true, false),
			readonly = FILEMAN:IsPathReadOnly("/Songs/" .. group),
		}
	end
	table.sort(packs, by_name)
	return packs
end

-- Calls fn(mountpoint) for each ready USB drive that has KEY_FILE in its root,
-- with the drive mounted read-only; the drive stays mounted while fn returns true.
local function each_keyed_drive(fn)
	for _, device in ipairs(MEMCARDMAN:GetStorageDevices()) do
		if device.ready and device.mountDir ~= "" then
			local mp = next_mountpoint()
			if FILEMAN:Mount("dirro", device.mountDir, mp) then
				local keep = FILEMAN:DoesFileExist(mp .. KEY_FILE) and fn(mp)
				if keep then
					mounted[#mounted+1] = { fs = "dirro", root = device.mountDir, mountpoint = mp }
				else
					FILEMAN:Unmount("dirro", device.mountDir, mp)
				end
			end
		end
	end
end

function M.usb_has_key()
	local found = false
	each_keyed_drive(function() found = true end)
	return found
end

function M.usb()
	M.unmount_all()
	local packs = {}
	each_keyed_drive(function(mp)
		local archives = FILEMAN:GetDirListing(mp .. "*.zip", false, true)
		for _, path in ipairs(FILEMAN:GetDirListing(mp .. "*.smzip", false, true)) do
			archives[#archives+1] = path
		end

		for _, path in ipairs(archives) do
			local zip_name = strip_extension(basename(path))
			local info = inspect_zip(path, zip_name)
			if info then
				info.source = "usb"
				info.id = "usb:" .. path
				info.path = path
				info.size = FILEMAN:GetFileSizeBytes(path)
				info.name = #info.groups == 1 and info.groups[1] or zip_name
				packs[#packs+1] = info
			end
		end
		return true
	end)
	table.sort(packs, by_name)
	return packs
end

local function describe_failure(response)
	if response.error then return response.errorMessage or ToEnumShortString(response.error) end
	return "HTTP " .. tostring(response.statusCode)
end

local function parse_catalog(path)
	local file = RageFileUtil.CreateRageFile()
	if not file:Open(path, 1) then
		file:destroy()
		return nil
	end
	local body = file:Read()
	file:Close()
	file:destroy()

	local packs = {}
	for line in body:gmatch("[^\r\n]+") do
		-- ID, "Pack Name", Song Count, Size, Sync, PackType, Substyle, Min Version
		local id, name, songs, size, sync, pack_type, substyle =
			line:match('^(%d+),%s*"(.*)",%s*(%d+),%s*(%d+),%s*([^,]*),%s*([^,]*),%s*([^,]*),')
		if id then
			packs[#packs+1] = {
				source = "smo",
				id = "smo:" .. id,
				smo_id = id,
				name = name,
				groups = { safe_folder_name(name) },
				songs = tonumber(songs),
				size = tonumber(size),
				sync = sync,
				pack_type = pack_type,
				substyle = substyle,
			}
		end
	end
	table.sort(packs, by_name)
	return packs
end

function M.online_allowed()
	return NETWORK:IsUrlAllowed(SMO_CATALOG_URL)
end

-- on_done(packs) on success, on_done(nil, string_key, detail) on failure.
function M.load_catalog(on_done)
	NETWORK:HttpRequest{
		url = SMO_CATALOG_URL,
		downloadFile = SMO_CATALOG_FILE,
		connectTimeout = 10,
		transferTimeout = 60,
		onResponse = function(response)
			if response.error or response.statusCode ~= 200 then
				on_done(nil, "CatalogFailed", describe_failure(response))
				return
			end
			local packs = parse_catalog("/Downloads/" .. SMO_CATALOG_FILE)
			FILEMAN:Remove("/Downloads/" .. SMO_CATALOG_FILE)
			if packs and #packs > 0 then
				on_done(packs)
			else
				on_done(nil, "CatalogFailed", "empty catalog")
			end
		end,
	}
end

local function delete_groups(groups)
	for _, group in ipairs(groups) do
		if FILEMAN:DoesFileExist("/Songs/" .. group) and not FILEMAN:DeleteRecursive("/Songs/" .. group .. "/") then
			return false
		end
	end
	return true
end

local function install_zip(path, info)
	if not delete_groups(info.groups) then return false end
	local ok = FILEMAN:Unzip(path, info.target, info.strip)
	if FILEMAN:DoesFileExist("/Songs/__MACOSX") then
		FILEMAN:DeleteRecursive("/Songs/__MACOSX/")
	end
	return ok
end

function M.install_usb(pack)
	return install_zip(pack.path, pack)
end

function M.delete(pack)
	return delete_groups(pack.groups)
end

-- on_done(true) once installed, on_done(false, string_key, detail) on failure, on_done(false) when cancelled.
-- Returns the request, whose :Cancel() aborts the download.
function M.download(pack, on_progress, on_done)
	local file = "smo-" .. pack.smo_id .. ".zip"
	local path = "/Downloads/" .. file
	-- The trailing slash is required by the SMO download endpoint.
	return NETWORK:HttpRequest{
		url = "https://stepmaniaonline.net/download/pack/" .. pack.smo_id .. "/",
		downloadFile = file,
		connectTimeout = 10,
		transferTimeout = 3600,
		onProgress = on_progress,
		onResponse = function(response)
			if response.error == "HttpErrorCode_Cancelled" then
				on_done(false)
				return
			end
			if response.error or response.statusCode ~= 200 then
				FILEMAN:Remove(path)
				on_done(false, "DownloadFailed", describe_failure(response))
				return
			end
			local info = inspect_zip(path, pack.groups[1])
			local ok = info ~= nil and install_zip(path, info)
			FILEMAN:Remove(path)
			on_done(ok, not ok and "InstallFailed" or nil)
		end,
	}
end

return M
