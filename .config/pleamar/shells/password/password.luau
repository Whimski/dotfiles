-- password: the answer's way through, from the field to polkit's helper and
-- nowhere else. It is not kept, not logged, and the field is emptied as it goes.

local function clear()
    text.answer = ""
    fact.typed = false
end

on("text:answer", function(v) fact.typed = (v or "") ~= "" end)

on("send", function()
    if not fact["auth.asking"] then return end
    sys.call("polkit.answer", text.answer)
    clear()
end)

on("dismiss", function()
    sys.call("polkit.cancel")
    clear()
end)

-- Show it on the monitor in use: look when a question arrives (and once now).
local function find_monitor()
    run("hyprctl", { "monitors", "-j" }, function(out, code)
        if code ~= 0 or not out then return end
        local ok, list = pcall(json.decode, out)
        if ok and type(list) == "table" then
            for _, m in ipairs(list) do if m.focused then text.here = m.name end end
        end
    end)
end
find_monitor()

local was_pending = false
sys.watch("polkit", function(p)
    local pending = p and p.pending == true
    if pending and not was_pending then find_monitor() end
    if not pending and was_pending then clear() end
    was_pending = pending
end)
