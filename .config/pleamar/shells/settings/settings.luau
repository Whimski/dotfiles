-- settings: monitors from hyprctl, wallpapers saved in settings.json,
-- and the folder browser behind the picture picker.

local FILE = "settings.json"
local SLOTS = 4
local MAX_ENTRIES = 160
local PICTURES = { png = true, jpg = true, jpeg = true, webp = true, bmp = true, gif = true }

-- First run: start from what pastel-bar had chosen.
local DEFAULTS = {
    ["DP-1"] = "/home/tobi/Pictures/blue.jpg",
    ["DP-2"] = "/home/tobi/Pictures/unix.jpg",
    ["HDMI-A-2"] = "/home/tobi/.wallpaper/cat.png",
}

local settings = sys.ask("files.read", FILE, "json")
if type(settings) ~= "table" then
    settings = { wallpapers = DEFAULTS }
    sys.call("files.write", FILE, settings)
end
settings.wallpapers = settings.wallpapers or {}

local monitors = {}   -- slot (0-based) → monitor name

local function basename(p)
    return (p:match("([^/]+)$")) or p
end

local function show()
    for k = 0, SLOTS - 1 do
        local name = monitors[k]
        local path = name and settings.wallpapers[name] or ""
        fact["has." .. k] = name ~= nil
        fact["set." .. k] = path ~= ""
        text["mon." .. k] = name or ""
        text["path." .. k] = path
        text["file." .. k] = path ~= "" and basename(path) or ""
    end
end

local function save()
    sys.call("files.write", FILE, settings)
end

local function read_monitors(then_do)
    run("hyprctl", { "monitors", "-j" }, function(out, code)
        if code ~= 0 or not out then return end
        local ok, list = pcall(json.decode, out)
        if not ok or type(list) ~= "table" then return end
        table.sort(list, function(a, b) return (a.x or 0) < (b.x or 0) end)   -- left to right
        monitors = {}
        for _, m in ipairs(list) do
            if m.focused then text.here = m.name end
        end
        for i, m in ipairs(list) do
            if i > SLOTS then break end
            monitors[i - 1] = m.name
        end
        show()
        if then_do then then_do() end
    end)
end

show()
read_monitors()
every(10000, function() read_monitors() end)    -- a monitor plugged in or out

-- Open on a given page (the control center's right-click on a tile).
local PAGES = { [0] = "wallpaper", "wifi", "audio", "bluetooth", "privacy" }
on("open_page", function(p)
    fact.page = PAGES[p] or "wallpaper"
    if not fact.open then read_monitors(function() fact.open = true end) end
end)

-- Open on the monitor in use; close wherever it is.
on("toggle", function()
    if fact.open then
        fact.open = false
        fact.picking = false
    else
        read_monitors(function() fact.open = true end)
    end
end)

-- If settings.json is edited by hand, take it.
sys.watch("files:" .. FILE, function()
    local now = sys.ask("files.read", FILE, "json")
    if type(now) == "table" then
        settings = now
        settings.wallpapers = settings.wallpapers or {}
        show()
    end
end)

-- ---------------- the picker ----------------
local home = "/home/tobi"
local here = home .. "/Pictures"
local listing = {}    -- what each entry is: { name, dir, path }

local function browse(dir)
    run("find", { dir, "-mindepth", "1", "-maxdepth", "1", "-not", "-name", ".*",
                  "(", "-type", "d", "-o", "-type", "f", "-o", "-type", "l", ")", "-printf", "%Y\t%f\n" },
        function(out, code)
            if code ~= 0 then return end
            here = dir
            text.folder = dir
            local dirs, pics = {}, {}
            for line in (out or ""):gmatch("[^\n]+") do
                local kind, name = line:match("^(%a)\t(.+)$")
                if kind == "d" then
                    table.insert(dirs, name)
                elseif kind == "f" then
                    local ext = (name:match("%.(%w+)$") or ""):lower()
                    if PICTURES[ext] then table.insert(pics, name) end
                end
            end
            local byname = function(a, b) return a:lower() < b:lower() end
            table.sort(dirs, byname)
            table.sort(pics, byname)
            listing = {}
            local rows = {}
            for _, n in ipairs(dirs) do
                table.insert(listing, { name = n, dir = true, path = dir .. "/" .. n })
            end
            for _, n in ipairs(pics) do
                table.insert(listing, { name = n, dir = false, path = dir .. "/" .. n })
            end
            for i, e in ipairs(listing) do
                if i > MAX_ENTRIES then break end
                rows[i] = { name = e.name, dir = e.dir, pic = e.dir and "" or e.path }
            end
            model.entries = rows
        end)
end

local function parent_of(dir)
    local up = dir:match("^(.*)/[^/]+$")
    if up == nil or up == "" then return "/" end
    return up
end

on("choose", function(k)
    fact.target = k
    local current = text["path." .. k]
    browse(current ~= "" and parent_of(current) or here)
    fact.picking = true
end)

on("clear", function(k)
    local name = monitors[k]
    if not name then return end
    settings.wallpapers[name] = nil
    save()
    show()
end)

on("enter_entry", function(i)
    local e = listing[i + 1]
    if not e then return end
    if e.dir then
        browse(e.path)
        return
    end
    local name = monitors[fact.target]
    if not name then return end
    settings.wallpapers[name] = e.path
    save()
    show()
    fact.picking = false
end)

on("go_up", function() browse(parent_of(here)) end)
on("go_home", function() browse(home) end)

-- ---------------- Wi-Fi ----------------
local net = {}          -- the last network report
local shown_nets = {}   -- what each row is
local want = nil        -- the network being joined, until it turns active

local function nm(args, f)
    run("nmcli", args, function(out, code) if code == 0 and f then f(out or "") end end)
end

local function details()
    if not net.wifi or net.kind ~= "wifi" then return end
    nm({ "-t", "-f", "DEVICE,TYPE,STATE", "dev" }, function(out)
        for line in out:gmatch("[^\n]+") do
            local d, t, st = line:match("^([^:]+):([^:]+):(.+)$")
            if t == "wifi" and st == "connected" then
                text.net_dev = d
                nm({ "-g", "IP4.ADDRESS", "dev", "show", d }, function(ip)
                    text.net_ip = (ip:match("^([^/\n]+)") or "—")
                end)
            end
        end
    end)
    nm({ "-t", "-f", "IN-USE,FREQ,SECURITY", "dev", "wifi", "list", "--rescan", "no" }, function(out)
        for line in out:gmatch("[^\n]+") do
            local freq, sec = line:match("^%*:([^:]*):(.*)$")
            if freq then
                text.net_freq = freq
                text.net_sec = sec ~= "" and sec or "Open"
            end
        end
    end)
    if net.name and net.name ~= "" then
        nm({ "-g", "connection.autoconnect", "con", "show", net.name }, function(out)
            fact.autoconn = out:match("yes") ~= nil
        end)
    end
end

-- the service reports signal as 0..1 here; show it as a whole percent
local function pct(v)
    v = tonumber(v) or 0
    if v <= 1 then v = v * 100 end
    return math.floor(v + 0.5)
end

local function show_net()
    fact.wifi_on = net.wifi == true
    local on_wifi = net.kind == "wifi" and net.online == true
    fact.connected = on_wifi
    fact.strength = pct(net.strength)
    if want and on_wifi and net.name == want then want = nil end
    fact.connecting = want ~= nil
    if not net.wifi then
        text.net_name = "Wi-Fi"
        text.net_status = "Turned off"
    elseif want then
        text.net_name = want
        text.net_status = "Connecting…"
    elseif on_wifi then
        text.net_name = net.name or "Wi-Fi"
        text.net_status = "Connected · " .. pct(net.strength) .. "%"
    else
        text.net_name = "Not connected"
        text.net_status = "Pick a network below"
    end
    -- the connected one first, hidden networks left out
    local rows = {}
    shown_nets = {}
    local list = net.wifi and (net.networks or {}) or {}
    for _, n in ipairs(list) do
        if n.active and n.ssid ~= "" then table.insert(shown_nets, n) end
    end
    for _, n in ipairs(list) do
        if not n.active and n.ssid and n.ssid ~= "" then table.insert(shown_nets, n) end
    end
    for i, n in ipairs(shown_nets) do
        if i > 30 then break end
        rows[i] = { ssid = n.ssid, strength = pct(n.strength), secure = n.secure == true,
                    known = n.known == true, active = n.active == true }
    end
    model.nets = rows
end

sys.watch("network", function(n)
    net = n or {}
    show_net()
    details()
end)

-- look again now and then while the page is open
every(8000, function()
    if fact.open and fact.page == "wifi" and net.wifi then
        fact.scanning = true
        sys.call("network.scan")
        after(3000, function() fact.scanning = false end)
        details()
    end
end)
on("fact:page", function(p)
    if p == "wifi" and net.wifi then sys.call("network.scan"); details() end
end)

on("wifi_flip", function() sys.call("network.wifi", not net.wifi) end)

on("scan", function()
    fact.scanning = true
    sys.call("network.scan")
    after(3000, function() fact.scanning = false end)
end)

local function join(ssid, password)
    want = ssid
    show_net()
    if password then sys.call("network.connect", ssid, password)
    else sys.call("network.connect", ssid) end
    -- give up waiting after 20 s
    after(20000, function()
        if want == ssid then
            want = nil
            show_net()
            text.net_status = "Could not join " .. ssid
        end
    end)
end

on("join", function(i)
    local n = shown_nets[i + 1]
    if not n or n.active then return end
    if n.secure and not n.known then
        text.ask_ssid = n.ssid
        text.pw = ""
        fact.asking = true
    else
        join(n.ssid)
    end
end)

local function send_password()
    if not fact.asking then return end
    local pw = text.pw
    fact.asking = false
    text.pw = ""
    join(text.ask_ssid, pw)
end
on("pw_ok", send_password)
on("submit:pw", send_password)
on("pw_cancel", function() fact.asking = false; text.pw = "" end)

on("leave_net", function() sys.call("network.disconnect") end)

on("autoconn_flip", function()
    if not net.name or net.name == "" then return end
    local v = fact.autoconn and "no" or "yes"
    nm({ "con", "modify", net.name, "connection.autoconnect", v }, function() fact.autoconn = (v == "yes") end)
end)

-- ---------------- Audio ----------------
local snd = {}
local dev_list = {}     -- what each device row is
local app_list = {}     -- what each app row is
local routes = {}       -- app (sink-input) id → the output (sink) id it plays on
local show_audio        -- (below)

local function read_routes()
    run("pactl", { "-f", "json", "list", "sink-inputs" }, function(out, code)
        if code ~= 0 or not out then return end
        local ok, list = pcall(json.decode, out)
        if not ok or type(list) ~= "table" then return end
        routes = {}
        for _, si in ipairs(list) do routes[si.index] = si.sink end
        if show_audio then show_audio() end
    end)
end

show_audio = function()
    fact.out_vol = tonumber(snd.volume) or 0
    fact.out_muted = snd.muted == true
    fact.in_vol = tonumber(snd.input) or 0
    fact.in_muted = snd.input_muted == true
    local function default_name(list)
        for _, d in ipairs(list or {}) do if d.default then return d.name or "" end end
        return ""
    end
    text.out_name = default_name(snd.outputs)
    text.in_name = default_name(snd.inputs)
    if text.out_name == "" then text.out_name = "No output" end
    if text.in_name == "" then text.in_name = "No input" end

    dev_list = (fact.atab == "ins") and (snd.inputs or {}) or (snd.outputs or {})
    local rows = {}
    for i, d in ipairs(dev_list) do
        if i > 16 then break end
        rows[i] = { name = d.name or "?", default = d.default == true }
    end
    model.devs = rows

    app_list = snd.apps or {}
    local arows = {}
    for i, a in ipairs(app_list) do
        if i > 16 then break end
        local out_name = "Default output"
        for _, d in ipairs(snd.outputs or {}) do
            if d.id == routes[a.id] then out_name = d.name or out_name end
        end
        arows[i] = { name = a.name or a.binary or "App", title = a.title or "",
                     icon = a.icon or "application-x-executable-symbolic",
                     volume = tonumber(a.volume) or 0, muted = a.muted == true,
                     out = out_name }
    end
    model.apps = arows
end

local seen_apps = ""
sys.watch("audio", function(a)
    snd = a or {}
    -- a new app or one gone: ask again where each plays
    local ids = {}
    for _, x in ipairs(snd.apps or {}) do table.insert(ids, tostring(x.id)) end
    local key = table.concat(ids, ",")
    if key ~= seen_apps then seen_apps = key; read_routes() end
    show_audio()
end)
-- and now and then while the Apps tab is open (another program may move one)
every(3000, function()
    if fact.open and fact.page == "audio" and fact.atab == "apps" then read_routes() end
end)

-- an app's output menu
local menu_sinks = {}
on("out_menu", function(i)
    if fact.menu_app == i then fact.menu_app = -1; return end
    local a = app_list[i + 1]
    if not a then return end
    menu_sinks = snd.outputs or {}
    local rows = {}
    for k, d in ipairs(menu_sinks) do
        if k > 8 then break end
        rows[k] = { name = d.name or "?", here = d.id == routes[a.id] }
    end
    model.sinks = rows
    fact.menu_app = i
end)
on("pick_sink", function(k)
    local a = app_list[fact.menu_app + 1]
    local d = menu_sinks[k + 1]
    fact.menu_app = -1
    if not a or not d then return end
    run("pactl", { "move-sink-input", tostring(a.id), tostring(d.id) }, function()
        read_routes()
        -- and again a moment later: another program (Easy Effects, when it
        -- processes every app) may take it straight back
        after(700, read_routes)
    end)
end)
on("fact:atab", function()
    fact.menu_app = -1
    show_audio()
end)

on("set_vol", function(v)
    if fact.atab == "ins" then sys.call("audio.input", v) else sys.call("audio.volume", v) end
end)
on("mute_flip", function()
    if fact.atab == "ins" then sys.call("audio.input_mute", not snd.input_muted)
    else sys.call("audio.mute", not snd.muted) end
end)
on("make_default", function(i)
    local d = dev_list[i + 1]
    if d and not d.default then sys.call("audio.default", d.id) end
end)
on("app_vol", function(v)
    local a = app_list[fact.app_sel + 1]
    if a then sys.call("audio.app_volume", a.id, v) end
end)
on("app_mute", function()
    local a = app_list[fact.app_sel + 1]
    if a then sys.call("audio.app_mute", a.id, not a.muted) end
end)

-- ---------------- Bluetooth ----------------
local bt = {}
local bt_list = {}      -- what each row is
local bt_busy = {}      -- address → true while connecting / leaving

local function show_bt()
    fact.bt_present = bt.present == true
    fact.bt_on = bt.powered == true
    fact.bt_scan = bt.discovering == true
    local n = 0
    for _, d in ipairs(bt.devices or {}) do if d.connected then n = n + 1 end end
    if not bt.present then text.bt_status = "No adapter found"
    elseif not bt.powered then text.bt_status = "Turned off"
    elseif n > 0 then text.bt_status = "On · " .. n .. " connected"
    else text.bt_status = "On" end

    -- connected, then paired, then new ones (unnamed ones left out)
    bt_list = {}
    local list = bt.powered and (bt.devices or {}) or {}
    for pass = 1, 3 do
        for _, d in ipairs(list) do
            local group = d.connected and 1 or (d.paired and 2 or 3)
            if group == pass and d.name and d.name ~= "" then table.insert(bt_list, d) end
        end
    end
    local rows = {}
    for i, d in ipairs(bt_list) do
        if i > 30 then break end
        rows[i] = { name = d.name, paired = d.paired == true, connected = d.connected == true,
                    busy = bt_busy[d.address] == true,
                    battery = tonumber(d.battery) or -1,
                    icon = (d.icon and d.icon ~= "") and d.icon or "bluetooth" }
    end
    model.bdevs = rows

    -- a pairing question
    local kinds = { pin = "code", passkey = "code", confirm = "confirm", display = "display", authorize = "authorize" }
    local k = kinds[bt.pairing or "none"] or "none"
    if k ~= fact.pair_kind then
        fact.pair_kind = k
        if k == "code" then text.pair_in = "" end
    end
    text.pair_name = bt.pairing_name or bt.pairing_address or "the device"
    text.pair_code = tostring(bt.pairing_code or "")
end

sys.watch("bluetooth", function(b)
    bt = b or {}
    -- a device that finished connecting or leaving is no longer busy
    for _, d in ipairs(bt.devices or {}) do
        if bt_busy[d.address] == d.connected then bt_busy[d.address] = nil end
    end
    show_bt()
end)

on("bt_flip", function() sys.call("bluetooth.power", not bt.powered) end)
on("bt_scan_flip", function() sys.call("bluetooth.scan", not bt.discovering) end)
-- stop looking when the window closes
on("fact:open", function(o) if not o and bt.discovering then sys.call("bluetooth.scan", false) end end)

on("bt_tap", function(i)
    local d = bt_list[i + 1]
    if not d or bt_busy[d.address] ~= nil then return end
    -- remember what we wait for: true = until connected, false = until it leaves
    bt_busy[d.address] = not d.connected
    show_bt()
    if d.connected then sys.call("bluetooth.disconnect", d.address)
    else sys.call("bluetooth.connect", d.address) end
    after(25000, function()
        if bt_busy[d.address] ~= nil then bt_busy[d.address] = nil; show_bt() end
    end)
end)

on("bt_forget", function()
    local d = bt_list[fact.bt_sel + 1]
    if d then sys.call("bluetooth.forget", d.address) end
end)

on("pair_yes", function()
    local id = bt.pairing_id
    if id == nil then return end
    if fact.pair_kind == "code" then sys.call("bluetooth.answer", id, text.pair_in)
    else sys.call("bluetooth.confirm", id) end
end)
on("submit:pair_in", function()
    if bt.pairing_id ~= nil then sys.call("bluetooth.answer", bt.pairing_id, text.pair_in) end
end)
on("pair_no", function()
    if bt.pairing_id ~= nil then sys.call("bluetooth.cancel", bt.pairing_id) end
end)

-- ---------------- Style: Glass or Midnight ----------------
-- Every shell imports ~/.config/pleamar/theme.plm; choosing a style copies
-- themes/<style>.plm over it, and each shell reloads itself with the new look.
local PLEAMAR = "/home/tobi/.config/pleamar"
local STYLES = { [0] = "glass", "midnight" }

fact.style = (settings.style == "midnight") and "midnight" or "glass"

on("set_style", function(k)
    local name = STYLES[k]
    if not name or name == fact.style then return end
    run("cp", { PLEAMAR .. "/themes/" .. name .. ".plm", PLEAMAR .. "/theme.plm" }, function(_, code)
        if code ~= 0 then return end
        fact.style = name
        settings.style = name
        save()
    end)
end)


-- ---------------- Privacy: apps the pill's sharing rings ignore ----------------
-- The list lives in settings.json ("share_ignore") and is handed to the pill
-- (`text share_ignore A|B`), which in turn says which apps it has seen
-- (`text seen_apps A|B`).
-- (read through ign(): a reload of settings.json can leave the list out)
local function ign()
    if type(settings.share_ignore) ~= "table" then settings.share_ignore = {} end
    return settings.share_ignore
end

local function ignoring(name)
    local low = string.lower(name or "")
    for i, n in ipairs(ign()) do
        if string.lower(n) == low then return i end
    end
    return nil
end

local seen_list = {}
local function show_privacy()
    local rows = {}
    for i, n in ipairs(seen_list) do
        if i > 12 then break end
        rows[i] = { name = n, ignored = ignoring(n) ~= nil }
    end
    model.seen = rows
    local irows = {}
    for i, n in ipairs(ign()) do
        if i > 24 then break end
        irows[i] = { name = n }
    end
    model.ignored = irows
end

local function push_ignore()
    pcall(sys.call, "say", "pastel", "text share_ignore " .. table.concat(ign(), "|"))
end

local function changed()
    save()
    show_privacy()
    push_ignore()
end

on("ignore_flip", function(i)
    local n = seen_list[i + 1]
    if not n then return end
    local at = ignoring(n)
    if at then table.remove(ign(), at) else table.insert(ign(), n) end
    changed()
end)
on("unignore", function(i)
    if ign()[i + 1] then table.remove(ign(), i + 1); changed() end
end)
on("ignore_add", function()
    local n = (text.ignore_new or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if n ~= "" and not ignoring(n) then table.insert(ign(), n); changed() end
    text.ignore_new = ""
    fact.typing_ignore = false
end)
on("text:ignore_new", function(v) fact.typing_ignore = (v or "") ~= "" end)
on("share_sync", push_ignore)

-- what the pill has seen (it sets text.seen_apps)
local last_seen = nil
every(1000, function()
    local v = text.seen_apps or ""
    if v == last_seen then return end
    last_seen = v
    seen_list = {}
    for n in v:gmatch("[^|]+") do table.insert(seen_list, n) end
    show_privacy()
end)

show_privacy()
push_ignore()
