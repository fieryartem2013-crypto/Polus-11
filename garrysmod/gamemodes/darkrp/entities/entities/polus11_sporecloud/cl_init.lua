include("shared.lua")

local matGlow = Material("sprites/light_glow02_add")

function ENT:Draw()
    local pos = self:GetPos()
    local t = CurTime()

    -- зелёное пульсирующее облачко из спрайтов
    render.SetMaterial(matGlow)
    for i = 1, 5 do
        local ang = t * 0.7 + i * 1.2566
        local off = Vector(math.cos(ang) * 55, math.sin(ang) * 55, 40 + math.sin(t * 1.3 + i) * 25)
        local size = 130 + math.sin(t * 2 + i * 2) * 30
        render.DrawSprite(pos + off, size, size, Color(120, 235, 110, 60))
    end

    -- ядро плотнее
    render.DrawSprite(pos + Vector(0, 0, 35), 180, 180, Color(90, 200, 90, 45))

    local dl = DynamicLight(self:EntIndex())
    if dl then
        dl.pos = pos + Vector(0, 0, 40)
        dl.r = 120 dl.g = 255 dl.b = 100
        dl.brightness = 1
        dl.size = 300
        dl.decay = 700
        dl.dietime = CurTime() + 0.25
    end
end
