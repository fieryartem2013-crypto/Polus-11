-- ============================================================
--  ПОЛЮС-11 — МЕДАЛИ «ПОЧЁТ» (client) v5.2.3 → v2 (НОВЫЙ ФАЙЛ)
--  Кэш реестра + помощники отрисовки (ТАБ, ники над головами)
--  + окно вручения + вкладка МЕДАЛИ в админке.
--  Публичный API сохранён: P11.MedalIds / MedalGlyphs /
--  MedalColorOf / MedalCells / MedalTop / MedalScopeLocal /
--  MedalAwardMenu / P11FW.MedalsTabBuild.
--  Старый p11_cl_medals.lua ОТКЛЮЧЁН (не загружается).
-- ============================================================

P11 = P11 or {}
P11.Medals = P11.Medals or { defs = {}, list = {} }

surface.CreateFont("P11.Med.Big",   { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("P11.Med.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Med.Tx",    { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.Med.Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local MED_COL_BG   = Color(10, 14, 20, 248)
local MED_COL_PANE = Color(24, 30, 40, 255)
local MED_COL_GOLD = Color(255, 205, 100)
local MED_COL_TEXT = Color(232, 238, 245)
local MED_COL_DIM  = Color(150, 158, 172)
local MED_COL_BAD  = Color(240, 100, 90)

-- ============ ПРИЁМ РЕЕСТРА (WriteString → JSON, как фракции) ============

net.Receive("P11_MedalSync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(tbl) then return end
    if istable(tbl.defs) then P11.Medals.defs = tbl.defs end
    if istable(tbl.list) then P11.Medals.list = tbl.list end
end)

-- ============ ПОМОЩНИКИ ОТРИСОВКИ ============

function P11.MedalIds(ply)
    if not IsValid(ply) then return {} end
    return P11.Medals.list[ply:SteamID64()] or {}
end

--- строка глифов для надголовья/ТАБа: до maxn значков + полное N
function P11.MedalGlyphs(ply, maxn)
    local ids = P11.MedalIds(ply)
    local n = #ids
    if n == 0 then return "", 0 end
    maxn = maxn or 3
    local parts = {}
    for i = 1, math.min(n, maxn) do
        local d = P11.Medals.defs[ids[i]]
        parts[#parts + 1] = (d and d.g) or "?"
    end
    return table.concat(parts, " "), n
end

--- палитра металлов по уставу: у каждого знака свой цвет
local MEDAL_PAL = {
    ["★"] = Color(255, 205, 100), ["☆"] = Color(255, 226, 140),
    ["♥"] = Color(255, 112, 132), ["♦"] = Color(255, 152,  92),
    ["◆"] = Color(115, 195, 160), ["○"] = Color(150, 205, 245),
    ["▲"] = Color(125, 165, 235), ["■"] = Color(176, 182, 196),
    ["●"] = Color(195, 150, 240), ["♠"] = Color(122, 220, 152),
    ["◇"] = Color(232, 236, 245),
}

--- цвет знака по id медали (фолбэк: ведомственные — лёд, штабные — золото)
function P11.MedalColorOf(id)
    local d = P11.Medals.defs[id]
    local g = d and d.g or "★"
    return MEDAL_PAL[g] or (d and d.dept == 1 and Color(150, 205, 245) or Color(255, 205, 100))
end

--- фишки для лент/планок: до maxn ячеек {g,name,desc,col} + полное число медалей
function P11.MedalCells(ply, maxn)
    local ids = P11.MedalIds(ply)
    local total = #ids
    if total == 0 then return {}, 0 end
    maxn = maxn or 4
    local cells = {}
    for i = 1, math.min(total, maxn) do
        local d = P11.Medals.defs[ids[i]]
        cells[i] = {
            g    = (d and d.g) or "?",
            name = (d and d.n) or tostring(ids[i]),
            desc = (d and d.d) or "",
            col  = P11.MedalColorOf(ids[i]),
        }
    end
    return cells, total
end

--- доска почёта: top-n онлайн-бойцов по числу медалей
function P11.MedalTop(n)
    local t = {}
    for _, p in ipairs(player.GetAll()) do
        local cnt = #P11.MedalIds(p)
        if cnt > 0 then
            local nick = p:GetNWString("P11_CharName", "")
            if nick == "" then nick = p:Nick() end
            t[#t + 1] = { name = nick, n = cnt }
        end
    end
    table.sort(t, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, math.min(n or 3, #t) do out[#out + 1] = t[i] end
    return out
end

--- кто может вручать (зеркало сервера): "full" / "dept" / nil
function P11.MedalScopeLocal()
    local me = LocalPlayer()
    if not IsValid(me) then return nil end
    if me:IsSuperAdmin() then return "full" end
    if P11FW and P11FW.GetRankLevel then
        if (tonumber(P11FW.GetRankLevel(me)) or 0) >= 9 then return "full" end
        local r = P11FW.GetRank and P11FW.GetRank(me)
        if r and r.id == "faction_leader" then return "dept" end
    end
    return nil
end

-- ============ ОКНО ВРУЧЕНИЯ ============

function P11.MedalAwardMenu(target)
    if not IsValid(target) then return end
    local scope = P11.MedalScopeLocal()
    if not scope then
        chat.AddText(MED_COL_GOLD, "[ПОЧЁТ] ", MED_COL_TEXT,
            "Медали вручают: Faction Leader (ведомственные ○▲■) и ранг Developer+ (все).")
        return
    end
    if IsValid(P11.MedalFrame) then P11.MedalFrame:Remove() end

    local nick = target:GetNWString("P11_CharName", "")
    if nick == "" then nick = target:Nick() end

    local f = vgui.Create("DFrame")
    P11.MedalFrame = f
    f:SetSize(430, 470)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, MED_COL_BG)
        draw.RoundedBoxEx(10, 0, 0, w, 56, MED_COL_PANE, true, true, false, false)
        surface.SetDrawColor(MED_COL_GOLD)
        surface.DrawRect(0, 56, w, 2)
        draw.SimpleText("НАГРАДИТЬ", "P11.Med.Big", 16, 12, MED_COL_GOLD)
        draw.SimpleText(nick .. (scope == "dept" and "  ·  ведомственные медали" or "  ·  полная казна"),
            "P11.Med.Tx", 18, 40, MED_COL_DIM)
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(430 - 36, 12) x:SetSize(24, 24) x:SetText("")
    x.Paint = function(s, w, h)
        draw.SimpleText("✕", "P11.Med.Mid", w / 2, h / 2,
            s:IsHovered() and MED_COL_BAD or MED_COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    x.DoClick = function() f:Remove() end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(10, 64) sc:SetSize(410, 394)
    local bar = sc:GetVBar() bar:SetWide(5)
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 14)) end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, MED_COL_GOLD) end

    local order = { "zorkiy", "obhod", "sluzhba", "geroy", "mercy", "poriadok", "veteran", "legenda" }
    local mine = {}
    for _, m in ipairs(P11.MedalIds(target)) do mine[m] = true end

    for _, id in ipairs(order) do
        local d = P11.Medals.defs[id]
        if d then
            local dept = (d.dept == 1 or d.dept == true)
            local locked = (scope == "dept" and not dept) or mine[id]
            local pnl = sc:Add("DPanel")
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 6) pnl:SetTall(58)
            pnl.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, MED_COL_PANE)
                local gc = locked and MED_COL_DIM or MED_COL_GOLD
                draw.SimpleText(d.g or "?", "P11.Med.Big", 26, h / 2, gc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(d.n or id, "P11.Med.Mid", 52, 12, locked and MED_COL_DIM or MED_COL_TEXT)
                draw.SimpleText((locked and not dept and scope == "dept")
                    and ("только ранг Developer+ · " .. (d.d or ""))
                    or (mine[id] and ("УЖЕ ЕСТЬ · " .. (d.d or "")) or (d.d or "")),
                    "P11.Med.Small", 52, 38, MED_COL_DIM)
            end
            local b = vgui.Create("DButton", pnl)
            b:SetPos(410 - 10 - 86, 15) b:SetSize(82, 28) b:SetText("")
            b.Paint = function(s, w, h)
                draw.RoundedBox(5, 0, 0, w, h,
                    locked and Color(60, 64, 72, 200)
                    or (s:IsHovered() and Color(255, 205, 100, 235) or Color(150, 120, 55, 220)))
                draw.SimpleText("ВРУЧИТЬ", "P11.Med.Tx", w / 2, h / 2 - 1,
                    locked and MED_COL_DIM or Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                if locked then
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                net.Start("P11_MedalAct")
                    net.WriteUInt(1, 4)
                    net.WriteString(target:SteamID64())
                    net.WriteString(id)
                net.SendToServer()
                surface.PlaySound("buttons/button15.wav")
                timer.Simple(0.4, function()
                    if IsValid(f) then f:Remove() end
                    if IsValid(target) then P11.MedalAwardMenu(target) end
                end)
            end
        end
    end

    surface.PlaySound("buttons/button14.wav")
end

-- ============ ВКЛАДКА «МЕДАЛИ» В АДМИНКЕ ============

function P11FW.MedalsTabBuild(p, frame)
    local selSid, selNick = nil, "—"

    local lv = vgui.Create("DListView", p)
    lv:SetPos(10, 10) lv:SetSize(400, 450)
    lv:SetMultiSelect(false)
    lv:AddColumn("Боец"):SetFixedWidth(230)
    lv:AddColumn("Медалей"):SetFixedWidth(70)
    lv:AddColumn("Знаки")

    local medP = vgui.Create("DPanel", p)
    medP:SetPos(420, 10) medP:SetSize(426, 450)
    medP.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 60))
        draw.SimpleText("МЕДАЛИ БОЙЦА", "P11.Med.Small", 12, 8, MED_COL_DIM)
        draw.SimpleText(selNick, "P11.Med.Mid", 12, 26, MED_COL_GOLD)
    end

    local medScroll = vgui.Create("DScrollPanel", medP)
    medScroll:SetPos(8, 52) medScroll:SetSize(410, 334)
    local bar = medScroll:GetVBar() bar:SetWide(5)
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, MED_COL_GOLD) end
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 12)) end

    local function RefillMedals()
        medScroll:Clear()
        if not selSid then return end
        local arr = P11.Medals.list[selSid] or {}
        if #arr == 0 then
            local l = medScroll:Add("DLabel")
            l:SetFont("P11.Med.Tx") l:SetTextColor(MED_COL_DIM)
            l:SetText("  Медалей нет. Вручи первую — кнопка ниже.")
            l:SizeToContents()
            return
        end
        for i, id in ipairs(arr) do
            local d = P11.Medals.defs[id]
            local row = medScroll:Add("DPanel")
            row:Dock(TOP) row:DockMargin(0, 0, 0, 5) row:SetTall(44)
            row.Paint = function(s, w, h)
                draw.RoundedBox(5, 0, 0, w, h, Color(255, 255, 255, 10))
                draw.SimpleText((d and d.g) or "?", "P11.Med.Mid", 20, h / 2, MED_COL_GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText((d and d.n) or id, "P11.Med.Tx", 40, h / 2, MED_COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local rb = vgui.Create("DButton", row)
            rb:SetPos(410 - 8 - 66, 9) rb:SetSize(62, 26) rb:SetText("")
            rb.medIdx = i
            rb.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(240, 100, 90, 225) or Color(120, 55, 50, 200))
                draw.SimpleText("СНЯТЬ", "P11.Med.Small", w / 2, h / 2 - 1, MED_COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            rb.DoClick = function(s)
                net.Start("P11_MedalAct")
                    net.WriteUInt(2, 4)
                    net.WriteString(selSid)
                    net.WriteUInt(s.medIdx, 6)
                net.SendToServer()
                surface.PlaySound("buttons/button10.wav")
                timer.Simple(0.5, function()
                    if IsValid(frame) and frame.RefreshMedals then frame:RefreshMedals() end
                end)
            end
        end
    end

    local btnAward = vgui.Create("DButton", medP)
    btnAward:SetPos(8, 394) btnAward:SetSize(200, 36) btnAward:SetText("")
    btnAward.Paint = function(s, w, h)
        local on = selSid ~= nil
        draw.RoundedBox(6, 0, 0, w, h,
            on and (s:IsHovered() and Color(255, 205, 100, 240) or Color(150, 120, 55, 220))
             or Color(60, 64, 72, 200))
        draw.SimpleText("★ ВРУЧИТЬ МЕДАЛЬ", "P11.Med.Tx", w / 2, h / 2 - 1,
            on and Color(20, 22, 26) or MED_COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnAward.DoClick = function()
        if not selSid then return end
        for _, pl in ipairs(player.GetAll()) do
            if pl:SteamID64() == selSid then
                P11.MedalAwardMenu(pl)
                return
            end
        end
        chat.AddText(MED_COL_GOLD, "[ПОЧЁТ] ", MED_COL_TEXT, "Боец оффлайн — вручение доступно кнопкой только на живом.")
    end

    local btnRefresh = vgui.Create("DButton", medP)
    btnRefresh:SetPos(216, 394) btnRefresh:SetSize(200, 36) btnRefresh:SetText("")
    btnRefresh.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(90, 110, 135, 220) or Color(55, 65, 80, 200))
        draw.SimpleText("ОБНОВИТЬ РЕЕСТР", "P11.Med.Tx", w / 2, h / 2 - 1, MED_COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btnRefresh.DoClick = function()
        net.Start("P11_MedalAct") net.WriteUInt(9, 4) net.SendToServer()
        surface.PlaySound("buttons/button9.wav")
        timer.Simple(0.6, function()
            if IsValid(frame) and frame.RefreshMedals then frame:RefreshMedals() end
        end)
    end

    local function RefillRoster()
        lv:Clear()
        for _, pl in ipairs(player.GetAll()) do
            local ids = P11.MedalIds(pl)
            local nick = pl:GetNWString("P11_CharName", "")
            if nick == "" then nick = pl:Nick() end
            local line = lv:AddLine(nick, #ids, "")
            line.sid64 = pl:SteamID64()
            line.nick = nick
            -- v5.2.3: в колонке «Знаки» рисуем МЕДАЛИ цветными значками
            line.PaintOver = function(s, w, h)
                local ids2 = P11.MedalIds(pl)
                local n = #ids2
                if n == 0 then return end
                local x = 318
                local shown = math.min(n, 4)
                for i = 1, shown do
                    local d = P11.Medals.defs[ids2[i]]
                    if d then
                        local col = P11.MedalColorOf(ids2[i])
                        draw.RoundedBox(4, x, h / 2 - 9, 18, 18, Color(col.r, col.g, col.b, 45))
                        draw.RoundedBoxEx(4, x, h / 2 - 9, 18, 3, Color(col.r, col.g, col.b, 180), true, true, false, false)
                        draw.SimpleText(d.g or "?", "P11.Med.Small", x + 9, h / 2, col,
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        x = x + 21
                    end
                end
                if n > shown then
                    draw.SimpleText("+" .. (n - shown), "P11.Med.Small", x + 2, h / 2,
                        MED_COL_GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end
        RefillMedals()
    end

    lv.OnRowSelected = function(_, _, line)
        selSid, selNick = line.sid64, line.nick
        RefillMedals()
        surface.PlaySound("buttons/button9.wav")
    end

    frame.RefreshMedals = RefillRoster
    RefillRoster()
end

print("[POLUS-11] медали «ПОЧЁТ» (client) v5.2.3 → v2 (НОВЫЙ ФАЙЛ): реестр, надголовье, ТАБ, вручение, вкладка МЕДАЛИ")
