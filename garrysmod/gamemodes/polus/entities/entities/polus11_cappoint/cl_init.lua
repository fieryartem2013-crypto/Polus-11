include("shared.lua")

-- Точка захвата «ФЛАГ»: круг на земле, табличка и шкала в мире.

local FACT = {
    rkka  = { name = "РККА",                col = Color(205, 190, 100) },
    eagle = { name = "ОТРЯД «КРАСНЫЙ ОРЁЛ»", col = Color(115, 155, 225) },
}
local NEUTRAL = Color(150, 155, 165)
local RADIUS  = 360

local function FactCol(f)
    return (FACT[f] and FACT[f].col) or NEUTRAL
end

function ENT:Draw()
    self:DrawModel()

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local d2 = me:GetPos():DistToSqr(self:GetPos())
    if d2 > 700 * 700 then return end

    local owner = self:GetOwnerFact() or ""
    local cap   = self:GetCapFact() or ""
    local frac  = tonumber(self:GetCapFrac()) or 0

    -- круг захвата на земле (цвет: владелец / кто жмёт — мигает / никто)
    local col = FactCol(cap ~= "" and cap or owner)
    if cap ~= "" then
        local a = 140 + math.abs(math.sin(CurTime() * 6)) * 115
        col = Color(col.r, col.g, col.b, a)
    end
    local pos = self:GetPos()
    local seg = 40
    local lw = 2
    for i = 1, seg do
        local a1 = (i / seg) * math.pi * 2
        local a2 = ((i + 1) / seg) * math.pi * 2
        local p1 = pos + Vector(math.cos(a1) * RADIUS, math.sin(a1) * RADIUS, 3)
        local p2 = pos + Vector(math.cos(a2) * RADIUS, math.sin(a2) * RADIUS, 3)
        for k = 0, lw - 1 do
            render.DrawLine(p1 + Vector(0, 0, k), p2 + Vector(0, 0, k), col, false)
        end
    end

    if d2 > 400 * 400 then return end

    -- табличка над флагштоком
    local top = pos + Vector(0, 0, 96)
    local ang = Angle(0, (me:EyePos() - top):Angle().y - 90, 90)
    local nm = self:GetPointName()
    if nm == "" then nm = "?" end
    cam.Start3D2D(top, ang, 0.09)
        draw.SimpleTextOutlined("ТОЧКА ЗАХВАТА «" .. nm .. "»", "P11FW.NPC.Big", 0, 0,
            Color(255, 200, 120, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        local ow = FACT[owner]
        draw.SimpleTextOutlined("владеет: " .. (ow and ow.name or "НИКТО"), "P11FW.NPC.Small", 0, 46,
            FactCol(owner), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        if cap ~= "" and FACT[cap] then
            local bw = 220
            draw.RoundedBox(4, -bw / 2, 66, bw, 14, Color(20, 24, 30, 235))
            draw.RoundedBox(4, -bw / 2, 66, math.floor(bw * math.Clamp(frac, 0, 1)), 14, FactCol(cap))
            draw.SimpleTextOutlined("захват: " .. FACT[cap].name .. " " .. math.floor(frac * 100) .. "%",
                "P11FW.NPC.Small", 0, 73, Color(255, 255, 255, 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        else
            draw.SimpleTextOutlined("встань в круг своей фракцией — точка пойдёт под тебя",
                "P11FW.NPC.Small", 0, 73, Color(200, 205, 215, 255),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        end
    cam.End3D2D()
end
