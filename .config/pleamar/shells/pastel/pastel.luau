-- pastel: the wheel over the pill nudges the volume, 5 % a notch (like pastel-bar).
-- The volume goes up to 200 %: the audio service stops at 100 %, so past it
-- pactl sets it (it is in the scene's run permissions).
local snd = {}          -- the audio service's last report
local VOL_MAX = 2
local function set_volume(v)
    v = math.max(0, math.min(VOL_MAX, v))
    v = math.floor(v * 100 + 0.5) / 100
    if v <= 1 then
        sys.call("audio.volume", v)
    else
        run("pactl", { "set-sink-volume", "@DEFAULT_SINK@", tostring(math.floor(v * 100 + 0.5)) .. "%" }, function() end)
    end
end
on("nudge", function(notches)
    if notches == nil or notches == 0 then return end
    set_volume((snd.volume or 0) + (notches > 0 and 0.05 or -0.05))
end)

-- Notifications: pleamar is the notification server. They are kept until
-- someone opens or dismisses them (like pastel-bar's history).

local notes = {}        -- newest first, as the service gives them
local newest = nil      -- id of the newest one seen

local function invoke(n)
    if not n then return end
    local key = "default"
    local acts = n.actions or {}
    local has_default = false
    for _, a in ipairs(acts) do if a.key == "default" then has_default = true end end
    if not has_default and acts[1] then key = acts[1].key end
    sys.call("notifications.invoke", n.id, key)
    sys.call("notifications.dismiss", n.id)
end

sys.watch("notifications", function(list)
    notes = list or {}
    local rows = {}
    for i = 1, math.min(20, #notes) do
        rows[i] = { title = notes[i].title ~= "" and notes[i].title or (notes[i].app or "Notification"),
                    body = notes[i].body or "", app = notes[i].app or "" }
    end
    model.notes = rows
    local top = notes[1]
    if top and top.id ~= newest then
        newest = top.id
        text.t_title = rows[1].title
        text.t_body = rows[1].body
        if not fact.dnd then
            fact.toast = true
            fact.toast_n = fact.toast_n + 1
        end
    elseif not top then
        newest = nil
        fact.toast = false
    end
end)

-- (after sys.watch: the service only runs once something watches it)
sys.call("notifications.keep", true)

on("note_open", function(i)
    invoke(notes[(i < 0) and 1 or (i + 1)])
end)
on("note_close", function(i)
    local n = notes[i + 1]
    if n then sys.call("notifications.dismiss", n.id) end
end)
on("clear_notes", function() sys.call("notifications.clear") end)


-- ---------------- the control center (Super+C) ----------------
local function focused_monitor(f)
    run("hyprctl", { "monitors", "-j" }, function(out, code)
        if code == 0 and out then
            local ok, list = pcall(json.decode, out)
            if ok and type(list) == "table" then
                for _, m in ipairs(list) do if m.focused then text.cc_here = m.name end end
            end
        end
        if f then f() end
    end)
end

on("cc_toggle", function()
    if fact.cc_open then fact.cc_open = false
    else focused_monitor(function() fact.cc_open = true end) end
end)

-- the tiles' second lines
local net = {}
sys.watch("network", function(n)
    net = n or {}
    if not net.wifi then text.wifi_sub = "Off"
    elseif net.kind == "wifi" and net.name and net.name ~= "" then text.wifi_sub = net.name
    else text.wifi_sub = "On" end
end)
on("wifi_flip", function() sys.call("network.wifi", not net.wifi) end)

local bt = {}
sys.watch("bluetooth", function(b)
    bt = b or {}
    fact.bt_on = bt.powered == true
    local n = 0
    for _, d in ipairs(bt.devices or {}) do if d.connected then n = n + 1 end end
    fact.bt_n = n
    if not bt.powered then text.bt_sub = "Off"
    elseif n > 0 then text.bt_sub = n .. " connected"
    else text.bt_sub = "On" end
end)
on("bt_flip", function() sys.call("bluetooth.power", not bt.powered) end)

sys.watch("audio", function(a)
    snd = a or {}
    local name = ""
    for _, d in ipairs(snd.outputs or {}) do if d.default then name = d.name or "" end end
    text.out_name = snd.muted and "Muted" or name
end)
on("mute_flip", function() sys.call("audio.mute", not snd.muted) end)
on("set_vol", function(v) set_volume(v) end)
on("set_lit", function(v) sys.call("brightness.level", v) end)

on("fact:dnd", function(d) text.dnd_sub = d and "On" or "Off" end)

-- right-click a tile / the gear: the settings window (on that page)
on("open_settings", function(p)
    if p == -2 then return end
    fact.cc_open = false
    if p < 0 then sys.call("say", "settings", "emit toggle")
    else sys.call("say", "settings", "emit open_page " .. p) end
end)

-- music: only music players — a browser (a video, a tab) is left out
local BROWSERS = { "firefox", "chromium", "chrome", "brave", "zen", "vivaldi",
                   "edge", "opera", "librewolf", "floorp", "plasma-browser" }
local function is_browser(s)
    s = string.lower(s or "")
    for _, b in ipairs(BROWSERS) do
        if string.find(s, b, 1, true) then return true end
    end
    return false
end

-- the cover: downloaded when it is a web link, and its two main colours read
local art_for = nil
local function cover(url)
    if url == art_for then return end
    art_for = url
    local function colours(path)
        text.m_art = path
        run("magick", { path, "-resize", "1x2!", "-modulate", "115,190",
                        "-format", "%[hex:p{0,0}] %[hex:p{0,1}]", "info:" }, function(out, code)
            if code ~= 0 or not out then return end
            local k = 0
            for hexc in out:gmatch("(%x%x%x%x%x%x)") do
                if k > 1 then break end
                fact["art_r." .. k] = tonumber(hexc:sub(1, 2), 16) / 255
                fact["art_g." .. k] = tonumber(hexc:sub(3, 4), 16) / 255
                fact["art_b." .. k] = tonumber(hexc:sub(5, 6), 16) / 255
                k = k + 1
            end
        end)
    end
    if url == nil or url == "" then text.m_art = ""; return end
    if url:match("^https?://") then
        local file = "/tmp/pleamar-art/" .. (url:match("([%w_%-]+)[^/]*$") or "cover") .. ".jpg"
        run("curl", { "-sL", "--create-dirs", "-o", file, url }, function(_, code)
            if code == 0 and art_for == url then colours(file) end
        end)
    else
        colours((url:gsub("^file://", "")))
    end
end

local song = {}
local pinned = nil
sys.watch("media", function(m)
    song = m or {}
    -- what is reported is a browser: pin a music player instead, if there is one
    if song.player ~= "" and is_browser(song.player) then
        local pick = nil
        for _, p in ipairs(song.players or {}) do
            if not is_browser(p.id) and not is_browser(p.name) then
                if pick == nil or (p.playing and not pick.playing) then pick = p end
            end
        end
        if pick and pick.id ~= pinned then
            pinned = pick.id
            sys.call("media.choose", pick.id)
            return
        end
    end
    local music = (song.player or "") ~= "" and not is_browser(song.player)
    fact.has_media = music
    fact.m_playing = music and song.playing == true
    fact.m_len = music and (tonumber(song.length) or 0) or 0
    fact.m_seek = music and song.can_seek == true
    local title = music and (song.title or "") or ""
    local who = music and (song.artist or "") or ""
    if title ~= text.m_title or who ~= text.m_artist then fact.song_n = fact.song_n + 1 end  -- a new song: the scene slides it in
    text.m_title = title
    text.m_artist = who
    fact.elapsed = music and (tonumber(song.position) or 0) or 0
    cover(music and song.art or "")
end)
every(1000, function()
    if song.playing and fact.cc_open then
        local len = tonumber(song.length) or 0
        local e = fact.elapsed + (tonumber(song.rate) or 1)
        if len > 0 and e > len then e = len end
        fact.elapsed = e
    end
end)
-- play/pause, next, previous: only ever a music player, never a browser
-- (the media keys come here too: `pleamar --say pastel "emit media_play"`)
local function music_call(what)
    if fact.has_media then sys.call(what) end
end
on("media_prev", function() music_call("media.previous") end)
on("media_play", function() music_call("media.toggle") end)
on("media_next", function() music_call("media.next") end)
on("seek_to", function(f)
    local len = tonumber(song.length) or 0
    if len > 0 and song.can_seek then
        sys.call("media.seek", f * len)
        fact.elapsed = f * len
    end
end)

-- ---------------- what is being shared: mic, sound, screen, camera ----------------
-- Shown as chips in the Alt pill. Looked for every second while the pill is
-- open, and every five seconds otherwise, so it is ready when Alt is held.
--   mic / sound: apps recording a source (pactl source-outputs); a ".monitor"
--                source is the computer's own sound, anything else a microphone
--   screen:      the screen-share portal's video node, running, and who reads it
--   camera:      a camera's video node, running, or an app holding /dev/video*
local QUIET = { easyeffects = true, pleamar = true, pipewire = true, wireplumber = true,
                pavucontrol = true, ["pipewire-pulse"] = true, parec = true,
                ["pleamar-miclevel"] = true, python3 = true }
local MICLEVEL = "/home/tobi/.config/pleamar/shells/pastel/miclevel.py"
local SPEAKING = 0.03     -- a mic counts as in use only above this (0..1)

local function pretty(name)
    name = name or "?"
    return (name:gsub("^%l", string.upper))
end

-- every app seen using one since the pill started, newest first, for
-- Settings → Privacy (where some can be ignored)
local recent = {}
local function remember(name)
    for _, n in ipairs(recent) do
        if n == name then return end      -- already known: nothing new to say
    end
    table.insert(recent, 1, name)
    while #recent > 12 do table.remove(recent) end
    pcall(sys.call, "say", "settings", "text seen_apps " .. table.concat(recent, "|"))
end

local function scan_shares()
    local found, seen, left = {}, {}, 3
    local ignore = {}
    for n in (text.share_ignore or ""):gmatch("[^|]+") do ignore[string.lower(n)] = true end
    local function add(kind, app)
        local name = pretty(app)
        remember(name)
        if ignore[string.lower(name)] then return end
        local key = kind .. ":" .. string.lower(name)
        if seen[key] then return end
        seen[key] = true
        table.insert(found, { kind = kind, app = name })
    end
    local function done()
        left = left - 1
        if left > 0 then return end
        local order = { screen = 1, camera = 2, mic = 3, sound = 4 }
        table.sort(found, function(a, b) return order[a.kind] < order[b.kind] end)
        local rows = {}
        for i = 1, math.min(6, #found) do rows[i] = found[i] end
        model.shares = rows
    end

    -- audio being recorded: the computer's sound (a ".monitor" source) counts
    -- as soon as an app records it; a microphone only while sound comes in
    run("pactl", { "-f", "json", "list", "sources" }, function(sout, scode)
        local monitor, names = {}, {}
        if scode == 0 and sout then
            local ok, srcs = pcall(json.decode, sout)
            if ok and type(srcs) == "table" then
                for _, src in ipairs(srcs) do
                    names[src.index] = src.name
                    monitor[src.index] = (src.name or ""):match("%.monitor$") ~= nil
                end
            end
        end
        run("pactl", { "-f", "json", "list", "source-outputs" }, function(out, code)
            local mics = {}          -- source index → the apps recording it
            if code == 0 and out then
                local ok, list = pcall(json.decode, out)
                if ok and type(list) == "table" then
                    for _, so in ipairs(list) do
                        local p = so.properties or {}
                        local bin = string.lower(p["application.process.binary"] or "")
                        local app = p["application.name"] or bin
                        local media = p["media.name"] or ""
                        if not QUIET[bin] and not QUIET[string.lower(app)]
                           and not media:find("[Pp]eak detect") and not so.corked and not so.mute then
                            if monitor[so.source] then add("sound", app)
                            elseif names[so.source] then
                                mics[so.source] = mics[so.source] or {}
                                table.insert(mics[so.source], app)
                            end
                        end
                    end
                end
            end
            -- listen to each microphone in use for a moment
            local pending = 0
            for _ in pairs(mics) do pending = pending + 1 end
            if pending == 0 then done(); return end
            for src, apps in pairs(mics) do
                run("python3", { MICLEVEL, names[src] }, function(level)
                    if (tonumber(level) or 0) > SPEAKING then
                        for _, a in ipairs(apps) do add("mic", a) end
                    end
                    pending = pending - 1
                    if pending == 0 then done() end
                end)
            end
        end)
    end)

    -- screen share and cameras, from PipeWire's graph
    run("pw-dump", {}, function(out, code)
        if code == 0 and out then
            local ok, objs = pcall(json.decode, out)
            if ok and type(objs) == "table" then
                local nodes, links = {}, {}
                for _, o in ipairs(objs) do
                    if o.type == "PipeWire:Interface:Node" then nodes[o.id] = o
                    elseif o.type == "PipeWire:Interface:Link" then table.insert(links, o) end
                end
                local function readers(id)
                    local apps = {}
                    for _, l in ipairs(links) do
                        local i = l.info or {}
                        if i["output-node-id"] == id then
                            local n = nodes[i["input-node-id"]]
                            local p = n and n.info and n.info.props or {}
                            table.insert(apps, p["application.name"] or p["node.name"] or "an app")
                        end
                    end
                    return apps
                end
                for id, n in pairs(nodes) do
                    local info = n.info or {}
                    local p = info.props or {}
                    local name = p["node.name"] or ""
                    if info.state == "running" and p["media.class"] == "Video/Source" then
                        local kind = name:find("xdg%-desktop%-portal") and "screen"
                                  or (name:find("^v4l2") or p["device.api"] == "v4l2" or p["api.v4l2.path"]) and "camera"
                        if kind then
                            local apps = readers(id)
                            if #apps == 0 then add(kind, kind == "screen" and "Sharing screen" or "Camera on") end
                            for _, a in ipairs(apps) do add(kind, a) end
                        end
                    end
                end
            end
        end
        done()
    end)

    -- apps that open the camera directly
    run("fuser", { "/dev/video0", "/dev/video1", "/dev/video2", "/dev/video3" }, function(out)
        local pids = {}
        for pid in (out or ""):gmatch("(%d+)") do table.insert(pids, pid) end
        if #pids == 0 then done(); return end
        run("ps", { "-o", "comm=", "-p", table.concat(pids, ",") }, function(names)
            for n in (names or ""):gmatch("[^\n]+") do
                if not QUIET[string.lower(n)] then add("camera", n) end
            end
            done()
        end)
    end, { errors = false })
end

local tick = 0
every(1000, function()
    tick = tick + 1
    if fact.expanded or tick % 5 == 0 then scan_shares() end
end)
scan_shares()
-- ask Settings for the ignore list (it also sends it whenever it changes)
pcall(sys.call, "say", "settings", "emit share_sync")

-- ---------------- the music's bass and beat (beat.py) ----------------
-- Runs only while the control center is open and music plays; stopped
-- otherwise, so it costs nothing the rest of the time.
local BEAT = "/home/tobi/.config/pleamar/shells/pastel/beat.py"
local beat_id = nil

local function stop_beat()
    if beat_id then kill(beat_id); beat_id = nil end
    fact.bass = 0; fact.mid = 0; fact.high = 0
end

every(500, function()
    local want = fact.cc_open and fact.m_playing
    if want and not beat_id then
        beat_id = spawn("python3", { BEAT }, function(line)
            local b, m, h, hit = line:match("^(%S+) (%S+) (%S+) (%d)")
            if not b then return end
            fact.bass = tonumber(b) or 0
            fact.mid = tonumber(m) or 0
            fact.high = tonumber(h) or 0
            if hit == "1" then emit("beat_hit") end
        end, function() beat_id = nil end)
    elseif not want and beat_id then
        stop_beat()
    end
end)
