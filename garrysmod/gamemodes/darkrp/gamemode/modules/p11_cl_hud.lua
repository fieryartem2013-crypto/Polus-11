-- ============================================================
--  ПОЛЮС-11 — клиент: тьма, улей, окна теста крови
-- ============================================================

surface.CreateFont("P11.HUD.Big",   {font = "Roboto", size = 40, weight = 800, extended = true})
surface.CreateFont("P11.HUD.Mid",   {font = "Roboto", size = 24, weight = 700, extended = true})
surface.CreateFont("P11.HUD.Text",  {font = "Roboto", size = 18, weight = 500, extended = true})
-- шрифты для 3D2D табличек энтити (дубли на всякий случай)
surface.CreateFont("P11.Gen.Big",   {font = "Roboto", size = 44, weight = 700, extended = true})
surface.CreateFont("P11.Gen.Small", {font = "Roboto", size = 30, weight = 500, extended = true})

-- ============ СПИСОК УЛЬЯ (заражённый видит своих) ============

local HIVE = {} -- [entindex] = true

net.Receive("P11_HiveSync", function()
    HIVE = {}
    local n = net.ReadUInt(8)
    for i = 1, n do
        local e = net.ReadEntity()
        if IsValid(e) then HIVE[e] = true end
    end
end)

-- моё состояние (определяется по NW "на себе" — сервер пишет только нам)
local function AmInfected()
    return LocalPlayer():GetNWBool("P11_Infected", false)
end

-- ============ ТЬМА (блэкаут) ============

hook.Add("RenderScreenspaceEffects", "P11_Darkness", function()
    if not GetGlobalBool("P11_Blackout", false) then return end

    local pulse = 0.12 + math.abs(math.sin(CurTime() * 0.8)) * 0.08

    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.28 - pulse,
        ["$pp_colour_contrast"] = 0.92,
        ["$pp_colour_colour"]   = 0.42,
        ["$pp_colour_mulr"]     = 0.12,
        ["$pp_colour_mulg"]     = 0.10,
        ["$pp_colour_mulb"]     = 0.16,
    })
end)

-- лёгкое мерцание фразы аварии
hook.Add("HUDPaint", "P11_BlackoutWarn", function()
    if not GetGlobalBool("P11_Blackout", false) then return end
    if (CurTime() % 3) > 2.2 then return end

    local w, h = ScrW(), ScrH()
    local a = 220
    draw.RoundedBox(6, w / 2 - 300, 82, 600, 36, Color(30, 8, 6, 200))
    surface.SetDrawColor(255, 90, 80, 60)
    surface.DrawOutlinedRect(w / 2 - 300, 82, 600, 36, 1)
    draw.SimpleText("★ АВАРИЯ ЭНЕРГОСИСТЕМЫ — НЕТ ПИТАНИЯ ★", "P11.HUD.Mid", w / 2, 100, Color(255, 90, 80, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- фаза смены под часами конца экрана
hook.Add("HUDPaint", "P11_PhaseLine", function()
    local w = ScrW()
    local phase = GetGlobalString("P11_Phase", "")
    if phase == "" then return end
    surface.SetFont("P11.HUD.Text")
    local tw = surface.GetTextSize("Фаза: " .. phase)
    draw.RoundedBox(4, w - 18 - tw - 14, 10, tw + 14, 24, Color(10, 13, 18, 170))
    surface.SetDrawColor(255, 205, 100, 60)
    surface.DrawOutlinedRect(w - 18 - tw - 14, 10, tw + 14, 24, 1)
    draw.SimpleText("Фаза: " .. phase, "P11.HUD.Text", w - 18, 12, Color(200, 210, 230, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end)

-- ============ УЛЕЙ: иконки над заражёнными ============

hook.Add("HUDPaint", "P11_Hive", function()
    if not AmInfected() then return end

    local me = LocalPlayer()
    for ent, _ in pairs(HIVE) do
        if IsValid(ent) and ent:Alive() and ent ~= me then
            local pos = (ent:EyePos() + Vector(0, 0, 14)):ToScreen()
            if pos.visible then
                draw.SimpleText("НЕЧТО", "P11.HUD.Text", pos.x, pos.y, Color(255, 70, 70, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end
end)

-- ============ ПОДМЕНА НИКА В ЧАТЕ ============
-- v4.2.1: хук переехал в p11_cl_board.lua («P11.BoardChat») —
-- там цвет от УКРАДЕННОЙ должности и защита от nil-цвета команды
-- (старая версия могла сыпать ошибкой на каждое сообщение нечто).

-- ============ FX АКТИВАЦИИ НЕЧТО (лично мне) ============

local FX_UNTIL = 0
net.Receive("P11_InfectFX", function()
    FX_UNTIL = CurTime() + 6
    surface.PlaySound("npc/zombie_poison/pz_alert1.wav")
end)

hook.Add("HUDPaint", "P11_InfectFX", function()
    if CurTime() > FX_UNTIL then return end
    local a = (FX_UNTIL - CurTime()) / 6
    local w, h = ScrW(), ScrH()

    -- тянущие красные жилы по краям
    surface.SetDrawColor(140, 20, 20, 160 * a)
    surface.DrawRect(0, 0, w, 60)
    surface.DrawRect(0, h - 60, w, 60)
    surface.DrawRect(0, 0, 60, h)
    surface.DrawRect(w - 60, 0, 60, h)

    draw.SimpleText("ЧТО-ТО ВНУТРИ ПРОСНУЛОСЬ", "P11.HUD.Big", w / 2, h * 0.35, Color(255, 60, 60, 230 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ============ БЛЭКАУТ FX ============

net.Receive("P11_BlackoutFX", function()
    local on = net.ReadBool()
    if on then
        surface.PlaySound("ambient/energy/spark5.wav")
        surface.PlaySound("ambient/energy/zap7.wav")
    else
        surface.PlaySound("buttons/lever" .. math.random(1, 5) .. ".wav")
    end
end)

-- ============ ОКНО ПОДМЕНЫ РЕЗУЛЬТАТА (только для заражённого учёного) ============

net.Receive("P11_FalsifyAsk", function()
    local donor = net.ReadString()

    local frame = vgui.Create("DFrame")
    frame:SetSize(440, 180)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 20, 24, 250))
        draw.RoundedBox(8, 0, 0, w, 48, Color(20, 12, 16, 255))
        draw.SimpleText("Тест крови: " .. donor, "P11.HUD.Mid", 14, 11, Color(255, 120, 120))
    end

    local lab = vgui.Create("DLabel", frame)
    lab:SetText("ТЫ — НЕЧТО. Можешь ПОДМЕНИТЬ результат теста:")
    lab:SetFont("P11.HUD.Text")
    lab:SetTextColor(Color(230, 225, 230))
    lab:SetPos(14, 58)
    lab:SizeToContents()

    local yes = vgui.Create("DButton", frame)
    yes:SetPos(14, 100)
    yes:SetSize(200, 56)
    yes:SetText("")
    yes.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(240, 90, 90) or Color(200, 60, 60))
        draw.SimpleText("ПОДМЕНИТЬ", "P11.HUD.Mid", w / 2, h / 2 - 10, Color(20, 14, 16), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("(тест покажет ложь)", "P11.HUD.Text", w / 2, h / 2 + 16, Color(60, 30, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    yes.DoClick = function()
        net.Start("P11_FalsifySet") net.WriteBool(true) net.SendToServer()
        frame:Close()
    end

    local no = vgui.Create("DButton", frame)
    no:SetPos(226, 100)
    no:SetSize(200, 56)
    no:SetText("")
    no.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(110, 120, 140) or Color(70, 76, 90))
        draw.SimpleText("ПОКАЗАТЬ ПРАВДУ", "P11.HUD.Mid", w / 2, h / 2, Color(230, 230, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    no.DoClick = function()
        net.Start("P11_FalsifySet") net.WriteBool(false) net.SendToServer()
        frame:Close()
    end
end)

-- ============ РЕЗУЛЬТАТ ТЕСТА КРОВИ (только тестирующему) ============

local RESULT = nil

net.Receive("P11_TestResult", function()
    local thing = net.ReadBool()
    local donor = net.ReadString()
    local falsified = net.ReadBool()

    RESULT = {thing = thing, donor = donor, endsAt = CurTime() + 8, falsified = falsified}

    if thing then
        surface.PlaySound("npc/zombie_poison/pz_alert2.wav")
    else
        surface.PlaySound("buttons/lever7.wav")
    end
end)

hook.Add("HUDPaint", "P11_TestResult", function()
    if not RESULT or CurTime() > RESULT.endsAt then return end

    local w, h = ScrW(), ScrH()
    local alpha = math.Clamp((RESULT.endsAt - CurTime()) / 2, 0, 1) * 255

    if RESULT.thing then
        draw.RoundedBox(8, w / 2 - 260, h * 0.68, 520, 90, Color(30, 10, 10, alpha * 0.9))
        draw.SimpleText("КРОВЬ: " .. RESULT.donor, "P11.HUD.Mid", w / 2, h * 0.68 + 12, Color(255, 140, 140, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("ЭТО НЕЧТО!!!", "P11.HUD.Big", w / 2, h * 0.68 + 38, Color(255, 50, 50, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    else
        draw.RoundedBox(8, w / 2 - 260, h * 0.68, 520, 80, Color(10, 25, 12, alpha * 0.9))
        draw.SimpleText("Кровь: " .. RESULT.donor, "P11.HUD.Mid", w / 2, h * 0.68 + 10, Color(170, 230, 170, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("человек, чист", "P11.HUD.Text", w / 2, h * 0.68 + 42, Color(120, 210, 120, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    if RESULT.falsified then
        draw.SimpleText("(вы подменили результат)", "P11.HUD.Text", w / 2, h * 0.68 + 92, Color(200, 170, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)
