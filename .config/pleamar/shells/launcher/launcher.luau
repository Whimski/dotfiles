-- launcher: the apps (from the apps service), searching them, launching,
-- and the run-a-command mode with zsh-like Tab completion.

local HOME = "/home/tobi"
local MAX = 128

local apps = {}      -- every app, as the service gives them
local shown = {}     -- what each result row is

local function lower(s) return string.lower(s or "") end

local function filter()
    local q = lower(text.query):gsub("^%s+", ""):gsub("%s+$", "")
    shown = {}
    for _, a in ipairs(apps) do
        local hay = lower(a.local_name or a.name) .. " " .. lower(a.comment) .. " "
            .. lower(a.generic_name) .. " " .. lower(a.keywords)
        if q == "" or string.find(hay, q, 1, true) then table.insert(shown, a) end
    end
    table.sort(shown, function(x, y) return lower(x.local_name or x.name) < lower(y.local_name or y.name) end)
    local rows = {}
    for i, a in ipairs(shown) do
        if i > MAX then break end
        local comment = a.comment or ""
        rows[i] = { name = a.local_name or a.name or "?", comment = comment,
                    has_comment = comment ~= "", icon = a.icon or "" }
    end
    model.results = rows
    fact.sel = 0
end

sys.watch("apps", function(list)
    apps = list or {}
    filter()
end)

-- ---- completion (command mode) ----
local comp_base = ""     -- the text before what is being completed
local comps = {}

local function clear_comps()
    comps = {}
    model.comps = {}
    fact.comp_sel = -1
end

local function set_query(t)
    text.query = t
    fact.typed = t ~= ""
end

on("text:query", function(v)
    fact.typed = (v or "") ~= ""
    if fact.cmd then clear_comps() else filter() end
end)

-- Open on the monitor in use, with an empty field.
on("toggle", function()
    if fact.open then fact.open = false; return end
    set_query("")
    fact.cmd = false
    clear_comps()
    filter()
    run("hyprctl", { "monitors", "-j" }, function(out, code)
        if code == 0 and out then
            local ok, list = pcall(json.decode, out)
            if ok and type(list) == "table" then
                for _, m in ipairs(list) do if m.focused then text.here = m.name end end
            end
        end
        fact.open = true
    end)
end)

on("fact:cmd", function(c)
    clear_comps()
    if not c then filter() end
end)

on("launch", function(i)
    local a = shown[(i or 0) + 1]
    if not a then return end
    sys.call("apps.launch", a.exec)
    fact.open = false
end)

-- Run the typed text in the background; nothing it prints is kept.
on("run_cmd", function()
    local c = (text.query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if c == "" then return end
    run("setsid", { "-f", "sh", "-c", c .. " </dev/null >/dev/null 2>&1" }, nil, { output = false })
    fact.open = false
end)

local function common_prefix(list)
    local p = list[1] or ""
    for i = 2, #list do
        local s = list[i]
        local n = 0
        while n < #p and n < #s and p:sub(n + 1, n + 1) == s:sub(n + 1, n + 1) do n = n + 1 end
        p = p:sub(1, n)
        if p == "" then break end
    end
    return p
end

local function apply(base, names)
    if #names == 0 then clear_comps(); return end
    if #names == 1 then set_query(base .. names[1]); clear_comps(); return end
    set_query(base .. common_prefix(names))
    comp_base = base
    comps = names
    local rows = {}
    for i, n in ipairs(names) do
        if i > 60 then break end
        rows[i] = { name = n }
    end
    model.comps = rows
    fact.comp_sel = -1
end

on("complete", function()
    -- a menu is open: Tab cycles through it
    if #comps > 1 then
        local k = (fact.comp_sel + 1) % math.min(#comps, 60)
        fact.comp_sel = k
        set_query(comp_base .. comps[k + 1])
        return
    end
    local q = text.query or ""
    local token = q:match("(%S*)$") or ""
    local base = q:sub(1, #q - #token)
    if base:match("^%s*$") then
        -- the first word: a command name
        run("bash", { "-c", 'compgen -c -- "$1" 2>/dev/null | sort -u | head -300', "x", token }, function(out)
            local names = {}
            for line in (out or ""):gmatch("[^\n]+") do table.insert(names, line) end
            apply(base, names)
        end)
    else
        -- later words: a path (~ is home)
        local expanded = token:gsub("^~", HOME)
        local slash = token:match("^(.*/)") or ""
        local script = 'compgen -f -- "$1" 2>/dev/null | sort | head -300 | while IFS= read -r f; do if [ -d "$f" ]; then echo "$f/"; else echo "$f"; fi; done'
        run("bash", { "-c", script, "x", expanded }, function(out)
            local names = {}
            for line in (out or ""):gmatch("[^\n]+") do
                -- just the last part (and its slash, if it is a folder)
                table.insert(names, line:match("([^/]*/?)$") or line)
            end
            apply(base .. slash, names)
        end)
    end
end)

on("pick_comp", function(i)
    local n = comps[i + 1]
    if n then set_query(comp_base .. n); clear_comps() end
end)
