-- ============================================================
--  ПОЛЮС-11 — ОПЕРАЦИИ «РУБЕЖ» (клиент) v4.24.0
--   • зов «выбери сторону» (СССР/АМЕРИКА) при старте операции
--   • полоска-статус сверху: фаза, таймер, точки, серия удержания
--   • вкладка ОПЕРАЦИИ (кнопка в C-меню): статус + админ-старт/стоп
--   • лидерборд финала: победитель, удержание, фраги, топ бойцов
-- ============================================================

surface.CreateFont("P11.Op.Big",   { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("P11.Op.Mid",   { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("P11.Op.Small", { font = "Roboto", size = 14, weight = 500, extended = true })

local OP_RED  = Color(215, 90, 80)
local OP_BLUE = Color(100, 160, 240)
local OP_GOLD = Color(255, 205, 100)
local OP_DIM  = Color(160, 168, 180)
local OP_BG   = Color(12, 16, 22, 245)
local OP_PANE = Color(26, 32, 42, 255)

local PickFrame, BoardFrame, OpsFrame

local function OpState()
    local raw = GetGlobalString("P11_Op", "")
    if raw == "" then return { phase = "idle" } end
    local t = string.Explode("|", raw)
    return {
        phase = t[1] or "idle",
        left  = tonumber(t[2]) or 0,
        holdA = tonumber(t[3]) or 0,
        holdB = tonumber(t[4]) or 0,
        ownA  = tonumber(t[5]) or 0,
        ownB  = tonumber(t[6]) or 0,
        pts   = tonumber(t[7]) or 0,
    }
end

local function FmtTime(sec)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- ============ HUD-полоса ============

hook.Add("HUDPaint", "P11.OpHUD", function()
    local st = OpState()
    if st.phase == "idle" then return end
    local w = ScrW()
    local mine = LocalPlayer():GetNWString("P11_OpSide", "")

    if st.phase == "recruit" then
        draw.RoundedBox(8, w / 2 - 270, 92, 540, 36, Color(90, 60, 16, 220))
        draw.SimpleText("⚔ ОПЕРАЦИЯ «РУБЕЖ»: запись сторон " .. FmtTime(st.left) ..
            (mine ~= "" and ("  —  ты за «" .. (mine == "rkka" and "СССР" or "АМЕРИКА") .. "»") or ""),
            "P11.Op.Small", w / 2, 100, OP_GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        return
    end

    if st.phase == "battle" then
        draw.RoundedBox(8, w / 2 - 380, 92, 760, 40, Color(14, 18, 26, 225))
        local ca = (mine == "rkka") and OP_GOLD or OP_RED
        local cb = (mine == "eagle") and OP_GOLD or OP_BLUE
        draw.SimpleText("СССР  " .. (st.ownA or 0) .. "/" .. (st.pts or 0) .. "  •  серия " ..
            FmtTime(st.holdA or 0), "P11.Op.Mid", w / 2 - 360, 100, ca, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("до конца  " .. FmtTime(st.left), "P11.Op.Mid", w / 2, 100,
            Color(235, 238, 242), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("серия " .. FmtTime(st.holdB or 0) .. "  •  " .. (st.ownB or 0) ..
            "/" .. (st.pts or 0) .. "  США", "P11.Op.Mid", w / 2 + 360, 100, cb, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        return
    end

    if st.phase == "end" then
        draw.RoundedBox(8, w / 2 - 240, 92, 480, 34, Color(16, 40, 24, 220))
        draw.SimpleText("⚔ ОПЕРАЦИЯ ЗАВЕРШЕНА — лидерборд на экране",
            "P11.Op.Mid", w / 2, 100, Color(150, 230, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

-- ============ ЗОВ: ВЫБОР СТОРОНЫ ============

local function OpenPick()
    if IsValid(PickFrame) then PickFrame:Remove() end
    local f = vgui.Create("DFrame")
    f:SetSize(440, 250)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, pw, ph, OP_BG)
        draw.RoundedBoxEx(10, 0, 0, pw, 52, Color(74, 40, 18, 255), true, true, false, false)
        draw.SimpleText("⚔ ОПЕРАЦИЯ «РУБЕЖ» — ВЫБЕРИ СТОРОНУ", "P11.Op.Mid", pw / 2, 14,
            OP_GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then f:Remove() end end
    PickFrame = f

    local info = vgui.Create("DLabel", f)
    info:SetPos(20, 62) info:SetSize(400, 40)
    info:SetFont("P11.Op.Small") info:SetTextColor(OP_DIM)
    info:SetText("Вахты сброшены командованием. Выбранная сторона выдаёт тебе солдата автоматически — бой за точки, 30 минут.")
    info:SetWrap(true) info:SetAutoStretchVertical(true)

    local function SideBtn(x, txt, col, fac)
        local b = vgui.Create("DButton", f)
        b:SetPos(x, 118) b:SetSize(196, 92) b:SetText("")
        b.Paint = function(s, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, s:IsHovered() and
                Color(col.r + 28, col.g + 28, col.b + 28, 255) or col)
            draw.SimpleText(txt, "P11.Op.Big", pw / 2, 22, Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText("солдат " .. txt, "P11.Op.Small", pw / 2, 56, Color(28, 30, 36),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
        b.DoClick = function()
            net.Start("P11_OpPick")
                net.WriteString(fac)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            f:Remove()
        end
    end
    SideBtn(20,  "СССР",    Color(200, 80, 70),  "rkka")
    SideBtn(224, "АМЕРИКА", Color(90, 150, 230), "eagle")
end

net.Receive("P11_OpUI", function()
    local msg = net.ReadString() or ""
    if msg == "call" then
        OpenPick()
    elseif msg == "battle" then
        if IsValid(PickFrame) then PickFrame:Remove() end
    elseif string.sub(msg, 1, 7) == "joined|" then
        if IsValid(PickFrame) then PickFrame:Remove() end
    end
end)

-- ============ ЛИДЕРБОРД ============

net.Receive("P11_OpBoard", function()
    local ok, b = pcall(util.JSONToTable, net.ReadString() or "{}")
    if not ok or not istable(b) then return end
    if IsValid(BoardFrame) then BoardFrame:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(520, 430)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, pw, ph, OP_BG)
        draw.RoundedBoxEx(10, 0, 0, pw, 60, Color(22, 50, 30, 255), true, true, false, false)
        draw.SimpleText("⚔ ЛИДЕРБОРД ОПЕРАЦИИ", "P11.Op.Big", pw / 2, 8, OP_GOLD, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(tostring(b.wname or ""), "P11.Op.Mid", pw / 2, 36,
            Color(170, 235, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
    BoardFrame = f
    timer.Simple(25, function() if IsValid(f) then f:Remove() end end)

    local function Row(y, left, right, col)
        local l = vgui.Create("DLabel", f)
        l:SetPos(24, y) l:SetSize(300, 20) l:SetFont("P11.Op.Mid")
        l:SetTextColor(col or Color(230, 234, 240)) l:SetText(left)
        local r = vgui.Create("DLabel", f)
        r:SetPos(24, y) r:SetSize(472, 20) r:SetFont("P11.Op.Mid")
        r:SetTextColor(col or Color(230, 234, 240)) r:SetText(right)
        r:SetContentAlignment(6)
    end
    Row(76, "Удержание ВСЕХ точек",
        "СССР " .. FmtTime(b.holdA or 0) .. "   ·   США " .. FmtTime(b.holdB or 0))
    Row(100, "Фраги сторон",
        "СССР " .. (b.killsA or 0) .. "   ·   США " .. (b.killsB or 0))
    Row(124, "Выплаты участникам",
        "+" .. (b.winPay or 5000) .. "₽ победам  ·  +" .. (b.losePay or 1000) .. "₽ остальным", OP_GOLD)

    local hd = vgui.Create("DLabel", f)
    hd:SetPos(24, 156) hd:SetSize(400, 22)
    hd:SetFont("P11.Op.Mid") hd:SetTextColor(Color(150, 200, 255))
    hd:SetText("ТОП БОЙЦОВ ПО ФРАГАМ")

    local y = 184
    for i, rec in ipairs(b.top or {}) do
        local nm = tostring(rec.name or "?")
        local fac = (rec.fac == "eagle") and "США" or "СССР"
        local col = (rec.fac == "eagle") and OP_BLUE or OP_RED
        local ln = vgui.Create("DLabel", f)
        ln:SetPos(24, y) ln:SetSize(472, 19)
        ln:SetFont("P11.Op.Small") ln:SetTextColor(Color(225, 228, 234))
        ln:SetText(i .. ". " .. nm)
        local sc = vgui.Create("DLabel", f)
        sc:SetPos(24, y) sc:SetSize(472, 19)
        sc:SetFont("P11.Op.Small") sc:SetTextColor(col)
        sc:SetText(fac .. " · " .. (rec.k or 0) .. " фр.")
        sc:SetContentAlignment(6)
        y = y + 20
        if i >= 8 then break end
    end
    if #(b.top or {}) == 0 then
        local no = vgui.Create("DLabel", f)
        no:SetPos(24, y) no:SetSize(472, 19)
        no:SetFont("P11.Op.Small") no:SetTextColor(OP_DIM)
        no:SetText("Без крови — точки дрались на нервах.")
    end
end)

-- ============ ВКЛАДКА ОПЕРАЦИИ (из C-меню) ============

function P11.OpenOps()
    if IsValid(OpsFrame) then OpsFrame:Remove() end
    local st = OpState()

    local f = vgui.Create("DFrame")
    f:SetSize(470, 320)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.T0 = SysTime()
    OpsFrame = f
    f.Paint = function(s, pw, ph)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, pw, ph, OP_BG)
        draw.RoundedBoxEx(10, 0, 0, pw, 50, OP_PANE, true, true, false, false)
        draw.SimpleText("⚔ ОПЕРАЦИИ", "P11.Op.Big", 18, 10, OP_GOLD)
    end
    f.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then f:Remove() end end

    local st2 = vgui.Create("DLabel", f)
    st2:SetPos(20, 64) st2:SetSize(430, 60)
    st2:SetFont("P11.Op.Small") st2:SetTextColor(Color(225, 228, 234))
    local txt = "Сейчас тихо. Командование (ранг 4+) может объявить операцию: сброс вахт, выбор стороны, " ..
        "случайные точки захвата, бой 30 минут. Удержать ВСЕ точки 5 минут — досрочная победа. " ..
        "Награды: 5000₽ победителям, 1000₽ остальным."
    if st.phase == "recruit" then
        txt = "ИДЁТ ЗАПИСЬ СТОРОН: осталось " .. FmtTime(st.left) .. ". Окно выбора уже у всех на экране!"
    elseif st.phase == "battle" then
        txt = "БОЙ! СССР " .. (st.ownA or 0) .. "/" .. (st.pts or 0) .. " (серия " .. FmtTime(st.holdA or 0) ..
            ") — США " .. (st.ownB or 0) .. "/" .. (st.pts or 0) .. " (серия " .. FmtTime(st.holdB or 0) ..
            "). До конца " .. FmtTime(st.left) .. "."
    elseif st.phase == "end" then
        txt = "Финал: лидерборд на экранах участников, выплаты ушли."
    end
    st2:SetText(txt)
    st2:SetWrap(true) st2:SetAutoStretchVertical(true)

    local yb = 200
    if P11FW.Config.Admin(LocalPlayer()) then
        local function AdmBtn(y, txt, col, msg)
            local b = vgui.Create("DButton", f)
            b:SetPos(20, y) b:SetSize(430, 40) b:SetText("")
            b.Paint = function(s, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, s:IsHovered() and
                    Color(col.r + 25, col.g + 25, col.b + 25, 255) or col)
                draw.SimpleText(txt, "P11.Op.Mid", pw / 2, ph / 2, Color(240, 240, 245),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                net.Start("P11_OpPick")
                    net.WriteString(msg)
                net.SendToServer()
                surface.PlaySound("buttons/button15.wav")
                f:Remove()
            end
        end
        if st.phase == "idle" then
            AdmBtn(yb, "▲ ОБЪЯВИТЬ ОПЕРАЦИЮ (станция услышит)", Color(140, 90, 30, 255), "adm_start")
        else
            AdmBtn(yb, "✕ ЗАВЕРШИТЬ/ОТМЕНИТЬ ОПЕРАЦИЮ", Color(120, 30, 26, 255), "adm_stop")
        end
    end

    if (st.phase == "recruit" or st.phase == "battle")
        and LocalPlayer():GetNWString("P11_OpSide", "") == "" then
        local jb = vgui.Create("DButton", f)
        jb:SetPos(20, yb + 48) jb:SetSize(430, 36) jb:SetText("")
        jb.Paint = function(s, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, s:IsHovered() and Color(60, 90, 50, 255) or Color(40, 62, 34, 255))
            draw.SimpleText("ВСТУПИТЬ В ОПЕРАЦИЮ (выбрать сторону)", "P11.Op.Mid", pw / 2, ph / 2,
                Color(190, 240, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        jb.DoClick = function()
            f:Remove()
            OpenPick()
        end
    end
end

-- ============ МАЯКИ ТОЧЕК (v4.24.1 «МАЯК»): где лежат точки боя ============

hook.Add("HUDPaint", "P11.OpBeacons", function()
    local st = OpState()
    if st.phase ~= "battle" then return end
    local me = LocalPlayer()
    if not IsValid(me) then return end
    for _, e in ipairs(ents.FindByClass("polus11_cappoint")) do
        if IsValid(e) and e:GetNWBool("P11_OpPoint", false) then
            local scr = (e:GetPos() + Vector(0, 0, 110)):ToScreen()
            if scr.visible then
                local ow = e.GetOwnerFact and e:GetOwnerFact() or ""
                local col = (ow == "rkka") and OP_RED or (ow == "eagle") and OP_BLUE
                    or Color(160, 168, 180)
                local nm = e.GetPointName and e:GetPointName() or "?"
                local d = math.floor(me:GetPos():Distance(e:GetPos()))
                draw.SimpleTextOutlined("▼", "P11.Op.Big", scr.x, scr.y - 26, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
                draw.SimpleTextOutlined(nm .. " · " .. d .. " юн", "P11.Op.Small",
                    scr.x, scr.y + 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                    1, Color(0, 0, 0, 220))
            end
        end
    end
end)

print("[POLUS-11] ОПЕРАЦИИ «РУБЕЖ» (client) v4.24.1 «МАЯК»: зов сторон, HUD-бой, лидерборд, маяки точек")
