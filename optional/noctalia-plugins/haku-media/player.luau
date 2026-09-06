local mpris = require("./lib/mpris.luau")
local components = require("./lib/components.luau")

local state = {
    player = "",
    players = {},
    manualPlayer = false,

    title = "Sin reproducción",
    artist = "",
    album = "",
    art = "",
    artUrl = "",
    status = "Stopped",

    position = 0,
    length = 0,

    seeking = false,
    seekTarget = 0,

    canPrevious = false,
    canNext = false,
    canSeek = false
}

local refreshing = false

local function hoverCommand(action)
    noctalia.runAsync({
        "sh",
        "-lc",
        "$HOME/.local/bin/haku-media-hover " .. action
    }, function() end)
end

local function render()
    components.render(state)
end

local function refresh()
    if refreshing then
        return
    end

    refreshing = true

    mpris.refresh(state, function()
        refreshing = false
        render()
    end)
end

function toggle()
    mpris.toggle(state, refresh)
end

function previous()
    mpris.previous(state, refresh)
end

function next()
    mpris.next(state, refresh)
end

function previousPlayer()
    mpris.previousPlayer(state, refresh)
end

function nextPlayer()
    mpris.nextPlayer(state, refresh)
end

function seekPreview(value)
    mpris.seekPreview(state, value)
end

function seekCommit(value)
    mpris.seekCommit(state, value, refresh)
end

function seekBackward()
    mpris.seekBackward(state, refresh)
end

function seekForward()
    mpris.seekForward(state, refresh)
end

function onOpen()
    panel.setWantsSecondTicks(true)
    refresh()
end

function onClose()
    hoverCommand("panel-close")
end

function onSurfaceHover(hovered)
    if hovered then
        hoverCommand("panel-enter")
    else
        hoverCommand("panel-leave")
    end
end

function update()
    if not state.seeking then
        refresh()
    end
end
