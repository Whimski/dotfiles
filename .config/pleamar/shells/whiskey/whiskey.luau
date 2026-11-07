--  Logic for whiskey.plm. It never draws: it decides where the cat goes
--  next, carries it across monitors, and talks to Claude Code for the chat.

pcall(function() math.randomseed(os.time()) end)

--  ── Wandering ───────────────────────────────────────────────────────────────
--  Every few seconds: walk somewhere near, sit still, or (now and then) nap.
--  Stopped, it sits (most often), washes, yawns or lies down: fact.mood 0, 1, 2, 3.
--  A yawn plays once and it sits again; it meows (4) when its bubble opens.
local SIT, WASH, YAWN, LIE, MEOW = 0, 1, 2, 3, 4
local gx, gy = fact.gx, fact.gy
local home = function() end            -- defined with the monitors, below
on("fact:gx", function(v) gx = v; home() end)   -- a click or a drag puts the cat somewhere
on("fact:gy", function(v) gy = v; home() end)

local once = nil
local function set_mood(m, for_ms)
    if once then cancel(once); once = nil end
    fact.tick = 0                         -- an animation starts from its first frame
    fact.mood = m
    if for_ms then
        once = after(for_ms, function() once = nil; fact.mood = SIT end)
    end
end

local function pick_mood()
    local r = math.random()
    if r < 0.4 then set_mood(SIT)
    elseif r < 0.65 then set_mood(WASH)
    elseif r < 0.8 then set_mood(YAWN, 1000)  -- 8 frames of 125 ms
    else set_mood(LIE) end
end

on("fact:menu", function(open)
    if open then set_mood(MEOW, 750) end
end)

--  ── The monitors ────────────────────────────────────────────────────────────
--  The cat walks on the whole desktop, in Hyprland's coordinates. Each copy of
--  the scene (one per monitor) is told where its monitor is, through `mon`.
local screens = {}       -- copy number → monitor name, as the renderer reports them
local rects = {}         -- monitor name → { x, y, w, h } on the desktop

local function publish()
    local records = {}
    for k = 0, 3 do
        local r = screens[k] and rects[screens[k]]
        records[k + 1] = r and { ox = r.x, oy = r.y, w = r.w, h = r.h } or { ox = -100000, oy = -100000, w = 0, h = 0 }
    end
    model.mon = records
end

for k = 0, 3 do
    on("text:screen." .. k .. ".name", function(name) screens[k] = name; publish() end)
end

--  Where it may stand on a monitor: its feet below its height, inside the edges.
local function area(r)
    return r.x + 50, r.x + r.w - 50, r.y + 110, r.y + r.h - 20
end

local function monitor_at(x, y)
    for name, r in pairs(rects) do
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then return name, r end
    end
end

--  Tell the scene which monitor the cat is heading to: the bubble uses it only
--  while the cat is over no monitor (the scene follows the cat's feet otherwise).
home = function()
    local _, r = monitor_at(gx, gy)
    if r then fact.gox, fact.goy, fact.gow, fact.goh = r.x, r.y, r.w, r.h end
end

local function read_monitors()
    run("hyprctl", { "monitors", "-j" }, function(out, code)
        if code ~= 0 then log("hyprctl monitors: exit " .. tostring(code)); return end
        local ok, list = pcall(json.decode, out)
        if not ok or type(list) ~= "table" then return end
        local found = {}
        for _, m in ipairs(list) do
            local w, h = m.width / m.scale, m.height / m.scale
            if m.transform % 2 == 1 then w, h = h, w end      -- turned a quarter
            found[m.name] = { x = m.x, y = m.y, w = w, h = h }
        end
        rects = found
        publish()
        home()
        local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
        for _, r in pairs(found) do
            x0, y0 = math.min(x0, r.x), math.min(y0, r.y)
            x1, y1 = math.max(x1, r.x + r.w), math.max(y1, r.y + r.h)
        end
        fact.bx0, fact.by0, fact.bx1, fact.by1 = x0, y0, x1, y1
        if not fact.ready then
            -- start in the middle of the focused monitor
            for _, m in ipairs(list) do
                if m.focused then
                    local r = found[m.name]
                    gx, gy = r.x + r.w / 2, r.y + r.h * 0.8
                    fact.gx, fact.gy = gx, gy
                end
            end
            fact.ready = true
        end
    end)
end
read_monitors()
every(30000, read_monitors)          -- a monitor plugged in, moved or turned

--  A monitor beside this one, sharing an edge and some height: { name, rect, top, bottom }.
local function neighbours(name)
    local a, out = rects[name], {}
    for other, b in pairs(rects) do
        if other ~= name and (a.x + a.w == b.x or b.x + b.w == a.x) then
            local _, _, at, ab = area(a)
            local _, _, bt, bb = area(b)
            local top, bottom = math.max(at, bt), math.min(ab, bb)
            if bottom - top > 40 then table.insert(out, { other, b, top, bottom }) end
        end
    end
    return out
end

local function walk_to(x, y)
    if x ~= gx then fact.facing = x > gx and 1 or 0 end
    fact.gx, fact.gy = x, y
    home()
end

--  Carried: the scene follows the drag while the mouse is on the monitor the
--  cat was picked up on, but past it that copy hears nothing more until the
--  release. So while it is held, ask Hyprland where the mouse is (~30 a second)
--  and carry the cat there, keeping where it was grabbed.
local carrying = nil
local grab = nil                     -- the cat less the mouse, when picked up
local function carry()
    run("hyprctl", { "cursorpos", "-j" }, function(out, code)
        if code ~= 0 or not fact.held then return end
        local ok, c = pcall(json.decode, out)
        if not ok or type(c) ~= "table" or not c.x then return end
        if not grab then
            grab = { fact.sx - c.x, fact.sy - c.y }
            return
        end
        local x = math.clamp(c.x + grab[1], fact.bx0 + 40, fact.bx1 - 40)
        local y = math.clamp(c.y + grab[2], fact.by0 + 110, fact.by1 - 20)
        if math.abs(x - fact.sx) + math.abs(y - fact.sy) > 6 then fact.dragged = true end
        fact.hold_x, fact.hold_y = x, y
    end)
end

--  Dropped where no monitor is (below a shorter one), or too near an edge:
--  it walks to the nearest place it may stand.
local function snap()
    local best, bx, by = math.huge, gx, gy
    for _, r in pairs(rects) do
        local x0, x1, y0, y1 = area(r)
        local x, y = math.clamp(gx, x0, x1), math.clamp(gy, y0, y1)
        local d = (x - gx) ^ 2 + (y - gy) ^ 2
        if d < best then best, bx, by = d, x, y end
    end
    if best > 0.25 then walk_to(bx, by) end
end

on("fact:held", function(held)
    if held then
        grab = nil
        carry()
        if not carrying then carrying = every(33, carry) end
    else
        if carrying then cancel(carrying); carrying = nil end
        after(60, snap)                  -- once the drop has set where it is
    end
end)

local function wander()
    local here, r = monitor_at(gx, gy)
    if here and not fact.menu and not fact.asleep and not fact.held and not fact.calling then
        local roll = math.random()
        local next_to = neighbours(here)
        if roll < 0.12 then
            fact.asleep = true
            after(math.random(20000, 45000), function() fact.asleep = false end)
        elseif roll < 0.32 and #next_to > 0 then
            -- over to the next monitor: first to a height both share, then across
            local n = next_to[math.random(#next_to)]
            local b = n[2]
            local y = math.random(math.floor(n[3]), math.floor(n[4]))
            local x = b.x > r.x and b.x + math.random(120, 420) or b.x + b.w - math.random(120, 420)
            walk_to(gx, y)
            after(3400, function()
                if fact.held or fact.menu then return end
                walk_to(x, y)
                after(3300, pick_mood)
            end)
        elseif roll < 0.8 then
            local x0, x1, y0, y1 = area(r)
            local dx = (math.random() * 2 - 1) * r.w * 0.3
            if math.abs(dx) < r.w * 0.08 then dx = dx < 0 and -r.w * 0.08 or r.w * 0.08 end
            walk_to(math.clamp(gx + dx, x0, x1), math.clamp(gy + (math.random() * 2 - 1) * r.h * 0.25, y0, y1))
            after(3300, pick_mood)               -- what it does once it gets there
        else
            pick_mood()
        end
    end
    after(math.random(4000, 10000), wander)
end
after(3000, wander)

--  ── Chat ────────────────────────────────────────────────────────────────────
--  Whiskey talks through Claude Code (`claude -p`), signed in as the user, so no
--  API key. Each conversation is one Claude Code session: the first message
--  starts it with --session-id, the rest --resume it, so `claude --resume <id>`
--  opens the same conversation in a terminal. The session and what was said are
--  kept in this scene's folder (chat.json) and come back after a restart.
--  No tools: the cat only talks, it runs nothing on the machine.
local CHAT_FILE = "chat.json"
local PERSONA = "You are Whiskey, a small pixel-art calico cat who lives on Tobi's desktop and "
    .. "chats with her in a little speech bubble beside you. You're named after her real cat "
    .. "Whiskey, her emotional support animal. Talk the way her notes below ask: warm, simple, "
    .. "a little playful like a cat, brief, one thing at a time; keep replies to one to three "
    .. "short sentences unless she asks for more. You cannot run tools or see the screen. "
    .. "If she shares how she is feeling on one of her thermometers, take it seriously and follow "
    .. "the plan in her notes (she finds texting easier than calling); you are not a crisis "
    .. "service and never pretend to be one."
--  Which Claude, and how hard it thinks.
local MODEL, EFFORT = "claude-opus-5-5", "medium"

--  Her own notes, read before every message so an edit to the file counts at once.
local PREFS_FILE = "preferences.md"
local function instructions()
    local prefs = sys.ask("files.read", PREFS_FILE)
    if type(prefs) == "string" and prefs ~= "" then
        return PERSONA .. "\n\nTobi's own notes about herself (" .. PREFS_FILE .. "):\n\n" .. prefs
    end
    return PERSONA
end

local chat = { session = nil, started = false, said = {} }

local function uuid()
    local t = {}
    for i = 1, 16 do t[i] = math.random(0, 255) end
    t[7] = bit32.bor(bit32.band(t[7], 0x0f), 0x40)   -- version 4
    t[9] = bit32.bor(bit32.band(t[9], 0x3f), 0x80)   -- variant
    local h = {}
    for i = 1, 16 do h[i] = string.format("%02x", t[i]) end
    return table.concat(h, "", 1, 4) .. "-" .. table.concat(h, "", 5, 6) .. "-"
        .. table.concat(h, "", 7, 8) .. "-" .. table.concat(h, "", 9, 10) .. "-" .. table.concat(h, "", 11, 16)
end

local function show_chat()
    local from = math.max(1, #chat.said - 63)          -- the scene keeps the last 64
    local list = {}
    for i = from, #chat.said do table.insert(list, chat.said[i]) end
    model.said = list
end

local function save_chat()
    sys.call("files.write", CHAT_FILE, chat)
end

local function new_chat()
    -- the conversation that ends is kept beside it, by its session
    if chat.session and #chat.said > 0 then
        sys.call("files.write", "chat-" .. chat.session .. ".json", chat)
    end
    chat = { session = uuid(), started = false, said = {} }
    show_chat()
    save_chat()
end

--  Read what was said last time. A file that is there but does not read (a
--  reload caught half-way) is tried again, never replaced by an empty chat.
local function load_chat(tries)
    local saved = sys.ask("files.read", CHAT_FILE, "json")
    if type(saved) == "table" and saved.session then
        chat = { session = saved.session, started = saved.started == true, said = saved.said or {} }
        show_chat()
    elseif not sys.ask("files.exists", CHAT_FILE) then
        chat = { session = uuid(), started = false, said = {} }
        show_chat()
        save_chat()
    elseif tries < 10 then
        after(500, function() load_chat(tries + 1) end)
    else
        log("chat.json is there but does not read; leaving it alone")
    end
end
load_chat(0)
do
    local prefs = sys.ask("files.read", PREFS_FILE)
    log(type(prefs) == "string" and ("preferences.md: " .. #prefs .. " characters, sent with each message")
        or "preferences.md: none (Whiskey goes on its personality alone)")
end

on("new_chat", function()
    if fact.thinking then return end
    new_chat()
end)

on("send", function()
    local msg = (text.draft or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" or fact.thinking then return end
    text.draft = ""
    table.insert(chat.said, { text = msg, mine = true })
    show_chat()
    save_chat()
    fact.thinking = true
    local session = chat.session
    local args = { "-p", "--output-format", "json", "--tools", "", "--model", MODEL, "--effort", EFFORT,
                   "--append-system-prompt", instructions(),
                   chat.started and "--resume" or "--session-id", session }
    run("claude", args, function(out, code)
        fact.thinking = false
        if session ~= chat.session then return end      -- a new chat was started meanwhile
        local ok, reply = pcall(json.decode, out or "")
        local answer
        if ok and type(reply) == "table" and reply.result and not reply.is_error then
            answer = reply.result
            chat.started = true
        else
            answer = "*(Whiskey couldn't reach Claude"
                .. ((ok and type(reply) == "table" and reply.result) and (": " .. tostring(reply.result)) or ("; exit " .. tostring(code)))
                .. ")*"
            log("claude -p failed: exit " .. tostring(code) .. " " .. tostring(out):sub(1, 300))
        end
        table.insert(chat.said, { text = answer, mine = false })
        show_chat()
        save_chat()
    end, { input = msg, errors = false })
end)

--  ── Called with Alt ─────────────────────────────────────────────────────────
--  Hyprland sets fact `calling` while Alt is held (a bind in hyprland.lua runs
--  `pleamar --say whiskey "fact calling true"`, and false on release). The cat
--  walks to just beside the mouse, on whatever monitor it is.
local calling = nil
local function come()
    run("hyprctl", { "cursorpos", "-j" }, function(out, code)
        if code ~= 0 or not fact.calling or fact.held then return end
        local ok, c = pcall(json.decode, out)
        if not ok or type(c) ~= "table" or not c.x then return end
        local _, r = monitor_at(c.x, c.y)
        if not r then return end
        local x0, x1, y0, y1 = area(r)
        local side = c.x < gx and 1 or -1                -- stop on the side it comes from
        walk_to(math.clamp(c.x + side * 50, x0, x1), math.clamp(c.y + 60, y0, y1))
    end)
end
on("fact:calling", function(on_)
    if on_ then
        fact.asleep = false
        come()
        if not calling then calling = every(150, come) end
    elseif calling then
        cancel(calling); calling = nil
        after(3300, pick_mood)
    end
end)
