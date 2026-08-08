-- ============================================================
--  ПОЛЮС-11 — ОКНО РЕПОРТОВ (client) v4.8.2 «ДОКЛАД»
--  Открытие: /репорты /reports !репорты !reports • p11_reports.
--  Админ видит ВСЕ тикеты + кнопки:
--   ✔ ПРИНЯТЬ (берёт в работу)  •  ↗ К НЕМУ (тп к автору)
--   ↙ К СЕБЕ (автора к тебе)    •  ✕ ЗАКРЫТЬ.
--  Игрок видит СВОИ тикеты и форму отправки новой жалобы.
-- ============================================================

P11R = P11R or { list = {} }

surface.CreateFont("P11.RP.Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.RP.Text",  { font = "Roboto", size = 18, weight = 600, extended = true })
surface.CreateFont("P11.RP.Small", { font = "Roboto", size = 15, weight = 500, extended = true })
surface.CreateFont("P11.RP.Tiny",  { font = "Roboto", size = 13, weight = 500, extended = true })

local RC = {
    bg     = Color(10, 14, 20, 246),
    panel  = Color(20, 26, 36, 255),
    cyan   = Color(120, 185, 255),
    gold   = Color(255, 205, 110),
    text   = Color(228, 236, 245),
    dim    = Color(150, 165, 180),
    ok     = Color(115, 215, 135),
    bad    = Color(235, 100, 90),
    violet = Color(190, 145, 255),
}

local function IsAdm()
    local me = LocalPlayer()
    return IsValid(me) and P11FW.Config and P11FW.Config.Admin
        and P11FW.Config.Admin(me) or false
end

-- ============ СЕТЬ ============

local function Send(op, id)
    net.Start("P11_Rep")
        net.WriteUInt(op, 4)
        if op == 1 then
            -- текст пишет вызывающий
        elseif id then
            net.WriteUInt(id, 16)
        end
    net.SendToServer()
end

net.Receive("P11_Rep", function()
    local op = net.ReadUInt(4)
    if op == 1 then -- список
        local n = net.ReadUInt(8)
        local lst = {}
        for i = 1, n do
            lst[i] = {
                id     = net.ReadUInt(16),
                name   = net.ReadString(),
                sid    = net.ReadString(),
                text   = net.ReadString(),
                status = net.ReadString(),
                by     = net.ReadString(),
                age    = net.ReadUInt(16),
            }
        end
        P11R.list = lst
        if IsValid(P11R.frame) then P11R.frame:Refresh() end

    elseif op == 2 then -- тост
        local txt = net.ReadString()
        local snd = net.ReadBool()
        chat.AddText(Color(255, 125, 115), "[РЕПОРТЫ] ", Color(232, 238, 245), txt)
        if snd then surface.PlaySound("buttons/button17.wav") end
        -- v4.17.0 «КОНТРАБАНДА» (заявка): справа само выезжает менюшка
        -- репортов у админа, когда кто-то пишет репорт (анти-спам 12 сек)
        if IsAdm() then
            P11R._autoNext = P11R._autoNext or 0
            if CurTime() >= P11R._autoNext then
                P11R._autoNext = CurTime() + 12
                P11.OpenReports(true)
            end
        end

    elseif op == 4 then -- открыть окно
        if P11.OpenReports then P11.OpenReports() end
    end
end)

-- ============ ОКНО ============

local function AgeTxt(sec)
    sec = tonumber(sec) or 0
    if sec < 70 then return math.max(1, math.floor(sec)) .. " сек назад" end
    if sec < 3600 then return math.floor(sec / 60) .. " мин назад" end
    return math.floor(sec / 3600) .. " ч " .. math.floor((sec % 3600) / 60) .. " мин назад"
end

local function StatusChip(r)
    if r.status == "taken" then
        return "В РАБОТЕ: " .. (r.by or "?"), RC.cyan
    elseif r.status == "closed" then
        return "ЗАКРЫТ", RC.dim
    end
    return "ОТКРЫТ", RC.gold
end

function P11.OpenReports(dockRight) -- v4.17.0: dockRight=true — окно справа (авто-вызов репортом)
    if IsValid(P11R.frame) then P11R.frame:Remove() end
    local adm = IsAdm()

    local f = vgui.Create("DFrame")
    P11R.frame = f
    f:SetSize(640, 520)
    if dockRight then -- v4.17.0: авто-выезд — прижат к правому краю
        f:SetPos(ScrW() - 640 - 56, math.floor((ScrH() - 520) / 2))
    else
        f:Center()
    end
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.OnRemove = function() if P11R.frame == f then P11R.frame = nil end end

    f.Paint = function(s, w, h)
        if P11.DrawDim then P11.DrawDim(s, 130) end
        draw.RoundedBox(10, 0, 0, w, h, RC.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 64, RC.panel, true, true, false, false)
        surface.SetDrawColor(RC.cyan.r, RC.cyan.g, RC.cyan.b, 140)
        surface.DrawRect(0, 64, w, 1)
        surface.SetDrawColor(150, 215, 245, 90)
        surface.DrawRect(0, 0, 28, 2)
        surface.DrawRect(0, 0, 2, 28)
        draw.SimpleText("📨 РЕПОРТЫ СТАНЦИИ", "P11.RP.Title", 16, 22, RC.cyan, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(adm and "ты администратор: принимай жалаобы, телепортируйся, закрывай"
            or "твои жалобы администрации • ответ придёт в чат",
            "P11.RP.Tiny", 16, 47, RC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- ✕ закрыть
    local xb = vgui.Create("DButton", f)
    xb:SetPos(640 - 40, 10) xb:SetSize(26, 24)
    xb:SetText("")
    xb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(120, 40, 36) or Color(60, 30, 28))
        draw.SimpleText("✕", "P11.RP.Small", w / 2, h / 2 - 1, Color(240, 200, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    xb.DoClick = function() surface.PlaySound("buttons/button10.wav") f:Remove() end

    -- ⟳ обновить
    local rb = vgui.Create("DButton", f)
    rb:SetPos(640 - 118, 10) rb:SetSize(68, 24)
    rb:SetText("")
    rb.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(40, 60, 84) or Color(26, 38, 54))
        draw.SimpleText("⟳ обновить", "P11.RP.Tiny", w / 2, h / 2, RC.cyan, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    rb.DoClick = function() surface.PlaySound("buttons/button9.wav") Send(6) end

    -- ---------- СПИСОК ----------
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 74) sc:SetSize(616, 330)
    local sb = sc:GetVBar()
    sb:SetWide(5)
    sb.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 18)) end
    sb.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, RC.cyan) end

    local function MiniBtn(parent, x, y, w, name, col, fn, disabled)
        local b = vgui.Create("DButton", parent)
        b:SetPos(x, y) b:SetSize(w, 24)
        b:SetText("")
        b.Dis = disabled
        b.Paint = function(s, ww, hh)
            local a = s.Dis and 24 or (s:IsHovered() and 70 or 42)
            draw.RoundedBox(4, 0, 0, ww, hh, Color(col.r, col.g, col.b, a))
            surface.SetDrawColor(col.r, col.g, col.b, s.Dis and 60 or 150)
            surface.DrawOutlinedRect(0, 0, ww, hh, 1)
            draw.SimpleText(name, "P11.RP.Tiny", ww / 2, hh / 2, s.Dis and RC.dim or col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if b.Dis then surface.PlaySound("buttons/button10.wav") return end
            surface.PlaySound("buttons/button9.wav")
            fn()
        end
        return b
    end

    function f:Refresh()
        sc:Clear()
        local list = P11R.list or {}

        if #list == 0 then
            local l = sc:Add("DLabel")
            l:Dock(TOP) l:DockMargin(4, 24, 4, 4)
            l:SetFont("P11.RP.Text") l:SetTextColor(RC.dim)
            l:SetContentAlignment(5)
            l:SetText(adm
                and "Пока пусто — жалоб нет. Станция довольна."
                or "У тебя пока нет репортов. Есть проблема — напиши в форме ниже.")
            l:SetTall(48)
            return
        end

        for _, r in ipairs(list) do
            local chipTxt, chipCol = StatusChip(r)
            local cardH = 92

            local card = sc:Add("DPanel")
            card:Dock(TOP) card:DockMargin(2, 2, 6, 6)
            card:SetTall(cardH)
            card.Paint = function(s, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(15, 20, 28, 255))
                surface.SetDrawColor(chipCol.r, chipCol.g, chipCol.b, 120)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.RoundedBoxEx(8, 0, 0, 4, h, chipCol, true, false, true, false)

                draw.SimpleText("#" .. r.id .. "  " .. (r.name or "?"), "P11.RP.Text", 12, 12, RC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(AgeTxt(r.age), "P11.RP.Tiny", 12, 31, RC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(r.sid or "", "P11.RP.Tiny", 130, 31, Color(110, 122, 136), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                -- чип статуса справа сверху
                surface.SetFont("P11.RP.Tiny")
                local cw = (surface.GetTextSize(chipTxt) or 60) + 16
                draw.RoundedBox(4, w - cw - 8, 6, cw, 18, Color(chipCol.r, chipCol.g, chipCol.b, 34))
                surface.SetDrawColor(chipCol.r, chipCol.g, chipCol.b, 140)
                surface.DrawOutlinedRect(w - cw - 8, 6, cw, 18, 1)
                draw.SimpleText(chipTxt, "P11.RP.Tiny", w - cw / 2 - 8, 15, chipCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                -- текст жалобы (укороченный в один ряд)
                local t = tostring(r.text or "")
                if #t > 150 then t = string.sub(t, 1, 150) .. "…" end
                draw.SimpleText(t, "P11.RP.Small", 12, 54, Color(205, 214, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if adm then
                -- кнопки админа: ✔ / ↗ / ↙ / ✕
                local closed = (r.status == "closed")
                MiniBtn(card, 12, cardH - 30, 92, "✔ ПРИНЯТЬ", RC.ok, function() Send(2, r.id) end,
                    closed or r.status == "taken" and r.by == LocalPlayer():Nick())
                MiniBtn(card, 112, cardH - 30, 88, "↗ К НЕМУ", RC.violet, function() Send(3, r.id) end, closed)
                MiniBtn(card, 208, cardH - 30, 88, "↙ К СЕБЕ", RC.gold, function() Send(4, r.id) end, closed)
                MiniBtn(card, 304, cardH - 30, 92, "✕ ЗАКРЫТЬ", RC.bad, function() Send(5, r.id) end, closed)
            else
                local st = vgui.Create("DLabel", card)
                st:SetPos(12, cardH - 30) st:SetSize(420, 24)
                st:SetFont("P11.RP.Tiny") st:SetTextColor(RC.dim)
                if r.status == "taken" then
                    st:SetText("админ " .. (r.by or "?") .. " уже разбирает — жди, он рядом со станцией.")
                    st:SetTextColor(RC.cyan)
                elseif r.status == "closed" then
                    st:SetText("закрыт администрацией.")
                else
                    st:SetText("передан администрации — ответ придёт в чат.")
                end
            end
        end
    end

    -- ---------- ФОРМА НОВОГО РЕПОРТА (для всех) ----------
    local botY = 410
    local bl = vgui.Create("DLabel", f)
    bl:SetPos(14, botY) bl:SetSize(612, 18)
    bl:SetFont("P11.RP.Small") bl:SetTextColor(RC.gold)
    bl:SetText("НОВЫЙ РЕПОРТ (увидят админы онлайн; кулдаун 60 сек):")

    local entry = vgui.Create("DTextEntry", f)
    entry:SetPos(14, botY + 22) entry:SetSize(470, 34)
    entry:SetFont("P11.RP.Text")
    entry:SetTextColor(RC.text)
    entry:SetCursorColor(RC.cyan)
    entry:SetMaxLength(220)
    entry:SetPlaceholderText("Что случилось? Кто? Где? (до 220 знаков)")
    entry.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(6, 10, 15, 255))
        surface.SetDrawColor(RC.cyan.r, RC.cyan.g, RC.cyan.b, s:HasFocus() and 170 or 60)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        s:DrawTextEntryText(RC.text, RC.cyan, RC.text)
    end

    local function DoSend()
        local txt = string.Trim(entry:GetValue() or "")
        if txt == "" then
            surface.PlaySound("buttons/button10.wav")
            chat.AddText(RC.bad, "[РЕПОРТЫ] ", RC.text, "Напиши суть жалобы — пустой репорт не уходит.")
            return
        end
        net.Start("P11_Rep")
            net.WriteUInt(1, 4)
            net.WriteString(txt)
        net.SendToServer()
        entry:SetText("")
        surface.PlaySound("buttons/button15.wav")
    end
    entry.OnEnter = DoSend
    entry.OnKeyCodeTyped = function(s, code)
        if code == KEY_ESCAPE then f:Remove() return true end
    end

    local sb2 = vgui.Create("DButton", f)
    sb2:SetPos(492, botY + 22) sb2:SetSize(134, 34)
    sb2:SetText("")
    sb2.Paint = function(ss, ww, hh)
        draw.RoundedBox(6, 0, 0, ww, hh, ss:IsHovered() and Color(52, 108, 70) or Color(38, 84, 54))
        draw.SimpleText("ОТПРАВИТЬ ➜", "P11.RP.Small", ww / 2, hh / 2, RC.ok, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    sb2.DoClick = DoSend

    local foot = vgui.Create("DLabel", f)
    foot:SetPos(14, botY + 66) foot:SetSize(612, 36)
    foot:SetFont("P11.RP.Tiny") foot:SetTextColor(RC.dim)
    foot:SetText(adm
        and "Горячие клавиши админа: ↗ К НЕМУ / ↙ К СЕБЕ телепортируют сразу (античит в курсе — льготное окно)."
        or "Также работает из чата: /report <текст>. За ложные вызовы — разговор с НКВД.")

    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() end
    end

    f:Refresh()
    Send(6) -- попросить свежий список сразу при открытии
    if P11.AnimateIn then P11.AnimateIn(f) end
end

concommand.Add("p11_reports", function()
    P11.OpenReports()
end)

print("[POLUS-11] окно репортов v4.8.2 «ДОКЛАД» загружено (/репорты)")
