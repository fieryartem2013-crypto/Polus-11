-- ============================================================
--  ПОЛЮС-11 — СВОЙ ЧАТ-UI (client) v4.6.8 — ПОЛНОСТЬЮ С НУЛЯ
--  • Y — строка ввода с КНОПКОЙ КАНАЛА СЛЕВА (РЕЧЬ/OOC/LOOC/ME/IT/
--    РЕПОРТ), U — сразу OOC;
--  • лента слева внизу, гаснет через ~10 сек;
--  • системные chat.AddText ловятся в ту же ленту;
--  • ванильная коробка скрыта (вернуть: p11_vanilla_chat 1);
--  • самопроверка при загрузке: смотри консоль «[P11CHAT] v4.6.8 OK»;
--  • диагностика: p11_chatdiag_cl.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Chat.Text2", { font = "Roboto", size = 18, weight = 600, extended = true })
surface.CreateFont("P11.Chat.Btn2",  { font = "Roboto", size = 15, weight = 800, extended = true })

local CHAT = P11.Chat or {}
P11.Chat = CHAT
CHAT.lines = CHAT.lines or {}

local MAXW   = 660
local LINE_H = 22
local MAXVIS = 12
local FADE_S = 10

local CHANNELS = {
    { label = "РЕЧЬ",   prefix = "",         col = Color(228, 236, 245) },
    { label = "OOC",    prefix = "/ooc ",    col = Color(170, 176, 188) },
    { label = "LOOC",   prefix = "/looc ",   col = Color(145, 152, 165) },
    { label = "ME",     prefix = "/me ",     col = Color(205, 165, 255) },
    { label = "IT",     prefix = "/it ",     col = Color(255, 205, 110) },
    { label = "РЕПОРТ", prefix = "/report ", col = Color(235, 100, 90)  },
}

local cvVanilla = CreateClientConVar("p11_vanilla_chat", "0", true, false,
    "1 = вернуть штатный чат движка (если своей ленты не видно)")

-- ---------- переносы ----------
local function WrapParts(parts)
    surface.SetFont("P11.Chat.Text2")
    local vlines, cur, curW = {}, {}, 0
    local function Flush() vlines[#vlines + 1] = cur cur, curW = {}, 0 end
    local function PushWord(col, word)
        local w = surface.GetTextSize(word)
        if curW + w > MAXW and curW > 0 then Flush() end
        cur[#cur + 1] = { col = col, txt = word }
        curW = curW + w
    end
    for _, part in ipairs(parts) do
        local col = part.col or color_white
        local txt = tostring(part.txt or "")
        for piece in string.gmatch(txt .. "\n", "(.-)\n") do
            for word in string.gmatch(piece, "%S+%s*") do
                PushWord(col, word)
            end
            if #cur > 0 and piece ~= txt then Flush() end
        end
        if string.sub(txt, -1) == "\n" and #cur > 0 then Flush() end
    end
    if #cur > 0 then Flush() end
    return vlines
end

function CHAT.AddParts(parts)
    local ok, vlines = pcall(WrapParts, parts)
    if not ok or not vlines or #vlines == 0 then return end
    CHAT.lines[#CHAT.lines + 1] = { t = CurTime(), vlines = vlines }
    while #CHAT.lines > 60 do table.remove(CHAT.lines, 1) end
end

local function DrawLine(vline, x, y)
    local cx = x
    surface.SetFont("P11.Chat.Text2")
    for _, part in ipairs(vline) do
        local c = part.col or color_white
        draw.SimpleText(part.txt, "P11.Chat.Text2", cx, y,
            Color(c.r, c.g, c.b), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        cx = cx + (surface.GetTextSize(part.txt) or 0)
    end
end

-- ---------- отрисовка ленты (под бронёй: ошибка не убьёт чат) ----------
local paintErrShown = false
hook.Add("HUDPaint", "P11.ChatPaint", function()
    local ok, err = pcall(function()
        if cvVanilla:GetBool() then return end
        if P11B and P11B.open then return end
        local x0, y = 20, ScrH() - 152 - (CHAT.boxOpen and 46 or 0)
        local shown = 0
        for i = #CHAT.lines, 1, -1 do
            local ln = CHAT.lines[i]
            local age = CurTime() - ln.t
            local a = CHAT.boxOpen and 1 or math.Clamp(1 - (age - FADE_S) * 0.5, 0, 1)
            if a <= 0 then break end
            for j = #ln.vlines, 1, -1 do
                if shown >= MAXVIS then return end
                local vh = y - shown * LINE_H - LINE_H
                surface.SetAlphaMultiplier(a * 0.85)
                draw.RoundedBox(4, x0 - 4, vh + 1, 8 + MAXW, LINE_H - 2, Color(10, 14, 20, 150))
                surface.SetAlphaMultiplier(a)
                DrawLine(ln.vlines[j], x0, vh)
                shown = shown + 1
            end
        end
    end)
    surface.SetAlphaMultiplier(1)
    if not ok and not paintErrShown then
        paintErrShown = true
        ErrorNoHalt("[P11CHAT ERROR HUDPaint] " .. tostring(err) .. "\n")
    end
end)

-- ---------- вход 1: серверные пакеты каналов ----------
net.Receive("P11_ChatMsg", function()
    local ch   = net.ReadUInt(4)
    local name = net.ReadString()
    local text = net.ReadString()
    local ncol = net.ReadColor()
    if cvVanilla:GetBool() then return end

    if ch == 1 then
        CHAT.AddParts({ { col = ncol, txt = name }, { col = Color(120, 185, 255), txt = " говорит: " }, { col = Color(235, 240, 246), txt = text } })
    elseif ch == 2 then
        CHAT.AddParts({ { col = Color(150, 158, 172), txt = "[OOC] " }, { col = ncol, txt = name }, { col = Color(175, 180, 192), txt = ": " .. text } })
    elseif ch == 3 then
        CHAT.AddParts({ { col = Color(128, 136, 150), txt = "[LOOC] " }, { col = ncol, txt = name }, { col = Color(150, 156, 168), txt = ": " .. text } })
    elseif ch == 4 then
        CHAT.AddParts({ { col = Color(205, 165, 255), txt = "• " .. name .. " " .. text } })
    elseif ch == 5 then
        CHAT.AddParts({ { col = Color(255, 205, 110), txt = "*** " .. text } })
    elseif ch == 6 then
        CHAT.AddParts({ { col = Color(235, 100, 90), txt = "[РЕПОРТ] " }, { col = ncol, txt = name }, { col = Color(240, 150, 140), txt = ": " .. text } })
    end
end)

-- ---------- вход 2: системные chat.AddText ----------
local oldAddText = chat.AddText
function chat.AddText(...)
    if not cvVanilla:GetBool() then
        local parts, cur = {}, Color(235, 238, 244)
        for _, a in ipairs({ ... }) do
            if IsColor(a) then cur = a
            elseif isstring(a) or isnumber(a) then
                local t = string.gsub(tostring(a), "\n$", "")
                if t ~= "" then parts[#parts + 1] = { col = cur, txt = t } end
            elseif type(a) == "Player" and IsValid(a) then
                parts[#parts + 1] = { col = cur, txt = a:Nick() }
            end
        end
        if #parts > 0 then CHAT.AddParts(parts) end
    end
    return oldAddText(...)
end

-- ---------- страховка: движковые речи тоже в ленту (и глушим ваниль) ----------
hook.Add("OnPlayerChat", "P11.ChatCapture", function(ply, text)
    if cvVanilla:GetBool() then return end
    if IsValid(ply) then -- instanceof
        CHAT.AddParts({ { col = team.GetColor(ply:Team()), txt = ply:Nick() }, { col = Color(235, 240, 246), txt = ": " .. tostring(text) } })
    end
    return true
end)

hook.Add("HUDShouldDraw", "P11.ChatHide", function(name)
    if name == "CHudChat" and not cvVanilla:GetBool() then return false end
end)

-- ---------- строка ввода с кнопкой канала ----------
function CHAT.Open(withChannel)
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
    CHAT.boxOpen = true

    local W, H = 680, 42
    local f = vgui.Create("DPanel")
    CHAT.Box = f
    f:SetSize(W, H)
    f:SetPos(20, ScrH() - 152)
    f:MakePopup()
    f:SetKeyboardInputEnabled(true)
    f:SetMouseInputEnabled(true)

    f.Channel = withChannel or CHAT.lastChannel or 1
    CHAT.lastChannel = f.Channel

    f.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(10, 14, 20, 235))
        surface.SetDrawColor(CHANNELS[s.Channel].col)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local chBtn = vgui.Create("DButton", f)
    chBtn:SetPos(4, 5) chBtn:SetSize(126, 32)
    chBtn:SetText("")
    chBtn.Paint = function(s, w, h)
        local c = CHANNELS[f.Channel]
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 255, 255, 26) or Color(255, 255, 255, 12))
        draw.RoundedBoxEx(5, 0, 0, 4, h, c.col, true, false, true, false)
        draw.SimpleText(c.label .. " ▸", "P11.Chat.Btn2", 12, h / 2, c.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    chBtn.DoClick = function()
        f.Channel = (f.Channel % #CHANNELS) + 1
        CHAT.lastChannel = f.Channel
        surface.PlaySound("buttons/button9.wav")
        if IsValid(f.Entry) then f.Entry:RequestFocus() end
    end

    local entry = vgui.Create("DTextEntry", f)
    f.Entry = entry
    entry:SetPos(136, 5) entry:SetSize(W - 144, 32)
    entry:SetFont("P11.Chat.Text2")
    entry:SetTextColor(Color(235, 240, 246))
    entry:SetCursorColor(Color(235, 240, 246))
    entry:SetPlaceholderText("текст сообщения… (ENTER — отправить, ESC — закрыть, ▸ — канал)")
    entry.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 6))
        s:DrawTextEntryText(Color(235, 240, 246), Color(120, 185, 255), Color(235, 240, 246))
    end

    entry.OnEnter = function()
        local txt = string.Trim(entry:GetValue() or "")
        if txt ~= "" then
            RunConsoleCommand("say", CHANNELS[f.Channel].prefix .. txt)
        end
        CHAT.Close()
    end
    entry:RequestFocus()

    f.Think = function()
        if input.IsKeyDown(KEY_ESCAPE) then
            gui.HideGameUI()
            CHAT.Close()
        end
    end
end

function CHAT.Close()
    CHAT.boxOpen = false
    if IsValid(CHAT.Box) then CHAT.Box:Remove() end
end

hook.Add("PlayerBindPress", "P11.ChatOpen", function(ply, bind, pressed)
    if not pressed then return end
    if string.find(bind, "messagemode2") then
        CHAT.Open(2)
        return true
    end
    if string.find(bind, "messagemode") and not string.find(bind, "messagemode2") then
        CHAT.Open(CHAT.lastChannel or 1)
        return true
    end
end)

-- ---------- диагностика ----------
concommand.Add("p11_chatdiag_cl", function()
    print("[P11CHAT] v4.6.8 | линий в ленте: " .. #CHAT.lines .. " | ваниль: " .. tostring(cvVanilla:GetBool()))
    CHAT.AddParts({
        { col = Color(120, 255, 120), txt = "[ЧАТ-ТЕСТ]" },
        { col = Color(235, 240, 246), txt = " видишь эту строку слева внизу — лента жива." },
    })
end)

print("[P11CHAT] v4.6.8 OK — свой чат загружен (Y — писать, диагностика p11_chatdiag_cl)")
