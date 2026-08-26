include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
    self:DrawModel()

    -- угасание: последняя минута — усадка света, последние 30 сек —
    -- ещё и мерцание (v4.8.3: «пусть пропадает со временем» — зримо)
    local die = self.GetDieTime and self:GetDieTime() or 0
    local left = die - CurTime()
    local scale = 1
    if die > 0 and left < 60 then
        scale = math.max(0.3, left / 60)
        if left < 30 and math.random() < 0.14 then return end -- мерцание
    end

    local pulse = 200 + math.sin(CurTime() * 5) * 40
    render.SetMaterial(matGlow)
    render.DrawSprite(self:GetPos() + Vector(0, 0, 6), 90 * scale, 90 * scale, Color(120, 255, 150, pulse))
    render.DrawSprite(self:GetPos() + Vector(0, 0, 6), 30 * scale, 30 * scale, Color(200, 255, 210, 255))

    -- динамический свет
    local dl = DynamicLight(self:EntIndex())
    if dl then
        dl.pos = self:GetPos() + Vector(0, 0, 12)
        dl.r = 90 dl.g = 255 dl.b = 130
        dl.brightness = 2 * scale
        dl.size = 260 * scale
        dl.decay = 800
        dl.dietime = CurTime() + 0.2
    end
end
