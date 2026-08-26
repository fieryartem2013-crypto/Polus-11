-- ============================================================
--  ПОЛЮС-11 — НАРУЧНИКИ / КАРАУЛ (клиент) v4.22.0 «ОКОВЫ»
--   • красная плашка «ВЫ В НАРУЧНИКАХ» (NWBool P11_Cuffed)
--   • золотая строка конвоира «ВЕДЁТЕ: …» (NWString P11_CuffLead)
--   • окно начальника караула: 3/5/10 мин камеры или отпустить
-- ============================================================

surface.CreateFont("P11.Cuff.Big",   { font = "Roboto", size = 26, weight = 700, extended = true })
surface.CreateFont("P11.Cuff.Small", { font = "Roboto", size = 17, weight = 500, extended = true })

local JFrame -- файл-скоп: объявлен выше замыканий

-- ============ HUD ============

hook.Add("HUDPaint", "P11.CuffsHUD", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local w = ScrW()

    if lp:GetNWBool("P11_Cuffed") then
        local by = lp:GetNWString("P11_CuffBy", "")
        draw.RoundedBox(8, w / 2 - 300, 126, 600, 58, Color(120, 16, 16, 220))
        draw.SimpleText("■ ВЫ В НАРУЧНИКАХ", "P11.Cuff.Big", w / 2, 140,
            Color(255, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("снаряжение изъято, руки связаны — идёте за конвоиром"
                .. (by ~= "" and (": " .. by) or ""),
            "P11.Cuff.Small", w / 2, 168, Color(255, 190, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        return
    end

    local lead = lp:GetNWString("P11_CuffLead", "")
    if lead ~= "" then
        draw.RoundedBox(8, w / 2 - 290, 126, 580, 38, Color(20, 26, 36, 215))
        draw.SimpleText("► ВЕДЁТЕ: " .. lead .. "  —  к начальнику караула (E — оформить)",
            "P11.Cuff.Small", w / 2, 134, Color(255, 215, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

-- ============ ОКНО КАРАУЛА ============

net.Receive("P11_JailUI", function()
    local tar = net.ReadEntity()
    if not IsValid(tar) then return end
    if IsValid(JFrame) then JFrame:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(430, 300)
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:MakePopup()
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, Color(16, 18, 24, 245))
        draw.RoundedBoxEx(8, 0, 0, pw, 46, Color(120, 16, 16, 255), true, true, false, false)
        draw.SimpleText("■ НАЧАЛЬНИК КАРАУЛА — ОФОРМИТЬ АРЕСТ", "P11.Cuff.Small", 14, 14,
            Color(255, 230, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    JFrame = f

    local nik = vgui.Create("DLabel", f)
    nik:SetPos(18, 58) nik:SetSize(400, 24)
    nik:SetFont("P11.Cuff.Small") nik:SetTextColor(Color(235, 235, 240))
    nik:SetText("Задержанный: " .. tar:Nick())

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(18, 84) hint:SetSize(396, 38)
    hint:SetFont("P11.Cuff.Small") hint:SetTextColor(Color(170, 175, 190))
    hint:SetText("Срок камеры — на совесть конвоира. Оформление: опыт службы +25, запись в досье особого отдела.")
    hint:SetWrap(true) hint:SetAutoStretchVertical(true)

    local function SentBtn(y, txt, mins, col)
        local b = vgui.Create("DButton", f)
        b:SetPos(18, y) b:SetSize(394, 36)
        b:SetText("")
        b.Paint = function(_, pw, ph)
            local c = col
            if b:IsHovered() then c = Color(col.r + 30, col.g + 30, col.b + 30, 255) end
            draw.RoundedBox(6, 0, 0, pw, ph, c)
            draw.SimpleText(txt, "P11.Cuff.Small", pw / 2, ph / 2,
                Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            if not IsValid(tar) then f:Remove() return end
            net.Start("P11_JailAct")
                net.WriteEntity(tar)
                net.WriteUInt(mins, 4)
            net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
            f:Remove()
        end
    end

    SentBtn(126, "КАМЕРА — 3 МИНУТЫ",    3,  Color(120, 60, 30, 255))
    SentBtn(168, "КАМЕРА — 5 МИНУТ",     5,  Color(140, 40, 30, 255))
    SentBtn(210, "КАМЕРА — 10 МИНУТ",    10, Color(160, 25, 25, 255))
    SentBtn(252, "ОТПУСТИТЬ БЕЗ КАМЕРЫ", 0,  Color(60, 90, 60, 255))
end)
