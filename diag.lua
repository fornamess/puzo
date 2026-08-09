-- PS99 diag :: печатает состояние машины/скрипта, ничего не меняет.
-- Запуск на любой машине фермы:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/fornamess/puzo/main/diag.lua"))()
-- или, если HttpGet отсутствует:
--   loadstring(request({Url="https://raw.githubusercontent.com/fornamess/puzo/main/diag.lua",Method="GET"}).Body)()

local function p(...)
    print("[DIAG]", ...)
end

local ok, err = pcall(function()
    local genv = (getgenv and getgenv()) or _G

    -- 1. Экзекутор и обязательные функции окружения.
    local execName = "?"
    if type(identifyexecutor) == "function" then
        local okI, a, b = pcall(identifyexecutor)
        if okI then execName = tostring(a) .. " " .. tostring(b) end
    end
    p("executor:", execName)
    p("place:", game.PlaceId, "job:", game.JobId)

    local fns = {
        readfile = readfile, writefile = writefile, isfile = isfile,
        isfolder = isfolder, listfiles = listfiles, makefolder = makefolder,
        appendfile = appendfile, delfile = delfile,
        queue_on_teleport = queue_on_teleport,
        request = request, http_request = http_request,
    }
    for _, name in ipairs({ "readfile", "writefile", "isfile", "isfolder", "listfiles",
        "makefolder", "appendfile", "delfile", "queue_on_teleport", "request", "http_request" }) do
        p("fn:", name, typeof(fns[name]))
    end

    -- 2. Состояние PS99 Auto.
    local app, ctl = genv.__PS99, genv.__PS99_CTL
    if app then
        p("app: build=" .. tostring(app.BuildId) .. " ver=" .. tostring(app.Version)
            .. " ready=" .. tostring(app.Ready) .. " running=" .. tostring(app.Running)
            .. " stage=" .. tostring(app.stage))
    else
        p("app: nil")
    end
    if ctl then
        p("ctl: state=" .. tostring(ctl.state) .. " err=" .. tostring(ctl.error))
    else
        p("ctl: nil")
    end
    p("loads:", tostring(genv.__PS99_LOADS))
    p("bootSource:", type(genv.__PS99_BOOT_SOURCE) == "string"
        and ("present " .. #genv.__PS99_BOOT_SOURCE .. "B") or "nil")

    local farm = genv.__PINATA_FIESTA_AUTOFARM
    if type(farm) == "table" then
        local fs = type(farm.State) == "table" and farm.State or {}
        p("fiesta: running=" .. tostring(farm.Running) .. " phase=" .. tostring(fs.phase)
            .. " raids=" .. tostring(fs.raids) .. " loot=" .. tostring(fs.lootOpened))
    else
        p("fiesta: nil")
    end

    -- 3. Манифест и журналы ошибок на диске.
    local player = game:GetService("Players").LocalPlayer
    local root = player and ("PS99/state/%d/"):format(player.UserId) or nil
    local function show(path, label)
        if not root or typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
            p(label, "no file api")
            return
        end
        local okF, exists = pcall(isfile, path)
        if not okF or exists ~= true then
            p(label, "missing")
            return
        end
        local okR, body = pcall(readfile, path)
        p(label, okR and tostring(body):sub(1, 240) or "unreadable")
    end
    if root then
        show(root .. "active_build.txt", "manifest:")
        show(root .. "bootstrap_error.log", "bootstrap_error:")
        show(root .. "persist_error.log", "persist_error:")
    end

    -- 4. Автоэкзек: что лежит и каких версий (источник «Script '' line NN» ошибок).
    if typeof(listfiles) == "function" then
        local okL, files = pcall(listfiles, "autoexec")
        if okL and type(files) == "table" then
            if #files == 0 then p("autoexec: пусто") end
            for _, f in ipairs(files) do
                local okR, body = pcall(readfile, f)
                if okR and type(body) == "string" then
                    local build = body:match("PS99_BUILD_ID:%s*([^\r\n]+)")
                    p("autoexec:", tostring(f), "size=" .. #body
                        .. (build and (" build=" .. build) or ""))
                else
                    p("autoexec:", tostring(f), "unreadable")
                end
            end
        else
            p("autoexec: listfiles failed")
        end
    else
        p("autoexec: нет listfiles на этом экзекуторе")
    end
end)

if not ok then p("diag error:", err) end
p("done")
