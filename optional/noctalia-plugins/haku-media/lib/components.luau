local utils =
    require("./utils.luau")

local M = {}

local function cover(state)
    if state.art ~= "" then
        return ui.image({
            path = state.art,
            width = 126,
            height = 126,
            radius = 14,
            fit = "cover",
            border = "primary/0.45",
            borderWidth = 1
        })
    end

    return ui.box({
        width = 126,
        height = 126,
        radius = 14,
        fill = "#151515",
        border = "primary/0.35",
        borderWidth = 1
    })
end

local function header(state)
    return ui.row({
        minWidth = 280,
        align = "center",
        justify = "space_between"
    }, {
        ui.label({
            text = state.title,
            fontSize = 17,
            fontWeight = "bold",
            color = "primary",
            maxWidth = 215,
            maxLines = 2
        }),

        ui.label({
            text =
                state.playerLabel
                or utils.playerLabel(state.player),

            fontSize = 10,
            color = "primary/0.6",
            maxWidth = 60,
            maxLines = 1
        })
    })
end

local function metadata(state)
    return ui.column({
        gap = 4
    }, {
        ui.label({
            text = state.artist,
            fontSize = 13,
            color = "on_surface/0.8",
            maxWidth = 280,
            maxLines = 1
        }),

        ui.label({
            text = state.album,
            fontSize = 11,
            color = "on_surface/0.45",
            maxWidth = 280,
            maxLines = 1
        })
    })
end

local function seekbar(state)
    local sliderMax =
        state.length

    if sliderMax <= 0 then
        sliderMax = 1
    end

    local sliderValue =
        utils.clamp(
            state.position,
            0,
            sliderMax
        )

    return ui.column({
        gap = 2
    }, {
        ui.slider({
            min = 0,
            max = sliderMax,
            step = 1,
            value = sliderValue,
            controlSize = "sm",

            enabled = state.canSeek and state.length > 0,

            onChange = "seekPreview",
            onDragEnd = "seekCommit"
        }),

        ui.row({
            minWidth = 280,
            justify = "space_between",
            align = "center"
        }, {
            ui.label({
                text =
                    utils.formatTime(
                        state.position
                    ),

                fontSize = 10,
                color = "on_surface/0.55"
            }),

            ui.label({
                text =
                    utils.formatTime(
                        state.length
                    ),

                fontSize = 10,
                color = "on_surface/0.55"
            })
        })
    })
end

local function controls(state)
    local playing =
        state.status == "Playing"

    return ui.row({
        minWidth = 280,
        gap = 8,
        justify = "center",
        align = "center"
    }, {
        ui.button({
            glyph = "chevron-left",
            variant = "ghost",
            controlSize = "sm",
            tooltip = "Reproductor anterior",
            onClick = "previousPlayer"
        }),

        ui.button({
            glyph = "player-skip-back",
            variant = "ghost",
            controlSize = "sm",
            enabled = state.canPrevious,
            tooltip = "Pista anterior",
            onClick = "previous"
        }),

        ui.button({
            glyph =
                playing
                and "player-pause"
                or "player-play",

            variant = "primary",
            controlSize = "sm",

            tooltip =
                playing
                and "Pausa"
                or "Reproducir",

            onClick = "toggle"
        }),

        ui.button({
            glyph = "player-skip-forward",
            variant = "ghost",
            controlSize = "sm",
            enabled = state.canNext,
            tooltip = "Pista siguiente",
            onClick = "next"
        }),

        ui.button({
            glyph = "chevron-right",
            variant = "ghost",
            controlSize = "sm",
            tooltip = "Reproductor siguiente",
            onClick = "nextPlayer"
        })
    })
end

function M.render(state)
    panel.render(
        ui.row({
            padding = 12,
            gap = 18,
            align = "center"
        }, {
            cover(state),

            ui.column({
                gap = 6,
                flexGrow = 1
            }, {
                header(state),

                metadata(state),

                ui.spacer({
                    height = 2
                }),

                seekbar(state),

                controls(state)
            })
        })
    )
end

return M
