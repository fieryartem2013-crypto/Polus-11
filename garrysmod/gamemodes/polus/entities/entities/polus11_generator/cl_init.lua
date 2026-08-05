include("shared.lua")

surface.CreateFont("P11.Gen.Big",   {font = "Roboto", size = 44, weight = 700, extended = true})
surface.CreateFont("P11.Gen.Small", {font = "Roboto", size = 30, weight = 500, extended = true})
surface.CreateFont("P11.Gen.Tiny",  {font = "Roboto", size = 22, weight = 500, extended = true})

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

    local fuel = math.floor(self:GetFuel())
    local wear = math.floor(self:GetWear())
    local maxf = POLUS11.Config.GeneratorMaxFuel
    local frac = math.Clamp(fuel / maxf, 0, 1)
    local fault = self:GetFault()
    local reserve = self:GetReserve()

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)
    local pos = self:GetPos() + Vector(0, 0, 90)

    cam.Start3D2D(pos, ang, 0.2)
        -- фон
        draw.RoundedBox(6, -180, -86, 360, 152, Color(0, 0, 0, 175))

        local status, col
        if self:GetDamaged() then
            status = "АВАРИЯ! ТРЕБУЕТ РЕМОНТА"
            col = Color(255, 70, 70)
        elseif fault ~= "" then
            local f = POLUS11_GEN_FAULTS[fault]
            local blink = (CurTime() % 0.8) < 0.45
            status = blink and ("ПОЛОМКА: " .. (f and f.name or fault)) or " "
            col = Color(255, 150, 60)
        elseif fuel <= 0 then
            status = "НЕТ ТОПЛИВА"
            col = Color(255, 130, 60)
        elseif fuel <= POLUS11.Config.FlickerAt then
            status = "ТОПЛИВО НА ИСХОДЕ"
            col = Color(255, 210, 80)
        else
            status = reserve and "РЕЗЕРВ · ГОТОВ К АВАРИИ" or "ГЕНЕРАТОР РАБОТАЕТ"
            col = reserve and Color(140, 190, 255) or Color(120, 220, 120)
        end

        draw.SimpleText(status, "P11.Gen.Big", 0, -80, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- полоса топлива
        draw.RoundedBox(4, -160, -28, 320, 22, Color(40, 40, 46, 220))
        draw.RoundedBox(4, -160, -28, 320 * frac, 22, frac > 0.25 and Color(90, 180, 90) or Color(220, 90, 60))
        draw.SimpleText("ТОПЛИВО " .. fuel .. " сек", "P11.Gen.Tiny", 0, -29, Color(240, 240, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- полоса ИЗНОСА
        local wf = math.Clamp(wear / 100, 0, 1)
        draw.RoundedBox(4, -160, -2, 320, 16, Color(40, 40, 46, 220))
        local wcol = wf < 0.35 and Color(90, 160, 220) or wf < 0.7 and Color(235, 190, 80) or Color(235, 110, 70)
        if wf > 0.01 then draw.RoundedBox(4, -160, -2, 320 * wf, 16, wcol) end
        draw.SimpleText("ИЗНОС " .. wear .. "%", "P11.Gen.Tiny", 0, -5, Color(235, 238, 242), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- подсказки
        if fault == "" and not self:GetDamaged() then
            if wear >= 40 then
                draw.SimpleText("держи E — техосмотр", "P11.Gen.Tiny", 0, 20, Color(200, 210, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            else
                draw.SimpleText("E — статус · CTRL+E — режим", "P11.Gen.Tiny", 0, 20, Color(150, 160, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        elseif fault ~= "" then
            local f = POLUS11_GEN_FAULTS[fault]
            draw.SimpleText(f and f.hint or "держи E — устранить", "P11.Gen.Tiny", 0, 20, Color(255, 200, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        -- прогресс действия E
        local act = self:GetUseAction()
        local prog = self:GetUseProgress()
        if act ~= "" and prog > 0 then
            local label = (act == "repair") and "Ремонт..."
                or (act == "service") and "Техосмотр..."
                or "САБОТАЖ..."
            draw.RoundedBox(4, -160, 44, 320, 16, Color(40, 40, 46, 220))
            draw.RoundedBox(4, -160, 44, 320 * prog, 16, Color(110, 160, 255))
            draw.SimpleText(label, "P11.Gen.Tiny", 0, 40, Color(240, 240, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end
