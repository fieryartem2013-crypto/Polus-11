-- ============================================================
--  ПОЛЮС-11 — ДЕЖУРСТВА (client) v5.2.3
--  Меню поста (открывается с НПС «Дежурный главы» по E),
--  плашка «ДЕЖУРНЫЙ · <пост>» над ником (nametags) и в TAB.
-- ============================================================

P11 = P11 or {}

surface.CreateFont("P11.Duty.Big",   { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("P11.Duty.Mid",   { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("P11.Duty.Tx",    { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("P11.Duty.Small", { font = "Roboto", size = 12, weight = 500, extended = true })

P11.DutyLocs = P11.DutyLocs or {}

function P11.DutyName(id)
    local l = P11.DutyLocs[id]
    return (l and l.name) or tostring(id)
end

function P11.DutyOpenMenu()
    local me = LocalPlayer()
    if not IsValid(me) then return end

    if IsValid(P11.DutyFrame) then P11.DutyFrame:Remove() end

    local f = vgui.Create("DFrame")
    P11.DutyFrame = f
    f:SetSize(520, 470)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:SetDeleteOnClose(true)
    f.btnClose:SetVisible(false) f.btnMaxim:SetVisible(false) f.btnMinim:SetVisible(false)
    f.T0 = SysTime()
    f.Paint = function(s, w, h)
        Derma_DrawBackgroundBlur(s, s.T0)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 16, 22, 248))
        draw.RoundedBoxEx(10, 0, 0, w, 58, Color(30, 36, 46, 255), true, true, false, false)
        surface.SetDrawColor(255, 205, 100)
        surface.DrawRect(0, 58, w, 2)
        draw.SimpleText("🛡 ДЕЖУРСТВО — ПОСТ СТАНЦИИ", "P11.Duty.Big", 16, 12, Color(255, 205, 100))
        draw.SimpleText("выбери локацию поста · оклад за минуту · смерть снимает пост", "P11.Duty.Tx", 16, 38, Color(150, 158, 172))
    end
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE then s:Remove() end
    end

    local x = vgui.Create("DButton", f)
    x:SetPos(520 - 38, 12) x:SetSize(26, 26) x:SetText("✕")
    x:SetFont("P11.Duty.Mid") x:SetTextColor(Color(150, 158, 172))
    x.Paint = function() end
    x.DoClick = function() f:Remove() end

    -- текущий статус
    local cur = me:GetNWString("P11_DutyLoc", "")

    local st = vgui.Create("DPanel", f)
    st:SetPos(12, 70) st:SetSize(496, 52)
    st.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 70))
        draw.SimpleText("СЕЙЧАС:  " .. (cur ~= "" and ("🛡 " .. P11.DutyName(cur)) or "не на посту"),
            "P11.Duty.Mid", 14, h / 2,
            cur ~= "" and Color(255, 205, 100) or Color(150, 158, 172),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local sc = vgui.Create("DScrollPanel", f)
    sc:SetPos(12, 132) sc:SetSize(496, 252)

    local order = { "kpp2", "kpparr", "pov", "complex" }
    for _, id in ipairs(order) do
        local l = P11.DutyLocs[id]
        if l then
            local pnl = sc:Add("DPanel")
            pnl:Dock(TOP) pnl:DockMargin(0, 0, 0, 8) pnl:SetTall(56)
            pnl.Paint = function(s, w, h)
                local on = (cur == id)
                draw.RoundedBox(6, 0, 0, w, h, on and Color(255, 205, 100, 26) or Color(255, 255, 255, 8))
                if on then
                    surface.SetDrawColor(255, 205, 100, 180)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end
                draw.SimpleText(l.name, "P11.Duty.Mid", 14, 14, on and Color(255, 205, 100) or Color(232, 238, 245))
                draw.SimpleText(l.desc or "", "P11.Duty.Small", 14, 36, Color(150, 158, 172))
            end
            local b = vgui.Create("DButton", pnl)
            b:SetPos(496 - 8 - 100, 14) b:SetSize(96, 28) b:SetText("")
            b.Paint = function(s, w, h)
                local on = (cur == id)
                draw.RoundedBox(5, 0, 0, w, h,
                    on and Color(90, 70, 30, 220)
                    or (s:IsHovered() and Color(255, 205, 100, 235) or Color(150, 120, 55, 220)))
                draw.SimpleText(on and "НА ПОСТУ" or "ЗАСТУПИТЬ", "P11.Duty.Tx", w / 2, h / 2 - 1,
                    on and Color(255, 205, 100) or Color(20, 22, 26), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                if cur == id then return end
                net.Start("P11_DutyAct")
                    net.WriteUInt(1, 2)
                    net.WriteString(id)
                net.SendToServer()
                surface.PlaySound("buttons/button15.wav")
                f:Remove()
            end
        end
    end

    -- снять пост
    local endBtn = vgui.Create("DButton", f)
    endBtn:SetPos(12, 396) endBtn:SetSize(496, 42) endBtn:SetText("")
    endBtn.Paint = function(s, w, h)
        local on = (cur ~= "")
        draw.RoundedBox(6, 0, 0, w, h,
            on and (s:IsHovered() and Color(240, 100, 90, 225) or Color(140, 60, 50, 220))
            or Color(60, 64, 72, 200))
        draw.SimpleText(on and "СНЯТЬ ДЕЖУРСТВО" or "ВЫ НЕ НА ПОСТУ", "P11.Duty.Tx", w / 2, h / 2 - 1,
            on and Color(242, 242, 246) or Color(120, 126, 138), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    endBtn.DoClick = function()
        if cur == "" then return end
        net.Start("P11_DutyAct")
            net.WriteUInt(2, 2)
        net.SendToServer()
        surface.PlaySound("buttons/button10.wav")
        f:Remove()
    end
end

net.Receive("P11_DutyOpen", function()
    local ok, tbl = pcall(net.ReadTable)
    if ok and istable(tbl) then
        P11.DutyLocs = tbl
    end
    P11.DutyOpenMenu()
end)

print("[POLUS-11] ДЕЖУРСТВА (client): меню поста, плашка над ником, TAB")
