local utils = require("./utils.luau")
local artwork = require("./artwork.luau")

local M = {}

local destination = "dev.noctalia.Mpris"
local objectPath = "/dev/noctalia/Mpris"
local interface = "dev.noctalia.Mpris"

local function unwrap(value)
    if type(value) ~= "table" then
        return value
    end

    if value.data ~= nil and value.type ~= nil then
        return unwrap(value.data)
    end

    local result = {}

    for key, item in pairs(value) do
        result[key] = unwrap(item)
    end

    return result
end

local function call(method, signature, arguments, callback)
    local command = {
        "busctl", "--user", "--json=short", "call",
        destination, objectPath, interface, method
    }

    if signature ~= nil and signature ~= "" then
        table.insert(command, signature)

        for _, argument in ipairs(arguments or {}) do
            table.insert(command, tostring(argument))
        end
    end

    noctalia.runAsync(command, function(result)
        if result.exitCode ~= 0 then
            callback(nil)
            return
        end

        local decoded = noctalia.json.decode(utils.trim(result.stdout))

        if decoded == nil then
            callback(nil)
            return
        end

        callback(unwrap(decoded.data))
    end)
end

local function clear(state)
    state.player = ""
    state.players = {}
    state.title = "Sin reproducción"
    state.artist = ""
    state.album = ""
    state.art = ""
    state.artUrl = ""
    state.playerLabel = ""
    state.status = "Stopped"
    state.position = 0
    state.length = 0
    state.canPrevious = false
    state.canNext = false
    state.canSeek = false
end

local function scalar(value, fallback)
    if type(value) == "table" then
        return value[1] ~= nil and value[1] or fallback
    end

    return value ~= nil and value or fallback
end

local function playerName(busName, identity)
    if identity ~= "" then
        return identity
    end

    return busName:gsub("^org%.mpris%.MediaPlayer2%.", "")
end

local function applyPlayer(state, player)
    local busName = scalar(player.bus_name, "")
    local identity = scalar(player.identity, "")
    local artists = player.artists or {}

    state.player = busName
    state.playerLabel = playerName(busName, identity)
    state.title = scalar(player.title, "Sin reproducción")
    state.artist = table.concat(artists, ", ")
    state.album = scalar(player.album, "")
    state.status = scalar(player.playback_status, "Stopped")

    if not state.seeking then
        state.position = tonumber(scalar(player.position_us, 0)) / 1000000
    end

    state.length = tonumber(scalar(player.length_us, 0)) / 1000000
    state.canPrevious = scalar(player.can_go_previous, false) == true
    state.canNext = scalar(player.can_go_next, false) == true
    state.canSeek = scalar(player.can_seek, false) == true

    return scalar(player.art_url, "")
end

function M.refresh(state, callback)
    noctalia.runAsync({
        "playerctl", "metadata", "--format",
        "{{playerName}}|||{{status}}|||{{artist}}|||{{title}}|||{{album}}|||{{mpris:artUrl}}|||{{position}}|||{{mpris:length}}"
    }, function(result)
        if result.exitCode ~= 0 or utils.trim(result.stdout) == "" then
            clear(state)
            callback()
            return
        end

        local parts = utils.split(utils.trim(result.stdout), "|||")

        state.player = utils.trim(parts[1] or "")
        state.playerLabel = playerName(state.player, "")
        state.status = utils.trim(parts[2] or "Stopped")
        state.artist = utils.trim(parts[3] or "")
        state.title = utils.trim(parts[4] or "Sin reproducción")
        state.album = utils.trim(parts[5] or "")

        if not state.seeking then
            state.position = (tonumber(utils.trim(parts[7] or "")) or 0) / 1000000
        end

        state.length = (tonumber(utils.trim(parts[8] or "")) or 0) / 1000000
        state.canPrevious = true
        state.canNext = true
        state.canSeek = state.length > 0

        local artUrl = utils.trim(parts[6] or "")

        if state.artUrl == artUrl then
            callback()
            return
        end

        state.artUrl = artUrl

        artwork.resolve(artUrl, function(path)
            state.art = path
            callback()
        end)
    end)
end

local function control(method, callback)
    call(method, "", {}, function()
        callback()
    end)
end

function M.toggle(state, callback)
    control("PlayPauseActive", callback)
end

function M.previous(state, callback)
    if state.canPrevious then
        control("PreviousActive", callback)
    end
end

function M.next(state, callback)
    if state.canNext then
        control("NextActive", callback)
    end
end

local function cyclePlayer(state, direction, callback)
    call("GetPlayers", "", {}, function(data)
        local players = data and data[1] or {}

        if #players <= 1 then
            callback()
            return
        end

        local current = 1

        for index, player in ipairs(players) do
            if scalar(player.bus_name, "") == state.player then
                current = index
                break
            end
        end

        local target = ((current - 1 + direction) % #players) + 1
        local busName = scalar(players[target].bus_name, "")

        call("SetActivePlayerPreference", "s", { busName }, function()
            callback()
        end)
    end)
end

function M.previousPlayer(state, callback)
    cyclePlayer(state, -1, callback)
end

function M.nextPlayer(state, callback)
    cyclePlayer(state, 1, callback)
end

function M.seekPreview(state, value)
    if state.player == "" or state.length <= 0 or not state.canSeek then
        return
    end

    local target = tonumber(value)

    if target == nil then
        return
    end

    target = utils.clamp(target, 0, state.length)
    state.seeking = true
    state.seekTarget = target
    state.position = target
end

function M.seekCommit(state, value, callback)
    if state.player == "" or state.length <= 0 or not state.canSeek then
        state.seeking = false
        return
    end

    local target = tonumber(value) or state.seekTarget
    target = utils.clamp(target, 0, state.length)
    state.seekTarget = target
    state.position = target

    call("SetPositionActive", "x", { math.floor(target * 1000000) }, function()
        state.seeking = false
        callback()
    end)
end

function M.seekBackward(state, callback)
    if state.canSeek then
        call("SeekActive", "x", { -10000000 }, function()
            callback()
        end)
    end
end

function M.seekForward(state, callback)
    if state.canSeek then
        call("SeekActive", "x", { 10000000 }, function()
            callback()
        end)
    end
end

return M
