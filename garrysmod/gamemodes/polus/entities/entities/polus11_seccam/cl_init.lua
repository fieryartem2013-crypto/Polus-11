include("shared.lua")

-- Камера «ГЛАЗ»: модель + табличка с номером в сети (близко).

surface.CreateFont("P11.Dsp.CamTag", { font = "Arial", size = 46, weight = 800, extended = true })

-- номер камеры в сети (тот же порядок, что в пульте диспетчера)
local function CamNumber(me)
    local cams = ents.FindByClass("polus11_seccam")
    table.sort(cams, function(a, b) return a:EntIndex() < b:EntIndex() end)
    for i, c in ipairs(cams) do
        if c == me then return i end
    end
    return 0
end

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > 480 * 480 then return end

    local n = CamNumber(self)
    local pos = self:GetPos() + Vector(0, 0, 22)
    local ang = lp:EyeAngles()
    ang = Angle(0, ang.y - 90, 90)

    cam.Start3D2D(pos, ang, 0.09)
        draw.SimpleText("ГЛАЗ #" .. n, "P11.Dsp.CamTag", 0, 0,
            Color(150, 190, 255, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
