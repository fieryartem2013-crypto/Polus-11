include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
    self:DrawModel()

    -- мерцание перед угасанием
    local die = self.GetDieTime and self:GetDieTime() or 0
    if (die - CurTime()) < 30 and die > 0 then
        if math.random() < 0.1 then return end
    end

    local pulse = 200 + math.sin(CurTime() * 5) * 40
    render.SetMaterial(matGlow)
    render.DrawSprite(self:GetPos() + Vector(0, 0, 6), 90, 90, Color(120, 255, 150, pulse))
    render.DrawSprite(self:GetPos() + Vector(0, 0, 6), 30, 30, Color(200, 255, 210, 255))

    -- динамический свет
    local dl = DynamicLight(self:EntIndex())
    if dl then
        dl.pos = self:GetPos() + Vector(0, 0, 12)
        dl.r = 90 dl.g = 255 dl.b = 130
        dl.brightness = 2
        dl.size = 260
        dl.decay = 800
        dl.dietime = CurTime() + 0.2
    end
end
