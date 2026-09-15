# Simply Love Modules
If one wants to write code that needs to run on specific screens, Simply Love defines this notion of "modules". This is useful if one wants to incorporate third-party code into the theme without needing to edit the Simply Love files directly.

## Inner Workings
When StepMania loads, we load all the `*.lua` files in the `/Modules` directory. These modules must define and return a table where each entry in the table is a mapping from ScreenName to a single Actor/ActorFrame. These Actors will later get accumulated and added as child ActorFrames of ScreenSystemLayer. Every Actor must at least have a `ModuleCommand`. This is what gets executed whenever we load into a new screen.

When defining variables, remember to not have globals as they may pollute the global namespace.

For example, a module may look like the following:

```lua
local t = {}

t["ScreenSelectMusic"] = Def.ActorFrame {
    ModuleCommand=function(self)
        SCREENMAN:SystemMessage("hello from ScreenSelectMusic")
    end
}

t[Branch.GameplayScreen()] = Def.ActorFrame {
    ModuleCommand=function(self)
        SCREENMAN:SystemMessage("hello from ScreenGameplay")
    end
}

return t
```

In the above example, we will simply SystemMessage a string once we load `ScreenSelectMusic` and `ScreenGameplay` respectively.

## Lobby Modules
A module can act on commands a lobby controller sends to this cabinet, and add fields to the players this cabinet reports to the lobby, without editing `Scripts/SL-OnlineHelpers.lua`. Both registries are keyed by name, so reloading the theme replaces an entry rather than duplicating it.

- `RegisterLobbyCommand(command, handler)` runs `handler(payload)` for every `machineCommand` named `command`. Machines never answer a command. A command without a handler is ignored, and an error in a handler is reported without breaking the connection.
- `RegisterLobbyPlayerFields(name, provider)` calls `provider(player, screenName)` for every joined player each time the machine state is sent, and adds the fields of the table it returns to that player. It never replaces a field the theme itself sends. Providers run on every send, including throttled sends during gameplay, so they must be cheap.

A lobby module may also rely on `GetLobbyState()` and the `Lobby*Changed` messages, `GetCabinetId()`, `IsPlaceholderSide(player)` and `IsParkedCabinet()`, and on broadcasting `UpdateMachineState` to send the machine state at once.
