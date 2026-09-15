-- Moves this cabinet's music wheel to the song a lobby controller names.
--
-- It sends nothing: the lobby's song is still fixed by the player who confirms
-- it. A command received away from song select waits there, and a newer one
-- replaces it. A parked cabinet ignores it.

local pendingSongPath = nil

local FindSong = function(songPath)
	local song = SONGMAN:FindSong(songPath)
	local songFolder = songPath:split("/")[2]
	if not song and songFolder then
		song = SONGMAN:FindSong(songFolder)
	end
	return song
end

local ApplyPendingSong = function()
	local screen = SCREENMAN:GetTopScreen()
	if pendingSongPath == nil or screen == nil or screen:GetName() ~= "ScreenSelectMusic" then
		return
	end

	local songPath = pendingSongPath
	pendingSongPath = nil
	if IsParkedCabinet() then
		return
	end

	local song = FindSong(songPath)
	local wheel = screen:GetMusicWheel()
	if song and wheel then
		wheel:SelectSong(song)
		-- Nudging the wheel makes song select pick up the selection.
		wheel:Move(1)
		wheel:Move(-1)
		wheel:Move(0)
	end
end

RegisterLobbyCommand("changeSong", function(payload)
	if type(payload.songPath) ~= "string" or payload.songPath == "" then
		return
	end
	pendingSongPath = payload.songPath
	ApplyPendingSong()
end)

return {
	ScreenSelectMusic = Def.Actor{
		ModuleCommand=function(self)
			ApplyPendingSong()
		end,
	},
}
