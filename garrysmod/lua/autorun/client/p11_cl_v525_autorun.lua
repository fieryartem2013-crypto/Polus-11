-- ============================================================
--  ПОЛЮС-11 — КЛИЕНТСКИЙ ПАТЧ v5.2.5 (НОВЫЙ ФАЙЛ, autorun/client)
--  Правило владельца: старые файлы НЕ редактируются — всё новое
--  отдельными файлами. Файлы в lua/autorun/client/*.lua грузятся
--  на клиенте АВТОМАТИЧЕСКИ после гейммода. Содержит:
--    1) МЕДАЛИ ВЫРЕЗАНЫ (заглушки отрисовки/вкладки)
--    2) ДЕЖУРСТВА: меню поста + плашка «🛡 ДЕЖУРНЫЙ · пост» над головой
--    3) ФИКС АДМИНКИ: DLabel:SetAutoWrapVertical (метод движка)
--    4) ФИКС F6: донат-меню не закрывается тем же нажатием
--    5) Версия сборки
-- ============================================================

POLUS_BUILD = "5.2.5"

-- ============ 1) МЕДАЛИ ВЫРЕЗАНЫ (клиент) ============

P11 = P11 or {}
P11.Medals = P11.Medals or { defs = {}, list = {} }

P11.MedalIds        = function() return {} end
P11.MedalGlyphs     = function() return "", 0 end
P11.MedalColorOf    = function() return Color(150, 158, 172) end
P11.MedalCells      = function() return {}, 0 end
P11.MedalTop        = function() return {} end
P11.MedalScopeLocal = function() return nil end
P11.MedalAwardMenu  = function()
    chat.AddText(Color(255, 205, 100), "[ПОЧЁТ] ", Color(232, 238, 245), "Медали отключены (v5.2.5).")
end
P11FW.MedalsTabBuild = function(p)
    local l = vgui.Create("DLabel", p)
    l:SetPos(20, 30) l:SetSize(700, 60)
    l:SetFont("P11FW.Text")
    l:SetTextColor(Color(150, 158, 172))
    l:SetText("Медали отключены владельцем (v5.2.5).\nСистема наград убрана из сборки.")
end

-- ============ 2) ДЕЖУРСТВА (клиент) ============

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

-- плашка «🛡 ДЕЖУРНЫЙ · пост» НАД ГОЛОВОЙ (отдельный HUD-слой)
hook.Add("HUDPaint", "P11.DutyTag", function()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= me and IsValid(ply) and ply:Alive() then
            local dutyId = ply:GetNWString("P11_DutyLoc", "")
            if dutyId ~= "" then
                local dist = me:GetPos():DistToSqr(ply:GetPos())
                if dist < 450 * 450 then
                    local pos = (ply:EyePos() + Vector(0, 0, 14)):ToScreen()
                    if pos.visible then
                        local frac = 1 - (math.sqrt(dist) / 450)
                        local a = math.Clamp(frac * 255, 40, 255)
                        draw.SimpleTextOutlined("🛡 ДЕЖУРНЫЙ · " .. P11.DutyName(dutyId), "P11.HUD.Text",
                            pos.x, pos.y - 74, Color(255, 205, 100, a),
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, a * 0.8))
                    end
                end
            end
        end
    end
end)

-- ============ 3) ФИКС АДМИНКИ ============
-- Старый fw_cl_admin.lua зовёт DLabel:SetAutoWrapVertical (нет в движке).
-- Доопределяем метод на классе БЕЗ правки файла.

if DLabel then
    DLabel.SetAutoWrapVertical = DLabel.SetAutoWrapVertical or function(self, b)
        if self.SetWrap then self:SetWrap(b) end
        if self.SetAutoStretchVertical then self:SetAutoStretchVertical(b) end
    end
end

-- ============ 4) ФИКС F6 (донат-меню) ============
-- Окно открывается по F6, но закрывалось ТЕМ ЖЕ нажатием. Хук позже
-- оригинала подменяет закрытие окна на «только ESC».

hook.Add("PlayerButtonDown", "P11.DonateFixF6", function(ply, btn)
    if btn ~= KEY_F6 or ply ~= LocalPlayer() then return end
    local f = P11D and P11D.Frame
    if IsValid(f) then
        f.OnKeyCodePressed = function(s, key)
            if key == KEY_ESCAPE then s:Remove() end
        end
    end
end)

print("[POLUS-11] v5.2.5 autorun/client: медали вырезаны · дежурства (меню+плашка) · фиксы админки и F6")
