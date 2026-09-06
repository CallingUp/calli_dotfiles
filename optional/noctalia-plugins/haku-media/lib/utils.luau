local M = {}

function M.trim(value)
    local result = value or ""

    result = result:gsub("^%s+", "")
    result = result:gsub("%s+$", "")

    return result
end

function M.split(value, separator)
    local parts = {}
    local start = 1

    while true do
        local pos = string.find(
            value,
            separator,
            start,
            true
        )

        if not pos then
            table.insert(
                parts,
                string.sub(value, start)
            )

            break
        end

        table.insert(
            parts,
            string.sub(
                value,
                start,
                pos - 1
            )
        )

        start = pos + #separator
    end

    return parts
end

function M.clamp(value, minimum, maximum)
    value = tonumber(value) or minimum

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function M.formatTime(value)
    value = math.floor(
        tonumber(value) or 0
    )

    local minutes =
        math.floor(value / 60)

    local seconds =
        value % 60

    return string.format(
        "%d:%02d",
        minutes,
        seconds
    )
end

function M.playerLabel(name)
    if name == nil or name == "" then
        return ""
    end

    local result = name

    result =
        result:gsub(
            "%.instance.*$",
            ""
        )

    if #result > 0 then
        result =
            string.upper(
                string.sub(result, 1, 1)
            )
            .. string.sub(result, 2)
    end

    return result
end

function M.findIndex(values, target)
    for index, value in ipairs(values) do
        if value == target then
            return index
        end
    end

    return nil
end

return M
