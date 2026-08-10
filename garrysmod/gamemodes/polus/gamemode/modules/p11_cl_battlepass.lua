-- ============================================================
--  ПОЛЮС-11 — БАТЛ-ПАСС «БИТВА ВРЕМЕНИ» (client) v5.2.0
--  Меню на клавишу F5: уровни 1..20, прогресс XP, награды,
--  кнопка «ЗАБРАТЬ» на каждом открытом уровне.
--  Открыть: F5 · p11_battlepass · чат !батлпасс
-- ============================================================

surface.CreateFont("P11.BP.Huge",  { font = "Roboto", size = 40, weight = 900, extended = true })
surface.CreateFont("P11.BP.Title", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("P11.BP.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.BP.Small", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.BP.Tiny",  { font = "Roboto", size = 12, weight = 500, extended = true })

P11.BP = P11.BP or { data = nil, frame = nil }

local BP_COL = {
    bg    = Color(10, 14, 20, 248),
    panel = Color(20, 26, 36, 255),
    panel2= Color(27, 34, 47, 255),
    gold  = Color(255, 205, 100),
    red   = Color(205, 60, 52),
    text  = Color(232, 238, 245),
    dim   = Color(150, 158, 172),
    ok    = Color(120, 220, 140),
    bad   = Color(240, 100, 90),
}

-- ============ ПРИЁМ ДАННЫХ ============

net.Receive("P11_BP_Sync", function()
    local ok, tbl = pcall(util.JSONToTable, net.ReadString() or "{}")
    if ok and istable(tbl) then
        P11.BP.data = tbl
        if IsValid(P11.BP.frame) and P11.BP.frame.Refill then P11.BP.frame:Refill() end
    end
end)

local function ClaimLvl(lvl)
    net.Start("P11_BP_Claim")
        net.WriteUInt(lvl, 8)
    net.SendToServer()
end

-- ============ МЕНЮ ============

function P11.OpenBattlePass()
    if IsValid(P11.BP.frame) then P11.BP.frame:Remove() P11.BP.frame = nil return end

    local f = vgui.Create("DFrame")
    P11.BP.frame = f
    f:SetSize(760, 640)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()

    local data = P11.BP.data or { lvl = 1, xp = 0, left = 0, need = 100, max = 20, claimed = {}, rewards = {} }

    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(12, 0, 0, w, h, BP_COL.bg)
        -- шапка: красное знамя + золото
        draw.RoundedBoxEx(12, 0, 0, w, 84, BP_COL.panel, true, true, false, false)
        draw.RoundedBoxEx(12, 0, 0, w, 4, BP_COL.red, true, true, false, false)
        surface.SetDrawColor(BP_COL.gold.r, BP_COL.gold.g, BP_COL.gold.b, 130)
        surface.DrawLine(12, 84, w - 12, 84)
        draw.SimpleText("⚔ БАТЛ-ПАСС «БИТВА ВРЕМЕНИ»", "P11.BP.Title", w / 2, 14,
            BP_COL.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("ивент: Крепость Осовец восстала · 30 уровней · делай дела — забирай награды рейха",
            "P11.BP.Small", w / 2, 52, BP_COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- крестик
        draw.SimpleText("✕", "P11.BP.Mid", w - 22, 12, BP_COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- v5.2.1: вкладки НАГРАДЫ / ГАРДЕРОБ
    local curTab = P11.BP.tab or "rewards"
    local function TabBtn(x, label, tab)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, 92) b:SetSize(170, 30) b:SetText("")
        b.Paint = function(s2, w2, h2)
            local on = curTab == tab
            draw.RoundedBox(6, 0, 0, w2, h2, on and BP_COL.gold or BP_COL.panel2)
            draw.SimpleText(label, "P11.BP.Small", w2 / 2, h2 / 2,
                on and Color(20, 22, 26) or BP_COL.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if curTab == tab then return end
            P11.BP.tab = tab
            f:Remove()
            P11.OpenBattlePass()
        end
    end
    TabBtn(20, "🎖 НАГРАДЫ", "rewards")
    TabBtn(200, "🎭 ГАРДЕРОБ (" .. #(data.models or {}) .. ")", "wardrobe")
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then f:Remove() P11.BP.frame = nil end
    end

    -- уровень + прогресс
    local lvlLbl = vgui.Create("DLabel", f)
    lvlLbl:SetPos(20, 96) lvlLbl:SetSize(400, 34)
    lvlLbl:SetFont("P11.BP.Huge") lvlLbl:SetTextColor(BP_COL.gold)
    lvlLbl:SetContentAlignment(4)
    lvlLbl:SetText("УРОВЕНЬ " .. (data.lvl or 1))

    local xpLbl = vgui.Create("DLabel", f)
    xpLbl:SetPos(420, 100) xpLbl:SetSize(320, 24)
    xpLbl:SetFont("P11.BP.Small") xpLbl:SetTextColor(BP_COL.dim)
    xpLbl:SetContentAlignment(6)
    xpLbl:SetText("XP: " .. (data.xp or 0))

    -- прогресс-бар
    local prog = vgui.Create("DPanel", f)
    prog:SetPos(20, 136) prog:SetSize(720, 22)
    prog.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(8, 10, 14, 255))
        local need = math.max(1, data.need or 100)
        local frac = math.Clamp((data.left or 0) / need, 0, 1)
        draw.RoundedBox(4, 0, 0, math.max(4, w * frac), h, BP_COL.gold)
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawRect(1, 1, math.max(2, w * frac) - 2, math.floor(h / 2) - 1)
        draw.SimpleText("до уровня " .. ((data.lvl or 1) + 1) .. ": " .. (data.left or 0) ..
            " / " .. need .. " XP", "P11.BP.Tiny", w / 2, h / 2,
            Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- список уровней (или гардероб)
    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(20, 172) sc:SetSize(720, 420)
    local bar = sc:GetVBar() bar:SetWide(5)
    bar.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 14)) end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, BP_COL.gold) end

    if curTab == "wardrobe" then
        -- ============ ГАРДЕРОБ: разблокированные модели ============
        local models = data.models or {}
        if #models == 0 then
            local l = sc:Add("DLabel")
            l:SetFont("P11.BP.Mid") l:SetTextColor(BP_COL.dim)
            l:SetText("  Гардероб пуст. Открывай уровни батл-пасса — модели дают наградами!")
            l:SizeToContents()
        end
        for _, m in ipairs(models) do
            local worn = (data.wardrobe or "") == m.path
            local row = sc:Add("DPanel")
            row:Dock(TOP) row:DockMargin(0, 0, 0, 6) row:SetTall(56)
            row.Paint = function(s, w, h)
                draw.RoundedBox(7, 0, 0, w, h, worn and Color(30, 40, 26, 255) or Color(20, 26, 36, 255))
                if worn then
                    surface.SetDrawColor(BP_COL.gold.r, BP_COL.gold.g, BP_COL.gold.b, 120)
                    surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
                draw.SimpleText("🎭", "P11.BP.Mid", 28, h / 2, BP_COL.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(m.name or "Модель", "P11.BP.Mid", 52, h / 2 - 8,
                    worn and BP_COL.gold or BP_COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(m.path or "", "P11.BP.Tiny", 52, h / 2 + 12,
                    BP_COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if worn then
                    draw.SimpleText("НАДЕТА", "P11.BP.Tiny", w - 16, h / 2,
                        BP_COL.ok, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            local b = vgui.Create("DButton", row)
            b:SetPos(720 - 8 - 110, 12) b:SetSize(110, 32) b:SetText("")
            b.Paint = function(s2, w2, h2)
                draw.RoundedBox(5, 0, 0, w2, h2, s2:IsHovered() and Color(255, 220, 130) or BP_COL.gold)
                draw.SimpleText(worn and "СНЯТЬ" or "НАДЕТЬ", "P11.BP.Small", w2 / 2, h2 / 2 - 1,
                    Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                surface.PlaySound("buttons/button15.wav")
                net.Start("P11_BP_Wear")
                    net.WriteString(worn and "" or m.path)
                net.SendToServer()
                timer.Simple(0.4, function()
                    if IsValid(f) then
                        local keep = P11.BP.data
                        f:Remove()
                        P11.BP.data = keep
                        P11.OpenBattlePass()
                    end
                end)
            end
        end
        -- подпись
        local hint = vgui.Create("DLabel", f)
        hint:SetPos(20, 600) hint:SetSize(720, 24)
        hint:SetFont("P11.BP.Tiny") hint:SetTextColor(BP_COL.dim) hint:SetContentAlignment(5)
        hint:SetText("Облик сохраняется после респавна · снимается маскировкой/тварью · модели дают уровни 6, 9, 12, 16, 19, 22, 25, 29, 30")
        return
    end

    local rewards = data.rewards or {}
    table.sort(rewards, function(a, b) return a.lvl < b.lvl end)

    for _, r in ipairs(rewards) do
        local unlocked = r.lvl <= (data.lvl or 1)
        local claimed = (data.claimed or {})[r.lvl] == true
        local row = sc:Add("DPanel")
        row:Dock(TOP) row:DockMargin(0, 0, 0, 6) row:SetTall(52)
        row.Paint = function(s, w, h)
            local base = claimed and Color(24, 30, 26, 255) or (unlocked and Color(30, 38, 30, 255) or Color(18, 22, 28, 255))
            draw.RoundedBox(7, 0, 0, w, h, base)
            if r.lvl == 20 then
                surface.SetDrawColor(BP_COL.gold.r, BP_COL.gold.g, BP_COL.gold.b, 90 + 60 * math.sin(CurTime() * 4))
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
            -- номер уровня
            draw.SimpleText(string.format("%02d", r.lvl), "P11.BP.Mid", 26, h / 2,
                unlocked and BP_COL.gold or BP_COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- статус
            local stTxt = claimed and "✓ ЗАБРАНО" or (unlocked and "ГОТОВО" or "🔒")
            draw.SimpleText(stTxt, "P11.BP.Tiny", 62, h / 2,
                claimed and BP_COL.ok or (unlocked and BP_COL.gold or BP_COL.dim),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- награда
            draw.SimpleText(r.name or "?", "P11.BP.Mid", 150, h / 2,
                claimed and BP_COL.dim or BP_COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if r.lvl == 20 then
                draw.SimpleText("ГЛАВНЫЙ ПРИЗ", "P11.BP.Tiny", 150, h / 2 + 14,
                    BP_COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        -- кнопка ЗАБРАТЬ
        if unlocked and not claimed then
            local b = vgui.Create("DButton", row)
            b:SetPos(720 - 8 - 120, 11) b:SetSize(120, 30) b:SetText("")
            b.Paint = function(s, w, h)
                draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(255, 220, 130) or BP_COL.gold)
                draw.SimpleText("ЗАБРАТЬ", "P11.BP.Small", w / 2, h / 2 - 1,
                    Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                surface.PlaySound("buttons/button15.wav")
                ClaimLvl(r.lvl)
            end
        end
    end

    -- подпись
    local hint = vgui.Create("DLabel", f)
    hint:SetPos(20, 600) hint:SetSize(720, 24)
    hint:SetFont("P11.BP.Tiny") hint:SetTextColor(BP_COL.dim) hint:SetContentAlignment(5)
    hint:SetText("XP капает за: тесты крови · крафт · лечение · контракты · переклички · урон Нечто · фраги (в операции ×3) · F5 — меню · p11_bpxp — выдача командованием")

    f.Refill = function()
        -- пересоздаём просто: закрыть и открыть заново с тем же состоянием
        if IsValid(f) then
            local keep = P11.BP.data
            f:Remove()
            P11.BP.data = keep
            P11.OpenBattlePass()
        end
    end
end

-- ============ ОТКРЫТИЕ: F5 ============

hook.Add("PlayerButtonDown", "P11.BPKey", function(ply, btn)
    if btn == KEY_F5 then
        P11.OpenBattlePass()
        return true
    end
end)

concommand.Add("p11_battlepass", function()
    P11.OpenBattlePass()
end)

hook.Add("PlayerSay", "P11.BPChat", function(ply, text)
    local t = string.lower(string.Trim(text))
    if t == "!батлпасс" or t == "/батлпасс" or t == "!bp" then
        P11.OpenBattlePass()
        return ""
    end
end)

print("[POLUS-11] БАТЛ-ПАСС (client) v5.2.0: меню F5 · 20 уровней · награды рейха · ЗАБРАТЬ по клику")
