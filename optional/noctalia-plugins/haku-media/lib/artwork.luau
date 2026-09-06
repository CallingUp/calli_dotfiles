local utils =
    require("./utils.luau")

local M = {}

function M.resolve(url, callback)
    url = utils.trim(url)

    if url == "" then
        callback("")
        return
    end

    if string.sub(url, 1, 7) == "file://" then
        callback(
            string.sub(url, 8)
        )

        return
    end

    if string.sub(url, 1, 1) == "/" then
        callback(url)
        return
    end

    local http =
        string.sub(url, 1, 7)
        == "http://"

    local https =
        string.sub(url, 1, 8)
        == "https://"

    if not http and not https then
        callback("")
        return
    end

    local destination =
        "/tmp/haku-media-cover"

    noctalia.download(
        url,
        destination,
        function(result)
            if result then
                callback(destination)
            else
                callback("")
            end
        end
    )
end

return M

