include("shared.lua")

surface.CreateFont("P11.Gen.Big",   {font = "Roboto", size = 44, weight = 700, extended = true})
surface.CreateFont("P11.Gen.Small", {font = "Roboto", size = 30, weight = 500, extended = true})

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 550 * 550 then return end

    local fuel = math.floor(self:GetFuel())
    local maxf = POLUS11.Config.GeneratorMaxFuel
    local frac = math.Clamp(fuel / maxf, 0, 1)

    local eye = ply:EyeAngles()
    local ang = Angle(0, eye.y - 90, 90)
    local pos = self:GetPos() + Vector(0, 0, 90)

    cam.Start3D2D(pos, ang, 0.2)
        -- фон
        draw.RoundedBox(6, -180, -70, 360, 120, Color(0, 0, 0, 170))

        local status, col
        if self:GetDamaged() then
            status = "АВАРИЯ! ТРЕБУЕТ РЕМОНТА"
            col = Color(255, 70, 70)
        elseif fuel <= 0 then
            status = "НЕТ ТОПЛИВА"
            col = Color(255, 130, 60)
        elseif fuel <= POLUS11.Config.FlickerAt then
            status = "ТОПЛИВО НА ИСХОДЕ"
            col = Color(255, 210, 80)
        else
            status = "ГЕНЕРАТОР РАБОТАЕТ"
            col = Color(120, 220, 120)
        end

        draw.SimpleText(status, "P11.Gen.Big", 0, -60, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- полоса топлива
        draw.RoundedBox(4, -160, -6, 320, 24, Color(40, 40, 46, 220))
        draw.RoundedBox(4, -160, -6, 320 * frac, 24, frac > 0.25 and Color(90, 180, 90) or Color(220, 90, 60))
        draw.SimpleText(fuel .. " сек", "P11.Gen.Small", 0, -6, Color(240, 240, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        -- прогресс действия E
        local act = self:GetUseAction()
        local prog = self:GetUseProgress()
        if act ~= "" and prog > 0 then
            local label = (act == "repair") and "Ремонт..." or "САБОТАЖ..."
            draw.RoundedBox(4, -160, 26, 320, 16, Color(40, 40, 46, 220))
            draw.RoundedBox(4, -160, 26, 320 * prog, 16, Color(110, 160, 255))
            draw.SimpleText(label, "P11.Gen.Small", 0, 20, Color(240, 240, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end
