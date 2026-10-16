local M = {}

local fallback = {
    accent = "B99573",
    active = "D7B894",
    inactive = "705542",
    text = "E8DCC8",
    muted = "967F6B",
    bg = "000000",
    surface = "211813",
    surface_alt = "30241C",
    red = "BF616A",
    green = "A3BE8C",
    yellow = "D7B894",
    blue = "E8DCC8",
    purple = "C5A48C",
    cyan = "B99573",
}

local function palette()
    local path = vim.fn.expand("~/.config/haku/palette.conf")
    local file = io.open(path, "r")
    if not file then
        return {}
    end

    local content = file:read("*a")
    file:close()
    local values = {}
    for key, value in content:gmatch('([A-Z_]+)="#(%x%x%x%x%x%x)"') do
        values[key] = value
    end
    return values
end

local function apply()
    local c = {}
    local values = palette()
    local names = { accent = "ACCENT", active = "ACTIVE", inactive = "INACTIVE",
        text = "FOREGROUND", muted = "MUTED", bg = "BACKGROUND", surface = "SURFACE",
        surface_alt = "SURFACE_ALT", red = "ERROR", green = "SUCCESS", yellow = "WARNING" }
    for name in pairs(fallback) do
        c[name] = values[names[name]] or fallback[name]
    end
    vim.g.haku_colors = c

    local hl = vim.api.nvim_set_hl
    local hex = function(name) return "#" .. c[name] end

    hl(0, "Normal", { fg = hex("text"), bg = hex("bg") })
    hl(0, "NormalFloat", { fg = hex("text"), bg = hex("surface") })
    hl(0, "FloatBorder", { fg = hex("accent"), bg = hex("surface") })
    hl(0, "FloatTitle", { fg = hex("accent"), bg = hex("surface"), bold = true })
    hl(0, "CursorLine", { bg = "#" .. c.surface_alt })
    hl(0, "CursorLineNr", { fg = hex("accent"), bold = true })
    hl(0, "LineNr", { fg = hex("muted") })
    hl(0, "Visual", { bg = "#" .. c.inactive })
    hl(0, "Search", { fg = hex("bg"), bg = hex("accent"), bold = true })
    hl(0, "IncSearch", { fg = hex("bg"), bg = hex("active"), bold = true })
    hl(0, "Pmenu", { fg = hex("text"), bg = hex("surface") })
    hl(0, "PmenuSel", { fg = hex("bg"), bg = hex("accent"), bold = true })
    hl(0, "WinSeparator", { fg = hex("inactive") })
    hl(0, "StatusLine", { fg = hex("text"), bg = hex("surface") })
    hl(0, "StatusLineNC", { fg = hex("muted"), bg = hex("surface") })
    hl(0, "Comment", { fg = hex("muted"), italic = true })
    hl(0, "Constant", { fg = hex("purple") })
    hl(0, "String", { fg = hex("green") })
    hl(0, "Identifier", { fg = hex("blue") })
    hl(0, "Function", { fg = hex("accent"), bold = true })
    hl(0, "Statement", { fg = hex("active"), bold = true })
    hl(0, "Keyword", { fg = hex("active"), bold = true })
    hl(0, "Type", { fg = hex("yellow") })
    hl(0, "Special", { fg = hex("cyan") })
    hl(0, "Error", { fg = hex("red"), bold = true })
    hl(0, "DiagnosticError", { fg = hex("red") })
    hl(0, "DiagnosticWarn", { fg = hex("yellow") })
    hl(0, "DiagnosticInfo", { fg = hex("blue") })
    hl(0, "DiagnosticHint", { fg = hex("cyan") })
    hl(0, "GitSignsAdd", { fg = hex("green") })
    hl(0, "GitSignsChange", { fg = hex("yellow") })
    hl(0, "GitSignsDelete", { fg = hex("red") })
end

function M.setup()
    apply()
    vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
        callback = apply,
    })
end

return M
