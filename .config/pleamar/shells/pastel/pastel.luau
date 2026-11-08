-- pastel: the wheel over the pill nudges the volume, 5 % a notch (like pastel-bar).
on("nudge", function(notches)
    if notches == nil or notches == 0 then return end
    sys.call("audio.step", notches > 0 and 0.05 or -0.05)
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

local snd = {}
sys.watch("audio", function(a)
    snd = a or {}
    local name = ""
    for _, d in ipairs(snd.outputs or {}) do if d.default then name = d.name or "" end end
    text.out_name = snd.muted and "Muted" or name
end)
on("mute_flip", function() sys.call("audio.mute", not snd.muted) end)
on("set_vol", function(v) sys.call("audio.volume", v) end)
on("set_lit", function(v) sys.call("brightness.level", v) end)

on("fact:dnd", function(d) text.dnd_sub = d and "On" or "Off" end)

-- right-click a tile / the gear: the settings window (on that page)
on("open_settings", function(p)
    if p == -2 then return end
    fact.cc_open = false
    if p < 0 then sys.call("say", "settings", "emit toggle")
    else sys.call("say", "settings", "emit open_page " .. p) end
end)

-- music: the position is carried on here, once a second, while it plays
local song = {}
sys.watch("media", function(m)
    song = m or {}
    fact.has_media = (song.player or "") ~= ""
    fact.elapsed = tonumber(song.position) or 0
end)
every(1000, function()
    if song.playing and fact.cc_open then
        local len = tonumber(song.length) or 0
        local e = fact.elapsed + (tonumber(song.rate) or 1)
        if len > 0 and e > len then e = len end
        fact.elapsed = e
    end
end)
on("media_prev", function() sys.call("media.previous") end)
on("media_play", function() sys.call("media.toggle") end)
on("media_next", function() sys.call("media.next") end)
on("seek_to", function(f)
    local len = tonumber(song.length) or 0
    if len > 0 and song.can_seek then
        sys.call("media.seek", f * len)
        fact.elapsed = f * len
    end
end)
